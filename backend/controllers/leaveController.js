const { Leave, User, Company, Team } = require('../associations');
const { Op } = require('sequelize');
const { sendLeaveStatusEmail } = require('../services/mailService');

const getDaysDiff = (startStr, endStr) => {
  const start = new Date(startStr);
  const end = new Date(endStr);
  const utc1 = Date.UTC(start.getFullYear(), start.getMonth(), start.getDate());
  const utc2 = Date.UTC(end.getFullYear(), end.getMonth(), end.getDate());
  return Math.floor((utc2 - utc1) / (1000 * 60 * 60 * 24)) + 1;
};

const { calculateUserLeavesQuota } = require('../services/leaveQuotaService');

// Apply for a leave
const applyLeave = async (req, res) => {
  try {
    const { startDate, endDate, reason, isPaidRequest, allowNextMonthQuota } = req.body;
    const userId = req.user.id;

    if (!startDate || !endDate || !reason) {
      return res.status(400).json({ message: 'Start date, end date, and reason are required' });
    }

    const leave = await Leave.create({
      userId,
      startDate,
      endDate,
      reason,
      status: 'pending',
      isPaidRequest: isPaidRequest === true || isPaidRequest === 'true',
      allowNextMonthQuota: allowNextMonthQuota === true || allowNextMonthQuota === 'true',
    });

    return res.status(201).json({ message: 'Leave application submitted successfully', leave });
  } catch (error) {
    console.error('[Leave] Apply error:', error);
    return res.status(500).json({ message: 'Failed to submit leave application', error: error.message });
  }
};

// Get current user's leaves
const getMyLeaves = async (req, res) => {
  try {
    const userId = req.user.id;
    const leaves = await Leave.findAll({
      where: { userId },
      order: [['createdAt', 'DESC']],
    });
    return res.json({ leaves });
  } catch (error) {
    console.error('[Leave] Fetch my leaves error:', error);
    return res.status(500).json({ message: 'Failed to fetch your leaves', error: error.message });
  }
};

// Admin / Approver: Get all leaves according to role hierarchy
const getAllLeaves = async (req, res) => {
  try {
    const userRole = req.user.role;
    const companyId = req.user.companyId;
    const teamId = req.user.teamId;
    const { userId } = req.query;

    let userWhere = {};
    if (userRole === 'system_admin') {
      // system_admin only sees leave applications from their own company
      userWhere = { companyId };
    } else if (userRole === 'company_admin') {
      // company_admin sees leaves in their company
      userWhere = { companyId };
    } else if (userRole === 'manager' || userRole === 'team_leader') {
      // Find teams this user manages or leads (via teams.managerId / teams.teamLeaderId)
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

      userWhere.companyId = companyId;
      userWhere.teamId = { [Op.in]: managedTeamIds };
      if (userRole === 'manager') {
        userWhere.role = ['employee', 'team_leader'];
      } else {
        userWhere.role = 'employee';
      }
    } else {
      return res.status(403).json({ message: 'Unauthorized to view leave applications' });
    }

    if (userId) {
      userWhere.id = userId;
    }

    const leaves = await Leave.findAll({
      include: [{
        model: User,
        as: 'user',
        where: userWhere,
        attributes: ['id', 'name', 'email', 'employeeId', 'department', 'role', 'companyId', 'teamId'],
        include: [
          { model: Company, as: 'company', attributes: ['id', 'name'] },
          { model: Team, as: 'team', attributes: ['id', 'name'] }
        ]
      }],
      order: [['createdAt', 'DESC']],
    });
    return res.json({ leaves });
  } catch (error) {
    console.error('[Leave] Fetch all leaves error:', error);
    return res.status(500).json({ message: 'Failed to fetch leave applications', error: error.message });
  }
};

