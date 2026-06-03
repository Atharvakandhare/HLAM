const express = require('express');
const {
  listUsers,
  createUser,
  updateUser,
  deleteUser,
  attendanceStats,
  exportReport,
  listCompanies,
  createCompany,
  listTeams,
  createTeam,
  updateTeam,
  deleteTeam,
  getCompanySettings,
  updateCompanySettings,
  addTeamMember,
} = require('../controllers/adminController');
const { authMiddleware, systemAdminOnly, companyAdminOnly, approverOnly } = require('../middleware/auth');

const router = express.Router();

// Apply auth to all admin routes
router.use(authMiddleware);

// Companies (System Admin only)
router.get('/companies', systemAdminOnly, listCompanies);
router.post('/companies', systemAdminOnly, createCompany);

// Company Settings (System Admin or Company Admin)
router.get('/company-settings', companyAdminOnly, getCompanySettings);
router.put('/company-settings', companyAdminOnly, updateCompanySettings);

// Teams
router.get('/teams', listTeams); // Available to all authenticated users to list teams of their company
router.post('/teams', companyAdminOnly, createTeam); // Only admins can create teams
router.put('/teams/:id', companyAdminOnly, updateTeam); // Only admins can update teams
router.delete('/teams/:id', companyAdminOnly, deleteTeam); // Only admins can delete teams
router.post('/teams/add-member', addTeamMember); // Assign/add existing user to a team

// Users management
router.get('/users', listUsers); // Available to all authenticated users to fetch colleague list (e.g. for birthdays)
router.post('/users', approverOnly, createUser);
router.put('/users/:id', approverOnly, updateUser);
router.delete('/users/:id', approverOnly, deleteUser);

// Attendance stats and reports (System Admin, Company Admin, Manager, Team Leader)
router.get('/attendance/stats', approverOnly, attendanceStats);
router.get('/reports/export', approverOnly, exportReport);

module.exports = router;
