const { Attendance, User, CompanySetting, Team, Holiday, HolidayException } = require('../associations');
const { Op, Sequelize } = require('sequelize');

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

    // ── Late Status Calculation ────────────────────────────────────────────────
    let status = 'present';
    if (setting && setting.checkInTime) {
      const nowStr = today.toTimeString().split(' ')[0]; // HH:MM:SS
      if (nowStr > setting.checkInTime) {
        status = 'late';
      }
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

    // Calculate working hours
    if (record.checkInTime) {
      const diffMs = checkOutTime - new Date(record.checkInTime);
      const diffHrs = Math.floor(diffMs / (1000 * 60 * 60));
      const diffMins = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
      record.workingHours = `${diffHrs}h ${diffMins}m`;
    }

    // Early checkout half-day calculation
    if (setting && setting.checkInTime && setting.checkOutTime) {
      try {
        const schedStart = new Date(record.date + 'T' + setting.checkInTime);
        const schedEnd = new Date(record.date + 'T' + setting.checkOutTime);
        const totalShiftMs = schedEnd - schedStart;
        const remainingMs = schedEnd - checkOutTime;

        if (remainingMs > 0 && totalShiftMs > 0) {
          const ratio = remainingMs / totalShiftMs;
          if (ratio > 0.5) {
            record.status = 'half_day';
          }
        }
      } catch (err) {
        console.error('Error calculating half day status:', err.message);
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
};
