const { User, Attendance, Company, Team, CompanySetting, Shift, Holiday, Leave } = require('../associations');
const { Op } = require('sequelize');
const bcrypt = require('bcryptjs');
const { sendWelcomeEmail, sendCompanyAdminWelcomeEmail } = require('../services/mailService');

// --- Normalization helpers ---
// These prevent ENUM validation errors when incoming values have wrong casing
const VALID_WORK_MODES = ['Work From Office', 'Work From Home', 'Remote Work'];
const VALID_WORK_TYPES = ['Work From Office', 'Field Work', 'Office + Field Work'];

const normalizeEnum = (value, validValues, defaultValue = null) => {
  if (value == null || value === '') return defaultValue;
  const match = validValues.find(v => v.toLowerCase() === value.toLowerCase());
  return match || defaultValue;
};


// List users
const listUsers = async (req, res) => {
  try {
    const { role, department, isActive, companyId, teamId } = req.query;
    const filters = {};
    if (role) filters.role = role;
    if (department) filters.department = department;
    if (isActive !== undefined) filters.isActive = isActive === 'true';

    const userRole = req.user.role;
    let queryOptions = {
      where: filters,
      include: [
        { model: Company, as: 'company', attributes: ['id', 'name'] },
        { model: Team, as: 'team', attributes: ['id', 'name'] }
      ],
      order: [['createdAt', 'DESC']]
    };

    if (userRole === 'system_admin') {
      // system_admin can only fully manage their own company.
      // For other companies, only company_admin accounts are visible.
      const adminCompanyId = req.user.companyId;
      if (!companyId || parseInt(companyId) === adminCompanyId) {
        // Viewing own company — show all users
        filters.companyId = adminCompanyId;
        if (teamId) filters.teamId = teamId;
      } else {
        // Viewing another company — only show company_admin accounts
        filters.companyId = parseInt(companyId);
        filters.role = 'company_admin';
      }
    } else if (userRole === 'company_admin') {
      filters.companyId = req.user.companyId;
      if (teamId) filters.teamId = teamId;
    } else if (userRole === 'manager' || userRole === 'team_leader') {
      // Managers and Team Leaders see active employees in their own company (so they can add members to their team)
      filters.companyId = req.user.companyId;
      filters.isActive = true;
      queryOptions.attributes = ['id', 'name', 'email', 'department', 'dob', 'profilePicture', 'role', 'teamId'];
    } else if (userRole === 'employee') {
      // Employees see active colleagues in their own company
      filters.companyId = req.user.companyId;
      filters.isActive = true;
      queryOptions.attributes = ['id', 'name', 'email', 'department', 'dob', 'profilePicture', 'role', 'teamId'];
    } else {
      return res.status(403).json({ message: 'Unauthorized' });
    }

    const users = await User.findAll(queryOptions);
    return res.json({ users });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch users', error: error.message });
  }
};

