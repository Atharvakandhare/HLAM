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
} = require('../controllers/adminController');
const { authMiddleware, systemAdminOnly, companyAdminOnly, approverOnly } = require('../middleware/auth');

const multer = require('multer');
const path = require('path');
const fs = require('fs');

const tempUploadsDir = path.join(__dirname, '../uploads/temp');
if (!fs.existsSync(tempUploadsDir)) {
    fs.mkdirSync(tempUploadsDir, { recursive: true });
}
const tempStorage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, tempUploadsDir),
    filename: (req, file, cb) => cb(null, `bulk_users_${Date.now()}${path.extname(file.originalname)}`),
});
const uploadExcel = multer({
    storage: tempStorage,
    limits: { fileSize: 10 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        const allowed = ['.xlsx', '.xls', '.csv'];
        const ext = path.extname(file.originalname).toLowerCase();
        if (allowed.includes(ext)) return cb(null, true);
        cb(new Error('Only Excel (.xlsx, .xls) and CSV files are allowed.'));
    }
});

const router = express.Router();

// Apply auth to all admin routes
router.use(authMiddleware);

// Companies (System Admin only)
router.get('/companies', systemAdminOnly, listCompanies);
router.post('/companies', systemAdminOnly, createCompany);
router.post('/companies/:id/approve', systemAdminOnly, approveCompany);
router.post('/companies/:id/reject', systemAdminOnly, rejectCompany);

// Company Settings (System Admin or Company Admin)
router.get('/company-settings', companyAdminOnly, getCompanySettings);
router.post('/company-settings', companyAdminOnly, updateCompanySettings);
router.put('/company-settings', companyAdminOnly, updateCompanySettings);
router.post('/company-settings/leave-policy', companyAdminOnly, updateCompanySettings);

// Shift Management (Company Admin only - POST only as requested)
router.post('/shifts/create', companyAdminOnly, createShift);
router.post('/shifts/update', companyAdminOnly, updateShift);
router.post('/shifts/delete', companyAdminOnly, deleteShift);
router.post('/shifts/assign', companyAdminOnly, assignShift);

// Teams
router.get('/teams', listTeams); // Available to all authenticated users to list teams of their company
router.post('/teams', companyAdminOnly, createTeam); // Only admins can create teams
router.post('/teams/:id', companyAdminOnly, updateTeam); // Only admins can update teams
router.post('/teams/:id/delete', companyAdminOnly, deleteTeam); // Only admins can delete teams
router.post('/teams/add-member', addTeamMember); // Assign/add existing user to a team

// Users management
router.get('/users/template', downloadUserTemplate);
router.post('/users/bulk-upload', companyAdminOnly, uploadExcel.single('file'), bulkUploadUsers);
router.get('/users', listUsers); // Available to all authenticated users to fetch colleague list (e.g. for birthdays)
router.post('/users', approverOnly, createUser);
router.post('/users/:id', approverOnly, updateUser);
router.post('/users/:id/delete', approverOnly, deleteUser);

// Attendance stats and reports (System Admin, Company Admin, Manager, Team Leader)
router.get('/attendance/stats', approverOnly, attendanceStats);
router.get('/reports/export', approverOnly, exportReport);

module.exports = router;