// Admin / Approver: Accept/Reject leave according to role hierarchy
const updateLeaveStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, adminComment } = req.body;

    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ message: 'Invalid status. Must be approved or rejected' });
    }

    const leave = await Leave.findByPk(id, {
      include: [{ model: User, as: 'user' }]
    });
    if (!leave) {
      return res.status(404).json({ message: 'Leave application not found' });
    }

    const applicant = leave.user;
    const approver = req.user;

    // Check permissions according to hierarchy
    let hasPermission = false;
    if (approver.role === 'system_admin') {
      // system_admin can only approve/reject leaves within their own company
      if (applicant.companyId === approver.companyId) {
        hasPermission = true;
      }
    } else if (approver.role === 'company_admin') {
      if (applicant.companyId === approver.companyId) {
        hasPermission = true;
      }
    } else if (approver.role === 'manager' || approver.role === 'team_leader') {
      const managedTeams = await Team.findAll({
        where: {
          [Op.or]: [
            { managerId: approver.id },
            { teamLeaderId: approver.id }
          ]
        },
        attributes: ['id']
      });
      const managedTeamIds = managedTeams.map(t => t.id);

      const isTeamMember = applicant.teamId && managedTeamIds.includes(applicant.teamId);

      if (applicant.companyId === approver.companyId && isTeamMember) {
        if (approver.role === 'manager' && ['employee', 'team_leader'].includes(applicant.role)) {
          hasPermission = true;
        } else if (approver.role === 'team_leader' && applicant.role === 'employee') {
          hasPermission = true;
        }
      }
    }

    if (!hasPermission) {
      return res.status(403).json({ message: 'You do not have permission to approve/reject this leave application' });
    }

    leave.status = status;
    if (adminComment !== undefined) {
      leave.adminComment = adminComment;
    }

    if (status === 'approved') {
      const daysDiff = getDaysDiff(leave.startDate, leave.endDate);

      if (leave.isPaidRequest) {
        // Calculate quota for applicant as of leave's startDate
        const quota = await calculateUserLeavesQuota(leave.userId, leave.startDate);

        // availableThisMonth represents the remaining paid leaves balance of the start month
        // before this leave (since this leave is currently pending, it was NOT counted in calculateUserLeavesQuota)
        const available = quota.availableThisMonth;
        const availableNextMonth = quota.availableNextMonth;

        if (daysDiff <= available) {
          leave.paidDays = daysDiff;
          leave.nextMonthPaidDays = 0;
          leave.unpaidDays = 0;
        } else {
          leave.paidDays = available;
          const remaining = daysDiff - available;

          if (leave.allowNextMonthQuota) {
            const nextMonthPaid = Math.min(remaining, availableNextMonth);
            leave.nextMonthPaidDays = nextMonthPaid;
            leave.unpaidDays = remaining - nextMonthPaid;
          } else {
            leave.nextMonthPaidDays = 0;
            leave.unpaidDays = remaining;
          }
        }
      } else {
        leave.paidDays = 0;
        leave.nextMonthPaidDays = 0;
        leave.unpaidDays = daysDiff;
      }
    }

    await leave.save();

    // Send leave status update email in the background
    sendLeaveStatusEmail({
      applicantName: applicant.name,
      applicantEmail: applicant.email,
      status: status,
      startDate: leave.startDate,
      endDate: leave.endDate,
      reason: leave.reason,
      approverName: approver.name,
      adminComment: adminComment || '',
    }).catch((err) => {
      console.error('[Leave] Status email notification error:', err.message);
    });

    return res.json({ message: `Leave application successfully ${status}`, leave });
  } catch (error) {
    console.error('[Leave] Update status error:', error);
    return res.status(500).json({ message: 'Failed to update leave status', error: error.message });
  }
};

// Employee: Update a pending leave request
const updateLeave = async (req, res) => {
  try {
    const { id } = req.params;
    const { startDate, endDate, reason, isPaidRequest, allowNextMonthQuota } = req.body;
    const userId = req.user.id;

    if (!startDate || !endDate || !reason) {
      return res.status(400).json({ message: 'Start date, end date, and reason are required' });
    }

    const leave = await Leave.findByPk(id);
    if (!leave) {
      return res.status(404).json({ message: 'Leave application not found' });
    }

    // Ensure the leave belongs to the current user
    if (leave.userId !== userId) {
      return res.status(403).json({ message: 'Unauthorized to update this leave application' });
    }

    // Ensure the leave is still pending
    if (leave.status.toLowerCase() !== 'pending') {
      return res.status(400).json({ message: 'You can only update pending leave applications' });
    }

    leave.startDate = startDate;
    leave.endDate = endDate;
    leave.reason = reason;
    if (isPaidRequest !== undefined) leave.isPaidRequest = isPaidRequest === true || isPaidRequest === 'true';
    if (allowNextMonthQuota !== undefined) leave.allowNextMonthQuota = allowNextMonthQuota === true || allowNextMonthQuota === 'true';

    await leave.save();
    return res.json({ message: 'Leave application updated successfully', leave });
  } catch (error) {
    console.error('[Leave] Update error:', error);
    return res.status(500).json({ message: 'Failed to update leave application', error: error.message });
  }
};

// Fetch leave quota
const getLeaveQuota = async (req, res) => {
  try {
    const loggedInUser = req.user;
    let targetUserId = req.body.userId || loggedInUser.id;

    if (targetUserId !== loggedInUser.id) {
      // Check permissions
      const targetUser = await User.findByPk(targetUserId);
      if (!targetUser) {
        return res.status(404).json({ message: 'User not found' });
      }

      if (targetUser.companyId !== loggedInUser.companyId) {
        return res.status(403).json({ message: 'Forbidden. User belongs to another company.' });
      }

      if (['manager', 'team_leader'].includes(loggedInUser.role)) {
        const managedTeams = await Team.findAll({
          where: {
            [Op.or]: [
              { managerId: loggedInUser.id },
              { teamLeaderId: loggedInUser.id }
            ]
          },
          attributes: ['id']
        });
        const managedTeamIds = managedTeams.map(t => t.id);
        const isTeamMember = targetUser.teamId && managedTeamIds.includes(targetUser.teamId);

        if (!isTeamMember) {
          return res.status(403).json({ message: 'Forbidden. You do not manage this user\'s team.' });
        }
      } else if (loggedInUser.role === 'employee') {
        return res.status(403).json({ message: 'Forbidden. Employees cannot view other users\' quotas.' });
      }
    }

    const todayStr = new Date().toISOString().split('T')[0];
    const quota = await calculateUserLeavesQuota(targetUserId, todayStr);
    return res.json({ quota });
  } catch (error) {
    console.error('[Leave] Fetch quota error:', error);
    return res.status(500).json({ message: 'Failed to fetch leave quota', error: error.message });
  }
};

module.exports = { applyLeave, getMyLeaves, getAllLeaves, updateLeaveStatus, updateLeave, getLeaveQuota };