// Create user
const createUser = async (req, res) => {
  try {
    const { name, email, password, role, department, employeeId, profilePicture, dob, state, city, workMode, workType, companyId, teamId } = req.body;
    
    if (!name || !email || !password) {
      return res.status(400).json({ message: 'Name, email, and password are required' });
    }

    const creatorRole = req.user.role;
    let targetCompanyId = companyId;
    let targetTeamId = teamId;
    let targetRole = role || 'employee';

    // Role-based hierarchy checks
    if (creatorRole === 'system_admin') {
      // system_admin can create any user in their own company.
      // For other companies, they can only create company_admin accounts.
      if (targetCompanyId && parseInt(targetCompanyId) !== req.user.companyId) {
        if (targetRole !== 'company_admin') {
          return res.status(403).json({ message: 'System Admins can only create company_admin accounts for other companies.' });
        }
      } else {
        // Default to own company if no companyId provided
        if (!targetCompanyId) targetCompanyId = req.user.companyId;
      }
    } else if (creatorRole === 'company_admin') {
      targetCompanyId = req.user.companyId;
      if (!['manager', 'team_leader', 'employee'].includes(targetRole)) {
        return res.status(400).json({ message: 'Company Admins can only create managers, team leaders, or employees.' });
      }
    } else if (creatorRole === 'manager' || creatorRole === 'team_leader') {
      targetCompanyId = req.user.companyId;
      const managedTeams = await Team.findAll({
        where: {
          [Op.or]: [
            { managerId: req.user.id },
            { teamLeaderId: req.user.id }
          ]
        },
        attributes: ['id']
      });
      const managedTeamIds = managedTeams.map(t => t.id);

      if (teamId) {
        const assignedTeamId = parseInt(teamId);
        if (!managedTeamIds.includes(assignedTeamId)) {
          return res.status(403).json({ message: 'You can only assign users to teams you manage or lead.' });
        }
        targetTeamId = assignedTeamId;
      } else {
        targetTeamId = managedTeamIds.length > 0 ? managedTeamIds[0] : req.user.teamId;
      }

      if (creatorRole === 'manager') {
        if (!['team_leader', 'employee'].includes(targetRole)) {
          return res.status(400).json({ message: 'Managers can only create team leaders or employees for their team.' });
        }
      } else {
        if (targetRole !== 'employee') {
          return res.status(400).json({ message: 'Team Leaders can only create employees for their team.' });
        }
      }
    } else {
      return res.status(403).json({ message: 'Unauthorized to create users' });
    }

    const existing = await User.findOne({ where: { email } });
    if (existing) return res.status(409).json({ message: 'Email already exists' });

    if (employeeId) {
      const existingEmp = await User.findOne({ where: { employeeId } });
      if (existingEmp) return res.status(409).json({ message: 'Employee ID already exists' });
    }

    // Normalize and validate workType/workMode (prevent ENUM validation errors)
    const normalizedWorkMode = normalizeEnum(workMode, VALID_WORK_MODES, 'Work From Office');
    let finalWorkType = null;
    if (department && department.toLowerCase() === 'marketing' && workType) {
      finalWorkType = normalizeEnum(workType, VALID_WORK_TYPES, null);
      if (!finalWorkType) {
        return res.status(400).json({ message: 'Invalid work type for marketing department.' });
      }
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await User.create({
      name,
      email,
      password: hashedPassword,
      role: targetRole,
      department,
      employeeId,
      profilePicture: profilePicture || null,
      isProfilePictureAdminSet: !!profilePicture,
      dob: dob || null,
      state: state || null,
      city: city || null,
      workMode: normalizedWorkMode,
      workType: finalWorkType,
      companyId: targetCompanyId || null,
      teamId: targetTeamId || null,
    });

    // Enforce manager/team leader uniqueness per team
    if (user.teamId && ['manager', 'team_leader'].includes(user.role)) {
      await User.update(
        { teamId: null },
        {
          where: {
            companyId: user.companyId,
            teamId: user.teamId,
            role: user.role,
            id: { [Op.ne]: user.id }
          }
        }
      );
    }

    // Fetch company name and team details for welcome email
    let companyName = '';
    let teamName = '';
    let managerName = '';
    let teamLeaderName = '';

    try {
      if (targetCompanyId) {
        const companyObj = await Company.findByPk(targetCompanyId);
        if (companyObj) companyName = companyObj.name || '';
      }
      if (user.teamId) {
        const teamObj = await Team.findByPk(user.teamId);
        if (teamObj) {
          teamName = teamObj.name || '';
          if (teamObj.managerId) {
            const mgr = await User.findByPk(teamObj.managerId);
            if (mgr) managerName = mgr.name || '';
          }
          if (teamObj.teamLeaderId) {
            const tl = await User.findByPk(teamObj.teamLeaderId);
            if (tl) teamLeaderName = tl.name || '';
          }
        }
      }
    } catch (err) {
      console.error('[Admin] Welcome email details fetch error:', err.message);
    }

    // Send branded welcome email with credentials and company name
    sendWelcomeEmail({
      name,
      email,
      password,
      employeeId,
      companyName,
      role: targetRole,
      workMode: user.workMode,
      workType: user.workType,
      department: user.department,
      teamName,
      managerName,
      teamLeaderName,
    }).catch((err) => {
      console.error('[Admin] Welcome email error:', err.message);
    });

    return res.status(201).json({ message: 'User created', user });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to create user', error: error.message });
  }
};

// Update user
const updateUser = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      name, email, employeeId, password,
      role, department, isActive,
      profilePicture, companyId, teamId,
      dob, state, city, workMode, workType
    } = req.body;

    const user = await User.findByPk(id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const creatorRole = req.user.role;

    // Check if creator can manage this user
    if (creatorRole === 'system_admin') {
      // system_admin can fully manage users in their own company.
      // For other companies, they can only manage company_admin accounts.
      if (user.companyId !== req.user.companyId) {
        if (user.role !== 'company_admin') {
          return res.status(403).json({ message: 'System Admins can only manage company_admin accounts from other companies.' });
        }
        // When updating another company's admin, prevent role downgrade
        if (role && role !== 'company_admin') {
          return res.status(403).json({ message: 'Cannot change the role of a company_admin from another company.' });
        }
      }
    } else if (creatorRole === 'company_admin') {
      if (user.companyId !== req.user.companyId) {
        return res.status(403).json({ message: 'You can only manage users in your company' });
      }
      if (role && !['manager', 'team_leader', 'employee'].includes(role)) {
        return res.status(400).json({ message: 'Invalid role update' });
      }
    } else if (creatorRole === 'manager' || creatorRole === 'team_leader') {
      const managedTeams = await Team.findAll({
        where: {
          [Op.or]: [
            { managerId: req.user.id },
            { teamLeaderId: req.user.id }
          ]
        },
        attributes: ['id']
      });
      const managedTeamIds = managedTeams.map(t => t.id);

      const isOwnProfile = user.id === req.user.id;
      const isTeamMember = user.teamId && managedTeamIds.includes(user.teamId);

      if (user.companyId !== req.user.companyId || (!isOwnProfile && !isTeamMember)) {
        return res.status(403).json({ message: 'You can only manage users in teams you manage or lead' });
      }

      if (teamId) {
        const targetTeamId = parseInt(teamId);
        if (!managedTeamIds.includes(targetTeamId)) {
          return res.status(403).json({ message: 'You can only move users to teams you manage or lead.' });
        }
      }

      if (creatorRole === 'manager') {
        if (role && !['team_leader', 'employee'].includes(role)) {
          return res.status(400).json({ message: 'Invalid role update' });
        }
      } else {
        if (role && role !== 'employee') {
          return res.status(400).json({ message: 'Invalid role update' });
        }
      }
    } else {
      return res.status(403).json({ message: 'Unauthorized' });
    }

    // --- Update email (check uniqueness) ---
    if (email !== undefined && email !== user.email) {
      const existingEmail = await User.findOne({ where: { email } });
      if (existingEmail) return res.status(409).json({ message: 'Email already in use' });
      user.email = email;
    }

    // --- Update employeeId (check uniqueness) ---
    if (employeeId !== undefined && employeeId !== user.employeeId) {
      const existingEmpId = await User.findOne({ where: { employeeId } });
      if (existingEmpId) return res.status(409).json({ message: 'Employee ID already in use' });
      user.employeeId = employeeId;
    }

    // --- Update password ---
    if (password) {
      user.password = await bcrypt.hash(password, 10);
    }

    // --- Update profile picture ---
    if (req.body.hasOwnProperty('profilePicture')) {
      user.profilePicture = profilePicture || null;
      user.isProfilePictureAdminSet = !!profilePicture;
    }

    // --- Update name ---
    if (name !== undefined) user.name = name;

    // --- Update department ---
    if (department !== undefined) user.department = department;

    // --- Update role ---
    if (role !== undefined) user.role = role;

    // --- Update isActive ---
    if (isActive !== undefined) user.isActive = isActive === true || isActive === 1 || isActive === 'true';

    // --- Update company/team (restricted by role) ---
    if (companyId !== undefined) {
      user.companyId = creatorRole === 'system_admin' ? companyId : req.user.companyId;
    }
    if (teamId !== undefined) {
      if (['system_admin', 'company_admin'].includes(creatorRole)) {
        user.teamId = (teamId === null || teamId === 0 || teamId === 'null' || teamId === '') ? null : teamId;
      } else {
        // If manager/TL wants to remove user from team, they can set teamId to null/0/empty
        if (teamId === null || teamId === 0 || teamId === 'null' || teamId === '') {
          user.teamId = null;
        } else {
          // Verify that they are assigning the user to one of their managed teams
          const managedTeams = await Team.findAll({
            where: {
              [Op.or]: [
                { managerId: req.user.id },
                { teamLeaderId: req.user.id }
              ]
            },
            attributes: ['id']
          });
          const managedTeamIds = managedTeams.map(t => t.id);
          const targetTeamId = parseInt(teamId);
          if (managedTeamIds.includes(targetTeamId)) {
            user.teamId = targetTeamId;
          } else {
            return res.status(403).json({ message: 'You can only move users to teams you manage or lead.' });
          }
        }
      }
    }

    // --- Update location/personal fields ---
    if (dob !== undefined) user.dob = dob;
    if (state !== undefined) user.state = state;
    if (city !== undefined) user.city = city;
    // Normalize workMode to exact ENUM value (prevent Sequelize ENUM validation errors)
    if (workMode !== undefined) {
      user.workMode = normalizeEnum(workMode, VALID_WORK_MODES, 'Work From Office');
    }

    // --- Update workType (marketing department only, normalized) ---
    const resolvedDepartment = department !== undefined ? department : user.department;
    if (workType !== undefined) {
      if (resolvedDepartment && resolvedDepartment.toLowerCase() === 'marketing') {
        user.workType = normalizeEnum(workType, VALID_WORK_TYPES, null);
      } else {
        user.workType = null;
      }
    } else if (resolvedDepartment && resolvedDepartment.toLowerCase() !== 'marketing') {
      // If department was changed away from marketing, clear workType
      user.workType = null;
    }

    await user.save();

    // Enforce manager/team leader uniqueness per team
    if (user.teamId && ['manager', 'team_leader'].includes(user.role)) {
      await User.update(
        { teamId: null },
        {
          where: {
            companyId: user.companyId,
            teamId: user.teamId,
            role: user.role,
            id: { [Op.ne]: user.id }
          }
        }
      );
    }

    return res.json({ message: 'User updated', user });
  } catch (error) {
    console.error('[updateUser] Error:', error);
    return res.status(500).json({ message: 'Failed to update user', error: error.message });
  }
};


