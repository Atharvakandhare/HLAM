const { Attendance, User, CompanySetting, Team, Holiday, HolidayException, Shift } = require('../associations');
const { Op, Sequelize } = require('sequelize');
const { getFaceDescriptor, verifyFaceMatch } = require('../services/faceService');
const fs = require('fs');
const path = require('path');

// Helper to parse time string "HH:MM:SS" into milliseconds from midnight
const getTimeMs = (timeStr) => {
  if (!timeStr) return 0;
  const [hrs, mins, secs] = timeStr.split(':').map(Number);
  return ((hrs * 60 + mins) * 60 + (secs || 0)) * 1000;
};

// Helper to get milliseconds from midnight of a Date object
const getDateMsSinceMidnight = (date) => {
  if (!date) return 0;
  const hrs = date.getHours();
  const mins = date.getMinutes();
  const secs = date.getSeconds();
  return ((hrs * 60 + mins) * 60 + secs) * 1000;
};

// Helper function to generate Google Maps URL
const generateMapUrl = (latitude, longitude) => {
  if (!latitude || !longitude) return null;
  return `https://www.google.com/maps?q=${latitude},${longitude}`;
};

// Haversine formula to calculate distance in meters between two coordinates
const getDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371e3; // metres
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // in metres
};

// Local timezone-aware YYYY-MM-DD string generator
const getLocalDateString = (d = new Date()) => {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

/**
 * Check if today is a company holiday for this user.
 * Returns the holiday record if blocked, null if allowed to proceed.
 */
const checkHolidayBlock = async (userCompanyId, userId, userTeamId, dateStr) => {
  if (!userCompanyId) return null;

  const holiday = await Holiday.findOne({
    where: { companyId: userCompanyId, date: dateStr, isActive: true },
  });

  if (!holiday) return null; // Not a holiday, all good

  // Check if there's an exception for this user (by userId)
  const userException = await HolidayException.findOne({
    where: { holidayId: holiday.id, userId },
  });
  if (userException) return null; // User has an exception, allow

  // Check if there's an exception for this user's team
  if (userTeamId) {
    const teamException = await HolidayException.findOne({
      where: { holidayId: holiday.id, teamId: userTeamId },
    });
    if (teamException) return null; // Team has an exception, allow
  }

  return holiday; // Blocked by holiday
};

// Check-in / create attendance record
const checkIn = async (req, res) => {
  try {
    const { selfieUrl, taskComments, latitude, longitude, address, mood, energyLevel } = req.body;
    const userId = req.user.id;
    const userRole = req.user.role;
    const userCompanyId = req.user.companyId;
    const userWorkMode = req.user.workMode;
    const userTeamId = req.user.teamId;

    // Only system_admin and company_admin are blocked from marking attendance.
    // Managers and Team Leaders are treated as employees too.
    if (['system_admin', 'company_admin'].includes(userRole)) {
      return res.status(403).json({ message: 'Admins are not allowed to mark attendance' });
    }

    // Selfie is mandatory
    if (!selfieUrl) {
      return res.status(400).json({ message: 'Live selfie is required for check-in.' });
    }

    // Face verification for non-admin roles
    const needsFaceVerification = ['employee', 'manager', 'team_leader'].includes(userRole);
    if (needsFaceVerification) {
      const user = await User.findByPk(userId);
      if (!user || !user.faceDescriptor) {
        return res.status(400).json({ 
          message: 'Face verification is required. Please register your face on the profile page first.' 
        });
      }

      const localFilePath = path.join(__dirname, '..', selfieUrl);
      const newDescriptor = await getFaceDescriptor(localFilePath);

      if (!newDescriptor) {
        if (fs.existsSync(localFilePath)) {
          try { fs.unlinkSync(localFilePath); } catch (e) {}
        }
        return res.status(400).json({ 
          message: 'No face detected in your check-in selfie. Please make sure your face is clearly visible and try again.' 
        });
      }

      const { isMatch, distance } = verifyFaceMatch(user.faceDescriptor, newDescriptor);
      console.log(`[FaceVerify Check-In] User ID: ${userId}, Distance: ${distance.toFixed(4)}, Match: ${isMatch}`);

      if (!isMatch) {
        if (fs.existsSync(localFilePath)) {
          try { fs.unlinkSync(localFilePath); } catch (e) {}
        }
        return res.status(403).json({ 
          message: 'Face verification failed! The captured selfie does not match your registered face profile.' 
        });
      }
    }

    // Mood is mandatory
    if (!mood) {
      return res.status(400).json({ message: 'Mood selection is required for check-in.' });
    }

    // Energy level is mandatory
    if (!energyLevel) {
      return res.status(400).json({ message: 'Energy level selection is required for check-in.' });
    }

    const today = new Date();
    const dateOnly = getLocalDateString(today);

    // ── Holiday Check ──────────────────────────────────────────────────────────
    const blockedHoliday = await checkHolidayBlock(userCompanyId, userId, userTeamId, dateOnly);
    if (blockedHoliday) {
      return res.status(403).json({
        message: `Today is a company holiday: "${blockedHoliday.name}". Check-in is not allowed.`,
        holidayName: blockedHoliday.name,
        isHoliday: true,
      });
    }

    // Fetch company settings
    let setting = null;
    if (userCompanyId) {
      setting = await CompanySetting.findOne({ where: { companyId: userCompanyId } });
    }

    // ── Distance Calculation ───────────────────────────────────────────────────
    // Always calculate and store the distance — no longer blocking on radius
    let distanceFromOffice = null;
    if (latitude != null && longitude != null && setting && setting.latitude && setting.longitude) {
      distanceFromOffice = getDistance(
        parseFloat(latitude),
        parseFloat(longitude),
        parseFloat(setting.latitude),
        parseFloat(setting.longitude)
      );
      distanceFromOffice = Math.round(distanceFromOffice); // round to nearest metre
    }

    // ── Prevent Duplicate Active Session ───────────────────────────────────────
    const activeSession = await Attendance.findOne({
      where: { userId, date: dateOnly, checkOutTime: null },
    });
    if (activeSession) {
      return res.status(400).json({ message: 'You have an active session. Please check out first.' });
    }

    // ── Shift and Late Status Calculation ──────────────────────────────────────
    const todayRecords = await Attendance.findAll({ where: { userId, date: dateOnly } });
    let shiftId = req.body.shiftId;
    let explicitNone = false;
    if (shiftId === 'none' || shiftId === '0' || shiftId === 0) {
      shiftId = null;
      explicitNone = true;
    } else if (shiftId === undefined || shiftId === '') {
      shiftId = null;
    }
    let isLateIn = false;
    let isEarlyIn = false;
    let status = 'present';

    if (todayRecords.length === 0) {
      // First check-in of the day
      if (!shiftId && !explicitNone) {
        const user = await User.findByPk(userId);
        if (user && user.defaultShiftId) {
          shiftId = user.defaultShiftId;
        }
      }

      if (shiftId) {
        const shift = await Shift.findOne({ where: { id: shiftId, companyId: userCompanyId } });
        if (shift) {
          const checkInMs = getDateMsSinceMidnight(today);
          const shiftStartMs = getTimeMs(shift.checkInTime);
          const diffMins = (checkInMs - shiftStartMs) / (60 * 1000);

          if (diffMins > shift.lateInLimit) {
            isLateIn = true;
            status = 'late';
          } else if (diffMins < -shift.earlyInLimit) {
            isEarlyIn = true;
          }
        }
      } else if (setting && setting.checkInTime) {
        // Fallback to company settings if no shift exists
        const checkInMs = getDateMsSinceMidnight(today);
        const companyStartMs = getTimeMs(setting.checkInTime);
        const diffMins = (checkInMs - companyStartMs) / (60 * 1000);

        if (diffMins > 15) {
          status = 'late';
        }
      }
    } else {
      // Subsequent check-ins use the same shift as the first session of today
      shiftId = todayRecords[0].shiftId;
      status = todayRecords[0].status;
    }

    const record = await Attendance.create({
      userId,
      date: dateOnly,
      checkInTime: today,
      selfieUrl,
      taskComments: taskComments || null,
      latitude: latitude != null ? parseFloat(latitude) : null,
      longitude: longitude != null ? parseFloat(longitude) : null,
      address: address || null,
      loginStatus: req.body.loginStatus || 'success',
      status,
      mood: mood || null,
      energyLevel: energyLevel || null,
      distanceFromOffice,
      shiftId,
      isLateIn,
      isEarlyIn,
    });

    const attendanceData = record.toJSON();
    attendanceData.mapUrl = generateMapUrl(record.latitude, record.longitude);

    return res.status(201).json({
      message: 'Attendance marked successfully',
      attendance: attendanceData,
    });
  } catch (error) {
    console.error('[Attendance] Check-in error:', error);
    return res.status(500).json({ message: 'Check-in failed', error: error.message });
  }
};

// Check-out / update today's attendance record
const checkOut = async (req, res) => {
  try {
    const userId = req.user.id;
    const userCompanyId = req.user.companyId;
    const { attendanceId, checkoutSelfieUrl, checkoutLatitude, checkoutLongitude, checkoutAddress, taskComments } = req.body;
    const today = getLocalDateString();

    // Look for active checked-in session where checkOutTime is null
    const record = await Attendance.findOne({
      where: attendanceId ? { id: attendanceId, userId } : { userId, date: today, checkOutTime: null },
    });

    if (!record) return res.status(404).json({ message: 'No active checked-in session found to check out.' });

    // Selfie is mandatory
    if (!checkoutSelfieUrl) {
      return res.status(400).json({ message: 'Live selfie is required for check-out.' });
    }

    // Face verification for non-admin roles
    const userRole = req.user.role;
    const needsFaceVerification = ['employee', 'manager', 'team_leader'].includes(userRole);
    if (needsFaceVerification) {
      const user = await User.findByPk(userId);
      if (!user || !user.faceDescriptor) {
        return res.status(400).json({ 
          message: 'Face verification is required. Please register your face on the profile page first.' 
        });
      }

      const localFilePath = path.join(__dirname, '..', checkoutSelfieUrl);
      const newDescriptor = await getFaceDescriptor(localFilePath);

      if (!newDescriptor) {
        if (fs.existsSync(localFilePath)) {
          try { fs.unlinkSync(localFilePath); } catch (e) {}
        }
        return res.status(400).json({ 
          message: 'No face detected in your check-out selfie. Please make sure your face is clearly visible and try again.' 
        });
      }

      const { isMatch, distance } = verifyFaceMatch(user.faceDescriptor, newDescriptor);
      console.log(`[FaceVerify Check-Out] User ID: ${userId}, Distance: ${distance.toFixed(4)}, Match: ${isMatch}`);

      if (!isMatch) {
        if (fs.existsSync(localFilePath)) {
          try { fs.unlinkSync(localFilePath); } catch (e) {}
        }
        return res.status(403).json({ 
          message: 'Face verification failed! The captured selfie does not match your registered face profile.' 
        });
      }
    }

    // Fetch company settings
    let setting = null;
    if (userCompanyId) {
      setting = await CompanySetting.findOne({ where: { companyId: userCompanyId } });
    }

    // ── Distance Calculation for Checkout ─────────────────────────────────────
    let checkoutDistanceFromOffice = null;
    if (checkoutLatitude != null && checkoutLongitude != null && setting && setting.latitude && setting.longitude) {
      checkoutDistanceFromOffice = Math.round(getDistance(
        parseFloat(checkoutLatitude),
        parseFloat(checkoutLongitude),
        parseFloat(setting.latitude),
        parseFloat(setting.longitude)
      ));
    }

    const checkOutTime = new Date();
    record.checkOutTime = checkOutTime;
    record.checkoutSelfieUrl = checkoutSelfieUrl;
    record.checkoutLatitude = checkoutLatitude != null ? parseFloat(checkoutLatitude) : null;
    record.checkoutLongitude = checkoutLongitude != null ? parseFloat(checkoutLongitude) : null;
    record.checkoutAddress = checkoutAddress || null;
    record.logoutStatus = req.body.logoutStatus || 'success';
    if (taskComments) {
      record.taskComments = taskComments;
    }
    // Store checkout distance
    if (checkoutDistanceFromOffice !== null) {
      record.distanceFromOffice = checkoutDistanceFromOffice;
    }

    // Calculate working hours (diffMs for this session + sum other sessions for today)
    let totalWorkedMs = 0;
    if (record.checkInTime) {
      const diffMs = checkOutTime - new Date(record.checkInTime);
      totalWorkedMs = diffMs;

      // Find other check-out records of today for this user
      const otherRecords = await Attendance.findAll({
        where: {
          userId,
          date: record.date,
          id: { [Op.ne]: record.id },
          checkOutTime: { [Op.ne]: null }
        }
      });

      for (const r of otherRecords) {
        const sessionMs = new Date(r.checkOutTime) - new Date(r.checkInTime);
        totalWorkedMs += sessionMs;
      }

      const diffHrs = Math.floor(diffMs / (1000 * 60 * 60));
      const diffMins = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
      record.workingHours = `${diffHrs}h ${diffMins}m`;

      // Early checkout / Late checkout / Overtime shift calculation
      if (record.shiftId) {
        const shift = await Shift.findByPk(record.shiftId);
        if (shift) {
          const checkOutMs = getDateMsSinceMidnight(checkOutTime);
          const shiftEndMs = getTimeMs(shift.checkOutTime);
          const diffMinsFromEnd = (checkOutMs - shiftEndMs) / (60 * 1000);

          // Early Out Check
          if (diffMinsFromEnd < -shift.earlyOutLimit) {
            record.isEarlyOut = true;
          }

          // Late Out Check
          if (diffMinsFromEnd > shift.lateOutLimit) {
            record.isLateOut = true;
          }

          // Overtime Check: Check if overtime is allowed for this daily session
          const isOvertimeAllowed = record.overtimeAllowed || otherRecords.some(r => r.overtimeAllowed === true);
          if (isOvertimeAllowed && diffMinsFromEnd > 0) {
            const otHrs = Math.floor(diffMinsFromEnd / 60);
            const otMins = Math.floor(diffMinsFromEnd % 60);
            record.overtimeDuration = `${otHrs}h ${otMins}m`;
          }

          // Overall status decision based on total hours
          const shiftStartMs = getTimeMs(shift.checkInTime);
          const requiredShiftMs = shiftEndMs - shiftStartMs;

          if (totalWorkedMs >= requiredShiftMs) {
            record.status = 'present';
            // Propagate present status to all of today's records for this user
            if (otherRecords.length > 0) {
              await Attendance.update({ status: 'present' }, {
                where: { userId, date: record.date }
              });
            }
          } else {
            const ratio = totalWorkedMs / requiredShiftMs;
            const finalStatus = ratio < 0.5 ? 'half_day' : 'present';
            record.status = finalStatus;
            if (otherRecords.length > 0) {
              await Attendance.update({ status: finalStatus }, {
                where: { userId, date: record.date }
              });
            }
          }
        }
      } else if (setting && setting.checkInTime && setting.checkOutTime) {
        // Fallback to company settings if no shift
        try {
          const schedStart = new Date(record.date + 'T' + setting.checkInTime);
          const schedEnd = new Date(record.date + 'T' + setting.checkOutTime);
          const totalShiftMs = schedEnd - schedStart;

          // Propagate present/half-day status based on total worked ms
          if (totalWorkedMs >= totalShiftMs) {
            record.status = 'present';
            if (otherRecords.length > 0) {
              await Attendance.update({ status: 'present' }, {
                where: { userId, date: record.date }
              });
            }
          } else {
            const ratio = totalWorkedMs / totalShiftMs;
            const finalStatus = ratio < 0.5 ? 'half_day' : 'present';
            record.status = finalStatus;
            if (otherRecords.length > 0) {
              await Attendance.update({ status: finalStatus }, {
                where: { userId, date: record.date }
              });
            }
          }
        } catch (err) {
          console.error('Error calculating company settings checkout status:', err.message);
        }
      }
    }

    await record.save();
    return res.json({ message: 'Check-out recorded', attendance: record });
  } catch (error) {
    console.error('[Attendance] Check-out error:', error);
    return res.status(500).json({ message: 'Check-out failed', error: error.message });
  }
};

// List current user's attendance
const myAttendance = async (req, res) => {
  try {
    const { startDate, endDate, month, year } = req.query;
    const filters = { userId: req.user.id };

    if (month && year) {
      const start = `${year}-${String(month).padStart(2, '0')}-01`;
      const end = `${year}-${String(month).padStart(2, '0')}-${new Date(year, month, 0).getDate()}`;
      filters.date = { [Op.between]: [start, end] };
    } else if (startDate || endDate) {
      filters.date = {};
      if (startDate) filters.date[Op.gte] = startDate;
      if (endDate) filters.date[Op.lte] = endDate;
    }

    const records = await Attendance.findAll({
      where: filters,
      order: [['date', 'DESC']],
    });

    const attendanceWithMaps = records.map(record => {
      const data = record.toJSON();
      data.mapUrl = generateMapUrl(record.latitude, record.longitude);
      return data;
    });

    return res.json({ attendance: attendanceWithMaps });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch attendance', error: error.message });
  }
};

// Today attendance for current user
const todayAttendance = async (req, res) => {
  try {
    const today = getLocalDateString();
    const record = await Attendance.findOne({
      where: { userId: req.user.id, date: today },
      order: [['checkInTime', 'DESC']],
    });

    if (record) {
      const data = record.toJSON();
      data.mapUrl = generateMapUrl(record.latitude, record.longitude);
      return res.json({ attendance: data });
    }

    return res.json({ attendance: null });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch today attendance', error: error.message });
  }
};

// Admin: list all attendance with user details + mood/energy filter support
const listAll = async (req, res) => {
  try {
    const { startDate, endDate, userId, employeeId, month, year, mood, energyLevel } = req.query;
    const filters = {};
    const requesterRole = req.user.role;
    const requesterCompanyId = req.user.companyId;

    if (userId) {
      filters.userId = userId;
    } else if (employeeId) {
      const user = await User.findOne({ where: { employeeId } });
      if (user) {
        filters.userId = user.id;
      } else {
        return res.json({ attendance: [] });
      }
    }

    if (month && year) {
      const start = `${year}-${String(month).padStart(2, '0')}-01`;
      const end = `${year}-${String(month).padStart(2, '0')}-${new Date(year, month, 0).getDate()}`;
      filters.date = { [Op.between]: [start, end] };
    } else if (startDate || endDate) {
      filters.date = {};
      if (startDate) filters.date[Op.gte] = startDate;
      if (endDate) filters.date[Op.lte] = endDate;
    }

    // Mood and energy level filters
    if (mood) filters.mood = mood;
    if (energyLevel) filters.energyLevel = energyLevel;

    // Build user include with company-scoped filtering
    const userIncludeWhere = {};
    if (requesterCompanyId) {
      userIncludeWhere.companyId = requesterCompanyId;
    }
    if (['manager', 'team_leader'].includes(requesterRole)) {
      const managedTeams = await Team.findAll({
        where: {
          [Op.or]: [
            { managerId: req.user.id },
            { teamLeaderId: req.user.id }
          ]
        },
        attributes: ['id']
      });
      const teamIds = managedTeams.map(t => t.id);
      
      userIncludeWhere[Op.or] = [
        { teamId: { [Op.in]: teamIds } },
        { id: req.user.id }
      ];
    }

    const records = await Attendance.findAll({
      where: filters,
      include: [{
        model: User,
        as: 'user',
        where: Object.keys(userIncludeWhere).length > 0 ? userIncludeWhere : undefined,
        attributes: ['id', 'name', 'email', 'employeeId', 'department', 'role', 'companyId', 'teamId'],
        include: [{
          model: Team,
          as: 'team',
          attributes: ['id', 'name'],
          required: false,
        }],
      }],
      order: [['date', 'DESC'], ['checkInTime', 'DESC']],
    });

    const attendanceWithMaps = records.map(record => {
      const data = record.toJSON();
      data.mapUrl = generateMapUrl(record.latitude, record.longitude);
      return data;
    });

    return res.json({ attendance: attendanceWithMaps });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch attendance', error: error.message });
  }
};

// Admin: get attendance grouped by team for a specific date range
const getAttendanceByTeams = async (req, res) => {
  try {
    const { startDate, endDate, date, mood, energyLevel } = req.query;
    const requesterCompanyId = req.user.companyId;

    if (!requesterCompanyId) {
      return res.status(403).json({ message: 'Company-level access required.' });
    }

    const filters = {};
    if (date) {
      filters.date = date;
    } else if (startDate || endDate) {
      filters.date = {};
      if (startDate) filters.date[Op.gte] = startDate;
      if (endDate) filters.date[Op.lte] = endDate;
    } else {
      // Default: today
      filters.date = getLocalDateString();
    }

    if (mood) filters.mood = mood;
    if (energyLevel) filters.energyLevel = energyLevel;

    const userWhere = { companyId: requesterCompanyId };
    if (['manager', 'team_leader'].includes(req.user.role)) {
      const managedTeams = await Team.findAll({
        where: {
          [Op.or]: [
            { managerId: req.user.id },
            { teamLeaderId: req.user.id }
          ]
        },
        attributes: ['id']
      });
      const teamIds = managedTeams.map(t => t.id);
      
      userWhere[Op.or] = [
        { teamId: { [Op.in]: teamIds } },
        { id: req.user.id }
      ];
    }

    const records = await Attendance.findAll({
      where: filters,
      include: [{
        model: User,
        as: 'user',
        where: userWhere,
        attributes: ['id', 'name', 'email', 'employeeId', 'department', 'role', 'teamId'],
        include: [{
          model: Team,
          as: 'team',
          attributes: ['id', 'name'],
          required: false,
        }],
      }],
      order: [['date', 'DESC'], ['checkInTime', 'DESC']],
    });

    // Fetch all teams for this company (to include teams with no attendance)
    const teamWhere = { companyId: requesterCompanyId };
    if (['manager', 'team_leader'].includes(req.user.role)) {
      teamWhere[Op.or] = [
        { managerId: req.user.id },
        { teamLeaderId: req.user.id }
      ];
    }

    const allTeams = await Team.findAll({
      where: teamWhere,
      attributes: ['id', 'name'],
    });

    // Group attendance by team
    const teamMap = {};
    // Initialize with all known teams
    for (const t of allTeams) {
      teamMap[t.id] = { teamId: t.id, teamName: t.name, records: [] };
    }
    // Special bucket for unassigned users
    teamMap['unassigned'] = { teamId: null, teamName: 'No Team Assigned', records: [] };

    for (const record of records) {
      const data = record.toJSON();
      data.mapUrl = generateMapUrl(record.latitude, record.longitude);
      const teamId = data.user?.teamId;
      if (teamId && teamMap[teamId]) {
        teamMap[teamId].records.push(data);
      } else {
        teamMap['unassigned'].records.push(data);
      }
    }

    const grouped = Object.values(teamMap).filter(
      t => t.records.length > 0 || t.teamId !== null
    );

    return res.json({ grouped });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch team attendance', error: error.message });
  }
};

// Get one attendance record by id (with user)
const getById = async (req, res) => {
  try {
    const { id } = req.params;
    const requesterCompanyId = req.user.companyId;

    const record = await Attendance.findByPk(id, {
      include: [{
        model: User,
        as: 'user',
        attributes: ['id', 'name', 'email', 'employeeId', 'department', 'role', 'companyId', 'teamId'],
      }],
    });
    if (!record) return res.status(404).json({ message: 'Attendance not found' });

    if (requesterCompanyId && record.user && record.user.companyId !== requesterCompanyId) {
      return res.status(403).json({ message: 'You are not authorized to view this attendance record.' });
    }

    if (['manager', 'team_leader'].includes(req.user.role)) {
      const managedTeams = await Team.findAll({
        where: {
          [Op.or]: [
            { managerId: req.user.id },
            { teamLeaderId: req.user.id }
          ]
        },
        attributes: ['id']
      });
      const teamIds = managedTeams.map(t => t.id);
      
      const isSelf = record.userId === req.user.id;
      const isTeamMember = record.user && teamIds.includes(record.user.teamId);
      
      if (!isSelf && !isTeamMember) {
        return res.status(403).json({ message: 'You are not authorized to view this attendance record.' });
      }
    }

    const data = record.toJSON();
    data.mapUrl = generateMapUrl(record.latitude, record.longitude);

    return res.json({ attendance: data });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch attendance', error: error.message });
  }
};

// Admin: delete attendance record
const deleteAttendance = async (req, res) => {
  try {
    const { id } = req.params;
    const requesterCompanyId = req.user.companyId;

    const record = await Attendance.findByPk(id, {
      include: [{ model: User, as: 'user', attributes: ['id', 'companyId'] }]
    });
    if (!record) return res.status(404).json({ message: 'Attendance not found' });

    if (requesterCompanyId && record.user && record.user.companyId !== requesterCompanyId) {
      return res.status(403).json({ message: 'You are not authorized to delete this attendance record.' });
    }

    await record.destroy();
    return res.json({ message: 'Attendance deleted successfully' });
  } catch (error) {
    return res.status(500).json({ message: 'Deletion failed', error: error.message });
  }
};

// User Stats for dashboard
const getUserStats = async (req, res) => {
  try {
    const userId = req.user.id;
    const today = new Date();
    const startOfMonth = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-01`;
    const endOfMonth = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()}`;

    const records = await Attendance.findAll({
      where: {
        userId,
        date: { [Op.between]: [startOfMonth, endOfMonth] }
      }
    });

    const present = records.filter(r => r.checkInTime && r.checkOutTime && r.status !== 'half_day').length;
    const halfDay = records.filter(r => r.status === 'half_day' || (r.checkInTime && !r.checkOutTime)).length;
    const totalDaysSoFar = today.getDate();
    const absents = Math.max(0, totalDaysSoFar - (present + halfDay));

    return res.json({ present, absents, halfDay, totalRecords: records.length });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch stats', error: error.message });
  }
};

// Allocate Overtime Permission (Manager/TL/Admin)
const updateOvertimePermission = async (req, res) => {
  try {
    const requesterRole = req.user.role;
    const requesterCompanyId = req.user.companyId;
    const requesterId = req.user.id;

    // Only Admin, Manager, Team Leader can manage overtime
    if (!['system_admin', 'company_admin', 'manager', 'team_leader'].includes(requesterRole)) {
      return res.status(403).json({ message: 'Unauthorized. Only managers, team leaders, or admins can manage overtime.' });
    }

    const { userId, date, overtimeAllowed } = req.body;
    if (!userId || !date) {
      return res.status(400).json({ message: 'userId and date are required.' });
    }

    // Load target user
    const targetUser = await User.findByPk(userId);
    if (!targetUser) {
      return res.status(404).json({ message: 'User not found.' });
    }

    // Verify company scope
    if (targetUser.companyId !== requesterCompanyId) {
      return res.status(403).json({ message: 'You can only allocate overtime to employees within your own company.' });
    }

    // Role-based hierarchy scope verification
    if (['manager', 'team_leader'].includes(requesterRole)) {
      const managedTeams = await Team.findAll({
        where: {
          [Op.or]: [
            { managerId: requesterId },
            { teamLeaderId: requesterId }
          ]
        },
        attributes: ['id']
      });
      const teamIds = managedTeams.map(t => t.id);

      if (!targetUser.teamId || !teamIds.includes(targetUser.teamId)) {
        return res.status(403).json({ message: 'You can only allocate overtime to members of your managed teams.' });
      }
    }

    // Find or create attendance record for that date
    let [record] = await Attendance.findOrCreate({
      where: { userId, date },
      defaults: {
        selfieUrl: 'system-placeholder', // fallback placeholder
        status: 'present',
        loginStatus: 'success'
      }
    });

    record.overtimeAllowed = overtimeAllowed === true || overtimeAllowed === 'true';
    await record.save();

    // Propagate overtime allowed to all attendance rows of the same day (for multiple sessions)
    await Attendance.update(
      { overtimeAllowed: record.overtimeAllowed },
      { where: { userId, date } }
    );

    return res.json({
      message: `Overtime permission ${record.overtimeAllowed ? 'granted' : 'revoked'} successfully for user ${targetUser.name} on ${date}.`,
      attendance: record
    });
  } catch (error) {
    console.error('[Overtime Permission] Error:', error);
    return res.status(500).json({ message: 'Failed to update overtime permission', error: error.message });
  }
};

module.exports = {
  checkIn,
  checkOut,
  myAttendance,
  todayAttendance,
  listAll,
  getAttendanceByTeams,
  getById,
  deleteAttendance,
  getUserStats,
  updateOvertimePermission,
};
