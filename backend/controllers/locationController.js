const { User, Attendance, LocationLog } = require('../associations');
const { Op, literal } = require('sequelize');

// 1. Log Location (Employee Endpoint)
const logLocation = async (req, res) => {
  try {
    const { latitude, longitude, address } = req.body;
    const userId = req.user.id;

    if (latitude === undefined || longitude === undefined) {
      return res.status(400).json({ message: 'Latitude and longitude are required' });
    }

    if (!['system_admin', 'company_admin'].includes(req.user.role)) {
      if (req.user.department?.toLowerCase() !== 'marketing' || !['Field Work', 'Office + Field Work'].includes(req.user.workType)) {
        return res.status(403).json({ message: 'Location tracking is restricted to Marketing department employees with work type Field Work or Office + Field Work' });
      }
    }

    const log = await LocationLog.create({
      userId,
      latitude,
      longitude,
      address,
      recordedAt: new Date()
    });

    return res.status(201).json({ message: 'Location logged successfully', log });
  } catch (error) {
    console.error('Error logging location:', error.message);
    return res.status(500).json({ message: 'Failed to log location', error: error.message });
  }
};

// 2. Get Location Trail for a User on a given date (Admin Endpoint)
const getMarketingTrail = async (req, res) => {
  try {
    const { userId } = req.params;
    const { date } = req.query; // Expecting YYYY-MM-DD format

    const queryDate = date || new Date().toISOString().split('T')[0];

    const targetUser = await User.findByPk(userId);
    if (!targetUser) {
      return res.status(404).json({ message: 'Employee not found' });
    }

    // Restrict to own company only - both system_admin and company_admin
    if (req.user.companyId && targetUser.companyId !== req.user.companyId) {
      return res.status(403).json({ message: 'Unauthorized to track this employee' });
    }

    if (targetUser.department?.toLowerCase() !== 'marketing') {
      return res.status(400).json({ message: 'Selected employee does not belong to the Marketing department' });
    }

    // Use DATE() function to avoid UTC timezone boundary issues
    const logs = await LocationLog.findAll({
      where: {
        userId,
        [Op.and]: [literal(`DATE(recorded_at) = '${queryDate}'`)]
      },
      order: [['recordedAt', 'ASC']]
    });

    return res.json({ logs });
  } catch (error) {
    console.error('Error fetching marketing trail:', error.message);
    return res.status(500).json({ message: 'Failed to fetch location trail', error: error.message });
  }
};

// 3. Get Currently Active Marketing Employees & Their Latest Location (Admin Endpoint)
const getActiveMarketingEmployees = async (req, res) => {
  try {
    const todayStr = new Date().toISOString().split('T')[0];
    const creatorRole = req.user.role;
    const companyId = req.user.companyId;

    let userWhere = {
      department: { [Op.like]: 'marketing' }
    };
    // Always restrict to the requester's own company regardless of role
    if (req.user.companyId) {
      userWhere.companyId = req.user.companyId;
    }

    const activeAttendances = await Attendance.findAll({
      where: {
        date: todayStr,
        checkInTime: { [Op.ne]: null },
        checkOutTime: null
      },
      include: [
        {
          model: User,
          as: 'user',
          where: userWhere,
          attributes: ['id', 'name', 'email', 'employeeId', 'profilePicture', 'department']
        }
      ]
    });

    const activeMarketingList = [];
    for (const att of activeAttendances) {
      const user = att.user;
      if (!user) continue;

      const latestLog = await LocationLog.findOne({
        where: { userId: user.id },
        order: [['recordedAt', 'DESC']]
      });

      activeMarketingList.push({
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          employeeId: user.employeeId,
          profilePicture: user.profilePicture
        },
        attendance: {
          id: att.id,
          checkInTime: att.checkInTime,
          status: att.status
        },
        latestLocation: latestLog ? {
          latitude: latestLog.latitude,
          longitude: latestLog.longitude,
          address: latestLog.address,
          recordedAt: latestLog.recordedAt
        } : null
      });
    }

    return res.json({ activeEmployees: activeMarketingList });
  } catch (error) {
    console.error('Error fetching active marketing employees:', error.message);
    return res.status(500).json({ message: 'Failed to fetch active marketing list', error: error.message });
  }
};

// 4. Get ALL Marketing Employees with today's attendance & location status (Admin Endpoint)
const getAllMarketingEmployees = async (req, res) => {
  try {
    const todayStr = new Date().toISOString().split('T')[0];
    const creatorRole = req.user.role;
    const companyId = req.user.companyId;

    let userWhere = {
      department: { [Op.like]: 'marketing' }
    };
    // Always restrict to the requester's own company regardless of role
    if (req.user.companyId) {
      userWhere.companyId = req.user.companyId;
    }

    const marketingUsers = await User.findAll({
      where: userWhere,
      attributes: ['id', 'name', 'email', 'employeeId', 'profilePicture', 'department', 'isActive', 'workType'],
      order: [['name', 'ASC']]
    });

    const result = [];
    for (const user of marketingUsers) {
      const todayAttendance = await Attendance.findOne({
        where: { userId: user.id, date: todayStr },
        order: [['checkInTime', 'DESC']]
      });

      const latestLog = await LocationLog.findOne({
        where: { userId: user.id },
        order: [['recordedAt', 'DESC']]
      });

      const isCurrentlyActive = todayAttendance
        ? (todayAttendance.checkInTime !== null && todayAttendance.checkOutTime === null)
        : false;

      result.push({
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          employeeId: user.employeeId,
          profilePicture: user.profilePicture,
          isActive: user.isActive,
          workType: user.workType,
        },
        todayAttendance: todayAttendance ? {
          id: todayAttendance.id,
          checkInTime: todayAttendance.checkInTime,
          checkOutTime: todayAttendance.checkOutTime,
          status: todayAttendance.status,
          latitude: todayAttendance.latitude,
          longitude: todayAttendance.longitude,
          address: todayAttendance.address,
        } : null,
        latestLocation: latestLog ? {
          latitude: latestLog.latitude,
          longitude: latestLog.longitude,
          address: latestLog.address,
          recordedAt: latestLog.recordedAt
        } : null,
        isCurrentlyActive,
      });
    }

    return res.json({ employees: result });
  } catch (error) {
    console.error('Error fetching all marketing employees:', error.message);
    return res.status(500).json({ message: 'Failed to fetch marketing employees', error: error.message });
  }
};

module.exports = {
  logLocation,
  getMarketingTrail,
  getActiveMarketingEmployees,
  getAllMarketingEmployees
};