// Delete/deactivate user
const deleteUser = async (req, res) => {
  try {
    const { id } = req.params;
    const user = await User.findByPk(id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const creatorRole = req.user.role;
    let allowed = false;

    if (creatorRole === 'system_admin') {
      // system_admin can only deactivate/delete users in their own company,
      // or company_admin accounts in other companies.
      if (user.companyId === req.user.companyId) {
        allowed = true;
      } else if (user.role === 'company_admin') {
        allowed = true;
      }
    } else if (creatorRole === 'company_admin') {
      if (user.companyId === req.user.companyId) allowed = true;
    } else if (creatorRole === 'manager' || creatorRole === 'team_leader') {
      const managedTeams = await Team.findAll({
        where: {
          [Op.or]: [
            { managerId: req.user.id },
            { teamLeaderId: req.user.id }
          ]
        },
        attributes: ['id']
      });
      const managedTeamIds = managedTeams.map(t => t.id);

      const isTeamMember = user.teamId && managedTeamIds.includes(user.teamId);

      if (user.companyId === req.user.companyId && isTeamMember) {
        if (creatorRole === 'manager' && ['team_leader', 'employee'].includes(user.role)) {
          allowed = true;
        } else if (creatorRole === 'team_leader' && user.role === 'employee') {
          allowed = true;
        }
      }
    }

    if (!allowed) {
      return res.status(403).json({ message: 'Unauthorized to delete this user' });
    }

    await user.update({ isActive: false });
    return res.json({ message: 'User deactivated' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete user', error: error.message });
  }
};

// Attendance stats
const attendanceStats = async (req, res) => {
  try {
    const { startDate, endDate, userId } = req.query;
    const creatorRole = req.user.role;
    const companyId = req.user.companyId;

    const userWhere = {};
    if (creatorRole === 'system_admin') {
      // system_admin only sees attendance stats for their own company
      userWhere.companyId = companyId;
    } else if (creatorRole === 'company_admin') {
      userWhere.companyId = companyId;
    } else if (creatorRole === 'manager' || creatorRole === 'team_leader') {
      userWhere.companyId = companyId;
      const managedTeams = await Team.findAll({
        where: {
          [Op.or]: [
            { managerId: req.user.id },
            { teamLeaderId: req.user.id }
          ]
        },
        attributes: ['id']
      });
      const managedTeamIds = managedTeams.map(t => t.id);
      
      userWhere[Op.or] = [
        { teamId: { [Op.in]: managedTeamIds } },
        { id: req.user.id }
      ];
    }

    if (userId) {
      if (['manager', 'team_leader'].includes(creatorRole)) {
        const managedTeams = await Team.findAll({
          where: {
            [Op.or]: [
              { managerId: req.user.id },
              { teamLeaderId: req.user.id }
            ]
          },
          attributes: ['id']
        });
        const managedTeamIds = managedTeams.map(t => t.id);

        const targetUser = await User.findByPk(userId);
        if (!targetUser || (targetUser.id !== req.user.id && (!targetUser.teamId || !managedTeamIds.includes(targetUser.teamId)))) {
          return res.status(403).json({ message: 'You are not authorized to view stats for this user.' });
        }
      }
      userWhere.id = userId;
    }

    const matchedUsers = await User.findAll({ where: userWhere, attributes: ['id'] });
    const userIds = matchedUsers.map(u => u.id);

    if (userIds.length === 0) {
      return res.json({ totalPresent: 0, totalLate: 0, totalHalfDay: 0, totalAbsent: 0, attendanceRate: 0, totalUsers: 0 });
    }

    const where = { userId: { [Op.in]: userIds } };
    if (startDate || endDate) {
      where.date = {};
      if (startDate) where.date[Op.gte] = startDate;
      if (endDate) where.date[Op.lte] = endDate;
    }

    const totalPresent = await Attendance.count({ where: { ...where, status: 'present' } });
    const totalLate = await Attendance.count({ where: { ...where, status: 'late' } });
    const totalHalfDay = await Attendance.count({ where: { ...where, status: 'half_day' } });
    const totalAbsent = await Attendance.count({ where: { ...where, status: 'absent' } });
    const total = totalPresent + totalLate + totalHalfDay + totalAbsent || 1;
    const attendanceRate = Math.round(((totalPresent + totalLate + totalHalfDay) / total) * 100);
    const totalUsers = userIds.length;

    return res.json({ totalPresent, totalLate, totalHalfDay, totalAbsent, attendanceRate, totalUsers });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch stats', error: error.message });
  }
};

// Export report
const exportReport = async (req, res) => {
  try {
    const { startDate, endDate, userId } = req.query;
    const creatorRole = req.user.role;
    const companyId = req.user.companyId;

    const userWhere = {};
    if (creatorRole === 'system_admin') {
      userWhere.companyId = companyId;
    } else if (creatorRole === 'company_admin') {
      userWhere.companyId = companyId;
    } else if (creatorRole === 'manager' || creatorRole === 'team_leader') {
      userWhere.companyId = companyId;
      const managedTeams = await Team.findAll({
        where: {
          [Op.or]: [
            { managerId: req.user.id },
            { teamLeaderId: req.user.id }
          ]
        },
        attributes: ['id']
      });
      const managedTeamIds = managedTeams.map(t => t.id);
      
      userWhere[Op.or] = [
        { teamId: { [Op.in]: managedTeamIds } },
        { id: req.user.id }
      ];
    }

    if (userId) {
      if (['manager', 'team_leader'].includes(creatorRole)) {
        const managedTeams = await Team.findAll({
          where: {
            [Op.or]: [
              { managerId: req.user.id },
              { teamLeaderId: req.user.id }
            ]
          },
          attributes: ['id']
        });
        const managedTeamIds = managedTeams.map(t => t.id);

        const targetUser = await User.findByPk(userId);
        if (!targetUser || (targetUser.id !== req.user.id && (!targetUser.teamId || !managedTeamIds.includes(targetUser.teamId)))) {
          return res.status(403).json({ message: 'You are not authorized to view stats for this user.' });
        }
      }
      userWhere.id = userId;
    }

    const matchedUsers = await User.findAll({
      where: userWhere,
      attributes: ['id', 'name', 'email', 'department'],
      order: [['name', 'ASC']]
    });
    const userIds = matchedUsers.map(u => u.id);

    // Parse timezone-safe date range
    const parseLocalDate = (dateStr, isEnd = false) => {
      if (!dateStr) {
        const now = new Date();
        return isEnd ? new Date(now.getFullYear(), now.getMonth() + 1, 0) : new Date(now.getFullYear(), now.getMonth(), 1);
      }
      const [y, m, d] = dateStr.split('-').map(Number);
      return new Date(y, m - 1, d);
    };

    const startDt = parseLocalDate(startDate, false);
    const endDt = parseLocalDate(endDate, true);

    const dates = [];
    let curr = new Date(startDt);
    while (curr <= endDt) {
      const yyyy = curr.getFullYear();
      const mm = String(curr.getMonth() + 1).padStart(2, '0');
      const dd = String(curr.getDate()).padStart(2, '0');
      dates.push(`${yyyy}-${mm}-${dd}`);
      curr.setDate(curr.getDate() + 1);
    }

    if (userIds.length === 0 || dates.length === 0) {
      const headerParts = ['Name', 'Email', 'Department', 'Total Working Hours', 'Total Overtime'];
      for (let i = 0; i < dates.length; i++) {
        headerParts.push((i + 1).toString(), `${i + 1} Sessions`);
      }
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename="attendance.csv"');
      return res.send(headerParts.join(',') + '\n');
    }

    // Query necessary databases
    const records = await Attendance.findAll({
      where: {
        userId: { [Op.in]: userIds },
        date: { [Op.between]: [dates[0], dates[dates.length - 1]] }
      }
    });

    const holidays = await Holiday.findAll({
      where: {
        companyId,
        date: { [Op.between]: [dates[0], dates[dates.length - 1]] },
        isActive: true
      }
    });
    const holidayDates = new Set(holidays.map(h => h.date));

    const leaves = await Leave.findAll({
      where: {
        userId: { [Op.in]: userIds },
        status: 'approved',
        [Op.or]: [
          { startDate: { [Op.between]: [dates[0], dates[dates.length - 1]] } },
          { endDate: { [Op.between]: [dates[0], dates[dates.length - 1]] } },
          {
            startDate: { [Op.lte]: dates[0] },
            endDate: { [Op.gte]: dates[dates.length - 1] }
          }
        ]
      }
    });

    // Build CSV Header
    const headerParts = ['Name', 'Email', 'Department', 'Total Working Hours', 'Total Overtime'];
    for (let i = 0; i < dates.length; i++) {
      headerParts.push((i + 1).toString(), `${i + 1} Sessions`);
    }
    const header = headerParts.join(',') + '\n';

    // Build rows for each employee
    const rows = [];
    for (const emp of matchedUsers) {
      let monthlyTotalHours = 0.0;
      let monthlyOvertimeHours = 0.0;

      const rowParts = [
        (emp.name || '').replace(/,/g, ';'),
        (emp.email || '').replace(/,/g, ';'),
        (emp.department || 'N/A').replace(/,/g, ';'),
        '', // Placeholder for Total Working Hours
        ''  // Placeholder for Total Overtime
      ];
      const totalHoursIndex = 3;
      const totalOvertimeIndex = 4;

      for (let i = 0; i < dates.length; i++) {
        const datePrefix = dates[i];
        const daySessions = records.filter(r => r.userId === emp.id && r.date === datePrefix);

        const hasApprovedLeave = leaves.some(l => {
          if (l.userId !== emp.id) return false;
          return datePrefix >= l.startDate && datePrefix <= l.endDate;
        });

        const [yr, mn, dy] = datePrefix.split('-').map(Number);
        const dtObj = new Date(yr, mn - 1, dy);
        const dayOfWeek = dtObj.getDay();
        const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;

        let status = '';
        let sessionsText = '';

        if (daySessions.length === 0) {
          if (hasApprovedLeave) {
            status = 'L';
          } else {
            if (holidayDates.has(datePrefix)) {
              status = 'H';
            } else if (isWeekend) {
              status = 'WE';
            } else {
              status = 'AB';
            }
          }
        } else {
          const hasHalfDay = daySessions.some(s => s.status && s.status.toLowerCase() === 'half_day');
          status = hasHalfDay ? 'HD' : 'P';

          let dayHours = 0.0;
          let dayOtHours = 0.0;
          const sessionIntervals = [];

          for (const s of daySessions) {
            const formatTime = (dtStr) => {
              if (!dtStr) return 'N/A';
              const dt = new Date(dtStr);
              let hrs = dt.getHours();
              const mins = String(dt.getMinutes()).padStart(2, '0');
              const ampm = hrs >= 12 ? 'PM' : 'AM';
              hrs = hrs % 12;
              hrs = hrs ? hrs : 12;
              return `${String(hrs).padStart(2, '0')}:${mins} ${ampm}`;
            };

            const checkInStr = s.checkInTime ? formatTime(s.checkInTime) : 'N/A';
            const checkOutStr = s.checkOutTime ? formatTime(s.checkOutTime) : 'Active';
            sessionIntervals.push(`${checkInStr}-${checkOutStr}`);

            if (s.checkInTime) {
              const endDt = s.checkOutTime ? new Date(s.checkOutTime) : new Date();
              const startDt = new Date(s.checkInTime);
              dayHours += (endDt - startDt) / (1000 * 60 * 60);
            }

            if (s.overtimeDuration) {
              const otMatch = s.overtimeDuration.match(/(\d+)\s*h\s*(\d+)\s*m/);
              if (otMatch) {
                const h = parseInt(otMatch[1], 10);
                const m = parseInt(otMatch[2], 10);
                dayOtHours += h + (m / 60.0);
              } else {
                const num = parseFloat(s.overtimeDuration);
                if (!isNaN(num)) {
                  dayOtHours += num;
                }
              }
            }
          }

          sessionsText = `${sessionIntervals.join("; ")} [${dayHours.toFixed(2)} hrs]`;
          monthlyTotalHours += dayHours;
          monthlyOvertimeHours += dayOtHours;
        }

        rowParts.push(status);
        rowParts.push(`"${sessionsText.replace(/"/g, '""')}"`);
      }

      rowParts[totalHoursIndex] = `${monthlyTotalHours.toFixed(2)} hrs`;
      rowParts[totalOvertimeIndex] = `${monthlyOvertimeHours.toFixed(2)} hrs`;
      rows.push(rowParts.join(','));
    }

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="attendance.csv"');
    return res.send(header + rows.join('\n'));
  } catch (error) {
    return res.status(500).json({ message: 'Failed to export report', error: error.message });
  }
};

// Company controllers (System Admin only)
const listCompanies = async (req, res) => {
  try {
    if (req.user.role !== 'system_admin') {
      return res.status(403).json({ message: 'Only System Admins can view companies.' });
    }
    const companies = await Company.findAll({ order: [['name', 'ASC']] });

    // For each company, attach aggregate stats and the company_admin profiles
    const enrichedCompanies = await Promise.all(
      companies.map(async (company) => {
        const companyData = company.toJSON();

        // Get company admin profiles
        const admins = await User.findAll({
          where: { companyId: company.id, role: 'company_admin', isActive: true },
          attributes: ['id', 'name', 'email', 'employeeId', 'profilePicture']
        });

        // Get counts per role for this company
        const teamsCount = await require('../models/Team').count({ where: { companyId: company.id } });
        const managersCount = await User.count({ where: { companyId: company.id, role: 'manager', isActive: true } });
        const teamLeadersCount = await User.count({ where: { companyId: company.id, role: 'team_leader', isActive: true } });
        const employeesCount = await User.count({ where: { companyId: company.id, role: 'employee', isActive: true } });

        return {
          ...companyData,
          admins,
          teamsCount,
          managersCount,
          teamLeadersCount,
          employeesCount
        };
      })
    );

    return res.json({ companies: enrichedCompanies });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch companies', error: error.message });
  }
};

const createCompany = async (req, res) => {
  try {
    if (req.user.role !== 'system_admin') {
      return res.status(403).json({ message: 'Only System Admins can create companies.' });
    }
    const { name, adminName, adminEmail, adminPassword } = req.body;
    if (!name) {
      return res.status(400).json({ message: 'Company name is required.' });
    }

    const [company, created] = await Company.findOrCreate({
      where: { name },
      defaults: { isActive: true }
    });

    if (!created) {
      return res.status(409).json({ message: 'Company with this name already exists.' });
    }

    // Initialize company settings
    await CompanySetting.create({
      companyId: company.id,
      checkInTime: '09:00:00',
      checkOutTime: '18:00:00',
      latitude: 0.0,
      longitude: 0.0,
      address: null,
      radius: 100.0
    });

    // Optionally create the company admin account
    let adminUser = null;
    if (adminName && adminEmail && adminPassword) {
      const existingUser = await User.findOne({ where: { email: adminEmail } });
      if (existingUser) {
        return res.status(201).json({
          message: 'Company created, but admin email already registered.',
          company
        });
      }
      const hashedPassword = await bcrypt.hash(adminPassword, 10);
      adminUser = await User.create({
        name: adminName,
        email: adminEmail,
        password: hashedPassword,
        role: 'company_admin',
        isActive: true,
        companyId: company.id
      });

      // Send rich company-admin welcome email with company details
      sendCompanyAdminWelcomeEmail({
        adminName,
        adminEmail,
        adminPassword,
        companyName: company.name,
        companyAddress: null, // default from CompanySetting creation above
        checkInTime:  '09:00 AM',
        checkOutTime: '06:00 PM',
      }).catch((err) => {
        console.error('[Admin] Company admin welcome email error:', err.message);
      });
    }

    return res.status(201).json({
      message: 'Company created successfully',
      company,
      adminUser
    });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to create company', error: error.message });
  }
};

const approveCompany = async (req, res) => {
  try {
    if (req.user.role !== 'system_admin') {
      return res.status(403).json({ message: 'Only System Admins can approve companies.' });
    }
    const { id } = req.params;
    const company = await Company.findByPk(id);
    if (!company) {
      return res.status(404).json({ message: 'Company not found.' });
    }

    company.status = 'approved';
    company.isActive = true;
    await company.save();

    // Find company admin
    const adminUser = await User.findOne({
      where: { companyId: company.id, role: 'company_admin' }
    });

    if (adminUser) {
      const { sendCompanyApprovalEmail } = require('../services/mailService');
      await sendCompanyApprovalEmail({
        adminName: adminUser.name,
        adminEmail: adminUser.email,
        companyName: company.name,
        createdDate: company.createdAt,
      });
    }

    return res.json({ message: 'Company approved successfully.' });
  } catch (error) {
    console.error('[Admin] Approve company error:', error);
    return res.status(500).json({ message: 'Failed to approve company.', error: error.message });
  }
};

const rejectCompany = async (req, res) => {
  try {
    if (req.user.role !== 'system_admin') {
      return res.status(403).json({ message: 'Only System Admins can reject companies.' });
    }
    const { id } = req.params;
    const { reason } = req.body;

    if (!reason || reason.trim() === '') {
      return res.status(400).json({ message: 'Rejection reason is required.' });
    }

    const company = await Company.findByPk(id);
    if (!company) {
      return res.status(404).json({ message: 'Company not found.' });
    }

    company.status = 'rejected';
    company.isActive = false;
    company.rejectionReason = reason;
    await company.save();

    // Find company admin
    const adminUser = await User.findOne({
      where: { companyId: company.id, role: 'company_admin' }
    });

    if (adminUser) {
      const { sendCompanyRejectionEmail } = require('../services/mailService');
      await sendCompanyRejectionEmail({
        adminName: adminUser.name,
        adminEmail: adminUser.email,
        companyName: company.name,
        rejectionReason: reason,
        createdDate: company.createdAt,
      });
    }

    return res.json({ message: 'Company rejected successfully.' });
  } catch (error) {
    console.error('[Admin] Reject company error:', error);
    return res.status(500).json({ message: 'Failed to reject company.', error: error.message });
  }
};

// Team controllers (Company Admin, System Admin, Manager, TL)
const listTeams = async (req, res) => {
  try {
    const creatorRole = req.user.role;
    const { companyId } = req.query;

    // system_admin is restricted to listing teams for their own company only
    let targetCompanyId = req.user.companyId;
    if (creatorRole === 'company_admin' || creatorRole === 'manager' || creatorRole === 'team_leader') {
      targetCompanyId = req.user.companyId;
    } else if (creatorRole !== 'system_admin' && companyId) {
      targetCompanyId = companyId;
    }

    if (!targetCompanyId) {
      return res.status(400).json({ message: 'Company ID is required.' });
    }

    const teams = await Team.findAll({
      where: { companyId: targetCompanyId },
      order: [['name', 'ASC']]
    });

    const enrichedTeams = await Promise.all(
      teams.map(async (team) => {
        const teamData = team.toJSON();
        const manager = team.managerId ? await User.findOne({
          where: { id: team.managerId, isActive: true },
          attributes: ['id', 'name', 'email', 'employeeId']
        }) : null;
        const teamLeader = team.teamLeaderId ? await User.findOne({
          where: { id: team.teamLeaderId, isActive: true },
          attributes: ['id', 'name', 'email', 'employeeId']
        }) : null;
        const membersCount = await User.count({
          where: { teamId: team.id, isActive: true }
        });
        return {
          ...teamData,
          manager,
          teamLeader,
          membersCount
        };
      })
    );

    return res.json({ teams: enrichedTeams });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch teams', error: error.message });
  }
};

const createTeam = async (req, res) => {
  try {
    const creatorRole = req.user.role;
    if (!['system_admin', 'company_admin'].includes(creatorRole)) {
      return res.status(403).json({ message: 'Only Admins can create teams.' });
    }

    const { name, companyId } = req.body;
    if (!name) {
      return res.status(400).json({ message: 'Team name is required.' });
    }

    // system_admin can only create teams for their own company
    let targetCompanyId = req.user.companyId;
    if (creatorRole === 'company_admin') {
      targetCompanyId = req.user.companyId;
    }

    if (!targetCompanyId) {
      return res.status(400).json({ message: 'Company ID is required.' });
    }

    const [team, created] = await Team.findOrCreate({
      where: { name, companyId: targetCompanyId }
    });

    if (!created) {
      return res.status(409).json({ message: 'Team already exists in this company.' });
    }

    return res.status(201).json({ message: 'Team created successfully', team });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to create team', error: error.message });
  }
};

const updateTeam = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, managerId, teamLeaderId } = req.body;

    const team = await Team.findByPk(id);
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    // Verify creator can manage this company's teams
    const creatorRole = req.user.role;
    if (team.companyId !== req.user.companyId) {
      return res.status(403).json({ message: 'Unauthorized to modify this team' });
    }

    if (name !== undefined) {
      if (!name) {
        return res.status(400).json({ message: 'Team name is required.' });
      }
      team.name = name;
    }

    if (managerId !== undefined) {
      team.managerId = managerId;
      if (managerId) {
        // Automatically make sure the user role is updated to manager
        await User.update({ role: 'manager' }, { where: { id: managerId } });
      }
    }

    if (teamLeaderId !== undefined) {
      team.teamLeaderId = teamLeaderId;
      if (teamLeaderId) {
        // Automatically make sure the user role is updated to team_leader
        await User.update({ role: 'team_leader' }, { where: { id: teamLeaderId } });
      }
    }

    await team.save();

    return res.json({ message: 'Team updated successfully', team });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update team', error: error.message });
  }
};

const deleteTeam = async (req, res) => {
  try {
    const { id } = req.params;
    const team = await Team.findByPk(id);
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    // Verify creator can manage this company's teams
    const creatorRole = req.user.role;
    if (team.companyId !== req.user.companyId) {
      return res.status(403).json({ message: 'Unauthorized to delete this team' });
    }

    // Set teamId = null for all users associated with this team
    await User.update(
      { teamId: null },
      { where: { teamId: team.id } }
    );

    await team.destroy();

    return res.json({ message: 'Team deleted successfully' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete team', error: error.message });
  }
};

// Company Settings (Company Admin, System Admin)
const getCompanySettings = async (req, res) => {
  try {
    const creatorRole = req.user.role;
    const { companyId } = req.query;

    let targetCompanyId = req.user.companyId;
    if (creatorRole === 'system_admin' && companyId) {
      targetCompanyId = parseInt(companyId);
    }

    if (!targetCompanyId) {
      return res.status(400).json({ message: 'Company ID is required.' });
    }

    const setting = await CompanySetting.findOne({ where: { companyId: targetCompanyId } });
    if (!setting) {
      return res.status(404).json({ message: 'Company settings not found.' });
    }

    return res.json({ settings: setting });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch company settings', error: error.message });
  }
};

const updateCompanySettings = async (req, res) => {
  try {
    const creatorRole = req.user.role;
    if (!['system_admin', 'company_admin'].includes(creatorRole)) {
      return res.status(403).json({ message: 'Only Admins can update company settings.' });
    }

    const {
      companyId,
      checkInTime,
      checkOutTime,
      latitude,
      longitude,
      address,
      radius,
      monthlyPaidLeaves,
      yearlyPaidLeaves,
      leavesRefreshMonth,
      leavesRefreshDay
    } = req.body;

    let targetCompanyId = req.user.companyId;
    if (creatorRole === 'system_admin' && companyId) {
      targetCompanyId = parseInt(companyId);
    }

    if (!targetCompanyId) {
      return res.status(400).json({ message: 'Company ID is required.' });
    }

    const [setting] = await CompanySetting.findOrCreate({
      where: { companyId: targetCompanyId }
    });

    if (checkInTime !== undefined) setting.checkInTime = checkInTime;
    if (checkOutTime !== undefined) setting.checkOutTime = checkOutTime;
    if (latitude !== undefined) setting.latitude = parseFloat(latitude);
    if (longitude !== undefined) setting.longitude = parseFloat(longitude);
    if (address !== undefined) setting.address = address;
    if (radius !== undefined) setting.radius = parseFloat(radius);
    if (monthlyPaidLeaves !== undefined) setting.monthlyPaidLeaves = parseInt(monthlyPaidLeaves);
    if (yearlyPaidLeaves !== undefined) setting.yearlyPaidLeaves = parseInt(yearlyPaidLeaves);
    if (leavesRefreshMonth !== undefined) setting.leavesRefreshMonth = parseInt(leavesRefreshMonth);
    if (leavesRefreshDay !== undefined) setting.leavesRefreshDay = parseInt(leavesRefreshDay);

    await setting.save();

    return res.json({ message: 'Company settings updated successfully', settings: setting });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update company settings', error: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// Add an existing user to a team without creating a new account.
// This solves the use-case where a manager/TL who is already registered needs
// to be a member of another team (e.g. as a plain employee/member).
//
// Business rules:
//   - company_admin / system_admin → can add any user in their company to any
//     team within the same company.
//   - manager / team_leader        → can only add users to teams they manage
//     or lead. The target user must also belong to the same company.
//
// NOTE: Adding a user to a team does NOT change their role. A manager can be
// added to another team and will simply appear as a regular member of that team
// while retaining their manager role (and their own managed team).
// ─────────────────────────────────────────────────────────────────────────────
const addTeamMember = async (req, res) => {
  try {
    const { teamId, userId } = req.body;

    if (!teamId || !userId) {
      return res.status(400).json({ message: 'teamId and userId are required.' });
    }

    const creatorRole = req.user.role;

    // Fetch the target team
    const team = await Team.findByPk(teamId);
    if (!team) {
      return res.status(404).json({ message: 'Team not found.' });
    }

    // Fetch the user to be added
    const targetUser = await User.findByPk(userId);
    if (!targetUser) {
      return res.status(404).json({ message: 'User not found.' });
    }

    // Both team and user must belong to the same company as the requester
    if (team.companyId !== req.user.companyId) {
      return res.status(403).json({ message: 'You can only manage teams within your own company.' });
    }
    if (targetUser.companyId !== req.user.companyId) {
      return res.status(403).json({ message: 'The user must belong to the same company.' });
    }

    if (creatorRole === 'manager' || creatorRole === 'team_leader') {
      // Manager / TL can only assign users to teams they manage or lead
      const managedTeams = await Team.findAll({
        where: {
          [Op.or]: [
            { managerId: req.user.id },
            { teamLeaderId: req.user.id },
          ],
        },
        attributes: ['id'],
      });
      const managedTeamIds = managedTeams.map(t => t.id);

      if (!managedTeamIds.includes(parseInt(teamId))) {
        return res.status(403).json({ message: 'You can only add members to teams you manage or lead.' });
      }
    } else if (!['system_admin', 'company_admin'].includes(creatorRole)) {
      return res.status(403).json({ message: 'Unauthorized.' });
    }

    // Assign the user to the team (preserves their existing role)
    await targetUser.update({ teamId: parseInt(teamId) });

    return res.json({
      message: `${targetUser.name} has been successfully added to team "${team.name}".`,
      user: {
        id: targetUser.id,
        name: targetUser.name,
        email: targetUser.email,
        role: targetUser.role,
        teamId: targetUser.teamId,
      },
    });
  } catch (error) {
    console.error('[addTeamMember] Error:', error);
    return res.status(500).json({ message: 'Failed to add team member', error: error.message });
  }
};

const downloadUserTemplate = async (req, res) => {
  try {
    const path = require('path');
    const templatePath = path.join(__dirname, '..', 'employees_template.xlsx');
    return res.download(templatePath, 'employees_template.xlsx');
  } catch (error) {
    console.error('[Template Download] Error:', error);
    return res.status(500).json({ message: 'Failed to download template', error: error.message });
  }
};

const bulkUploadUsers = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded.' });
    }

    const creatorRole = req.user.role;
    const creatorCompanyId = req.user.companyId;

    if (!['system_admin', 'company_admin'].includes(creatorRole)) {
      return res.status(403).json({ message: 'Only administrators can perform bulk uploads.' });
    }

    const XLSX = require('xlsx');
    const bcrypt = require('bcryptjs');

    // Load workbook
    const workbook = XLSX.readFile(req.file.path);
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];

    // Convert rows to array of objects
    const rawRows = XLSX.utils.sheet_to_json(sheet);
    if (rawRows.length === 0) {
      return res.status(400).json({ message: 'The uploaded file is empty.' });
    }

    const createdUsers = [];
    const errors = [];

    // Valid option sets
    const VALID_ROLES = ['manager', 'team_leader', 'employee'];
    const VALID_WORK_MODES = ['Work From Office', 'Work From Home', 'Remote Work'];
    const VALID_WORK_TYPES = ['Field Work', 'Work From Office', 'Office + Field Work'];

    for (let index = 0; index < rawRows.length; index++) {
      const row = rawRows[index];
      const rowNum = index + 2; // Row number in sheet (1-based + 1 for header)

      // Normalize headers using case-insensitive mapping
      const getVal = (keys) => {
        for (const k of keys) {
          const matchingKey = Object.keys(row).find(rk => rk.trim().toLowerCase().includes(k.toLowerCase()));
          if (matchingKey && row[matchingKey] !== undefined) {
            return String(row[matchingKey]).trim();
          }
        }
        return '';
      };

      const name = getVal(['name']);
      const email = getVal(['email']);
      const password = getVal(['password']);
      const employeeId = getVal(['employee id', 'employeeid', 'empid', 'id']);
      const department = getVal(['department', 'dept']);
      const roleStr = getVal(['role']) || 'employee';
      const workModeStr = getVal(['work mode', 'workmode']) || 'Work From Office';
      const workTypeStr = getVal(['work type', 'worktype']);
      const dobStr = getVal(['date of birth', 'dob', 'birth']);
      const state = getVal(['state']);
      const city = getVal(['city']);

      // 1. Mandatory Validations
      if (!name) {
        errors.push(`Row ${rowNum}: Name is required.`);
        continue;
      }
      if (!email) {
        errors.push(`Row ${rowNum}: Email is required.`);
        continue;
      }
      // Simple regex check
      if (!/^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/.test(email)) {
        errors.push(`Row ${rowNum}: Invalid email format ("${email}").`);
        continue;
      }
      if (!password) {
        errors.push(`Row ${rowNum}: Password is required.`);
        continue;
      }
      if (password.length < 6) {
        errors.push(`Row ${rowNum}: Password must be at least 6 characters.`);
        continue;
      }
      if (!employeeId) {
        errors.push(`Row ${rowNum}: Employee ID is required.`);
        continue;
      }
      if (!department) {
        errors.push(`Row ${rowNum}: Department is required.`);
        continue;
      }

      // Check unique email in DB
      const existingEmail = await User.findOne({ where: { email } });
      if (existingEmail) {
        errors.push(`Row ${rowNum}: Email "${email}" is already registered.`);
        continue;
      }

      // Check unique employeeId in DB
      const existingEmpId = await User.findOne({ where: { employeeId } });
      if (existingEmpId) {
        errors.push(`Row ${rowNum}: Employee ID "${employeeId}" already exists.`);
        continue;
      }

      // Role check
      const normalizedRole = roleStr.toLowerCase().replace(' ', '_');
      if (!VALID_ROLES.includes(normalizedRole)) {
        errors.push(`Row ${rowNum}: Invalid role "${roleStr}". Allowed values: Manager, Team Leader, Employee.`);
        continue;
      }

      // Work mode check
      const matchedWorkMode = VALID_WORK_MODES.find(wm => wm.toLowerCase() === workModeStr.toLowerCase()) || 'Work From Office';

      // Marketing work type check
      let finalWorkType = null;
      if (department.toLowerCase() === 'marketing') {
        if (!workTypeStr) {
          errors.push(`Row ${rowNum}: Work Type is required for Marketing department.`);
          continue;
        }
        // Normalize common spelling variants
        let checkType = workTypeStr.toLowerCase().replace(/[\s\+]/g, '');
        if (checkType === 'fieldwork') finalWorkType = 'Field Work';
        else if (checkType === 'officework' || checkType === 'workfromoffice') finalWorkType = 'Work From Office';
        else if (checkType === 'officefieldwork' || checkType === 'officefield') finalWorkType = 'Office + Field Work';

        if (!finalWorkType) {
          errors.push(`Row ${rowNum}: Invalid work type "${workTypeStr}" for Marketing. Allowed values: Field Work, Work From Office, Office + Field Work.`);
          continue;
        }
      }

      // DOB format check
      let finalDob = null;
      if (dobStr) {
        const testDob = new Date(dobStr);
        if (isNaN(testDob.getTime())) {
          errors.push(`Row ${rowNum}: Invalid DOB format ("${dobStr}"). Use YYYY-MM-DD.`);
          continue;
        }
        finalDob = dobStr;
      }

      // Hash password
      const hashedPassword = await bcrypt.hash(password, 10);

      // Create user (forced to admin's companyId)
      const newUser = await User.create({
        name,
        email,
        password: hashedPassword,
        role: normalizedRole,
        department,
        employeeId,
        workMode: matchedWorkMode,
        workType: finalWorkType,
        dob: finalDob,
        state: state || null,
        city: city || null,
        companyId: creatorCompanyId,
        isActive: true
      });

      // Send welcome email in background
      let companyName = '';
      try {
        if (creatorCompanyId) {
          const companyObj = await Company.findByPk(creatorCompanyId);
          if (companyObj) companyName = companyObj.name || '';
        }
      } catch (err) {}

      const { sendWelcomeEmail } = require('../services/mailService');
      sendWelcomeEmail({
        name,
        email,
        password,
        employeeId,
        companyName,
        role: normalizedRole,
        workMode: matchedWorkMode,
        workType: finalWorkType,
        department
      }).catch(err => console.error('[Bulk Welcome Email] Error:', err.message));

      createdUsers.push(newUser);
    }

    // Clean up temp file
    const fs = require('fs');
    fs.unlink(req.file.path, () => {});

    return res.json({
      success: true,
      insertedCount: createdUsers.length,
      failedCount: errors.length,
      errors
    });
  } catch (error) {
    console.error('[Bulk Upload] Error:', error);
    if (req.file && req.file.path) {
      const fs = require('fs');
      try { fs.unlinkSync(req.file.path); } catch (e) {}
    }
    return res.status(500).json({ message: 'Bulk upload failed', error: error.message });
  }
};

// --- Shift Controller Actions ---

// Create Shift (Admin only)
const createShift = async (req, res) => {
  try {
    const creatorRole = req.user.role;
    if (!['system_admin', 'company_admin'].includes(creatorRole)) {
      return res.status(403).json({ message: 'Only Admins can create shifts.' });
    }

    const { name, checkInTime, checkOutTime, lateInLimit, lateOutLimit, earlyInLimit, earlyOutLimit } = req.body;
    if (!name || !checkInTime || !checkOutTime) {
      return res.status(400).json({ message: 'Name, check-in time, and check-out time are required.' });
    }

    const targetCompanyId = req.user.companyId;
    if (!targetCompanyId) {
      return res.status(400).json({ message: 'Company ID is required.' });
    }

    const shift = await Shift.create({
      companyId: targetCompanyId,
      name,
      checkInTime,
      checkOutTime,
      lateInLimit: lateInLimit !== undefined ? parseInt(lateInLimit) : 15,
      lateOutLimit: lateOutLimit !== undefined ? parseInt(lateOutLimit) : 15,
      earlyInLimit: earlyInLimit !== undefined ? parseInt(earlyInLimit) : 15,
      earlyOutLimit: earlyOutLimit !== undefined ? parseInt(earlyOutLimit) : 15,
      isActive: true
    });

    return res.status(201).json({ message: 'Shift created successfully', shift });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to create shift', error: error.message });
  }
};

// Update Shift (Admin only)
const updateShift = async (req, res) => {
  try {
    const creatorRole = req.user.role;
    if (!['system_admin', 'company_admin'].includes(creatorRole)) {
      return res.status(403).json({ message: 'Only Admins can update shifts.' });
    }

    const { id, name, checkInTime, checkOutTime, lateInLimit, lateOutLimit, earlyInLimit, earlyOutLimit, isActive } = req.body;
    if (!id) {
      return res.status(400).json({ message: 'Shift ID is required.' });
    }

    const shift = await Shift.findByPk(id);
    if (!shift) {
      return res.status(404).json({ message: 'Shift not found.' });
    }

    if (shift.companyId !== req.user.companyId) {
      return res.status(403).json({ message: 'Unauthorized to modify this shift.' });
    }

    if (name !== undefined) shift.name = name;
    if (checkInTime !== undefined) shift.checkInTime = checkInTime;
    if (checkOutTime !== undefined) shift.checkOutTime = checkOutTime;
    if (lateInLimit !== undefined) shift.lateInLimit = parseInt(lateInLimit);
    if (lateOutLimit !== undefined) shift.lateOutLimit = parseInt(lateOutLimit);
    if (earlyInLimit !== undefined) shift.earlyInLimit = parseInt(earlyInLimit);
    if (earlyOutLimit !== undefined) shift.earlyOutLimit = parseInt(earlyOutLimit);
    if (isActive !== undefined) shift.isActive = isActive === true || isActive === 'true';

    await shift.save();

    return res.json({ message: 'Shift updated successfully', shift });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update shift', error: error.message });
  }
};

// Delete/Deactivate Shift (Admin only)
const deleteShift = async (req, res) => {
  try {
    const creatorRole = req.user.role;
    if (!['system_admin', 'company_admin'].includes(creatorRole)) {
      return res.status(403).json({ message: 'Only Admins can delete shifts.' });
    }

    const { id } = req.body;
    if (!id) {
      return res.status(400).json({ message: 'Shift ID is required.' });
    }

    const shift = await Shift.findByPk(id);
    if (!shift) {
      return res.status(404).json({ message: 'Shift not found.' });
    }

    if (shift.companyId !== req.user.companyId) {
      return res.status(403).json({ message: 'Unauthorized to modify this shift.' });
    }

    shift.isActive = false;
    await shift.save();

    return res.json({ message: 'Shift deleted successfully' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete shift', error: error.message });
  }
};

// Assign Default Shift to User (Admin only)
const assignShift = async (req, res) => {
  try {
    const creatorRole = req.user.role;
    if (!['system_admin', 'company_admin'].includes(creatorRole)) {
      return res.status(403).json({ message: 'Only Admins can assign shifts.' });
    }

    const { userId, shiftId } = req.body;
    if (!userId) {
      return res.status(400).json({ message: 'User ID is required.' });
    }

    const targetUser = await User.findByPk(userId);
    if (!targetUser) {
      return res.status(404).json({ message: 'User not found.' });
    }

    if (targetUser.companyId !== req.user.companyId) {
      return res.status(403).json({ message: 'User must belong to your company.' });
    }

    if (shiftId) {
      const shift = await Shift.findByPk(shiftId);
      if (!shift) {
        return res.status(404).json({ message: 'Shift not found.' });
      }
      if (shift.companyId !== req.user.companyId) {
        return res.status(403).json({ message: 'Shift must belong to your company.' });
      }
      targetUser.defaultShiftId = parseInt(shiftId);
    } else {
      targetUser.defaultShiftId = null;
    }

    await targetUser.save();

    return res.json({ message: 'Shift assigned successfully', user: { id: targetUser.id, defaultShiftId: targetUser.defaultShiftId } });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to assign shift', error: error.message });
  }
};

// List Shifts (Available to all authenticated users of the same company)
const listShifts = async (req, res) => {
  try {
    const targetCompanyId = req.user.companyId;
    if (!targetCompanyId) {
      return res.status(400).json({ message: 'Company ID is required.' });
    }

    const shifts = await Shift.findAll({
      where: { companyId: targetCompanyId, isActive: true },
      order: [['name', 'ASC']]
    });

    return res.json({ shifts });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch shifts', error: error.message });
  }
};

// Reset User Session (forces user to log out on next API call / allows login on new device)
const resetSession = async (req, res) => {
  try {
    const { id } = req.params;
    const user = await User.findByPk(id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const creatorRole = req.user.role;
    let allowed = false;

    if (creatorRole === 'system_admin') {
      if (user.companyId === req.user.companyId || user.role === 'company_admin') {
        allowed = true;
      }
    } else if (creatorRole === 'company_admin') {
      if (user.companyId === req.user.companyId) {
        allowed = true;
      }
    } else if (creatorRole === 'manager' || creatorRole === 'team_leader') {
      const managedTeams = await Team.findAll({
        where: {
          [Op.or]: [
            { managerId: req.user.id },
            { teamLeaderId: req.user.id }
          ]
        },
        attributes: ['id']
      });
      const managedTeamIds = managedTeams.map(t => t.id);
      const isTeamMember = user.teamId && managedTeamIds.includes(user.teamId);
      if (user.companyId === req.user.companyId && isTeamMember) {
        allowed = true;
      }
    }

    if (!allowed) {
      return res.status(403).json({ message: 'Unauthorized to reset this user\'s session' });
    }

    user.currentDeviceId = null;
    await user.save();

    return res.json({ message: 'User session reset successfully' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to reset session', error: error.message });
  }
};

module.exports = {
  listUsers,
  createUser,
  updateUser,
  deleteUser,
  attendanceStats,
  exportReport,
  listCompanies,
  createCompany,
  approveCompany,
  rejectCompany,
  listTeams,
  createTeam,
  updateTeam,
  deleteTeam,
  getCompanySettings,
  updateCompanySettings,
  addTeamMember,
  downloadUserTemplate,
  bulkUploadUsers,
  createShift,
  updateShift,
  deleteShift,
  assignShift,
  listShifts,
  resetSession,
};
