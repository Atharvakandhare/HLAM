const express = require('express');
const {
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
} = require('../controllers/attendanceController');
const { authMiddleware, adminOnly } = require('../middleware/auth');

const router = express.Router();

// Employee / Manager / Team Leader
router.post('/check-in', authMiddleware, checkIn);
router.post('/check-out', authMiddleware, checkOut);
router.post('/overtime', authMiddleware, updateOvertimePermission);
router.get('/my', authMiddleware, myAttendance);
router.get('/my-attendance', authMiddleware, myAttendance); // alias
router.get('/today', authMiddleware, todayAttendance);
router.get('/stats', authMiddleware, getUserStats);

// Admin / Manager / Team Leader
router.get('/by-teams', authMiddleware, adminOnly, getAttendanceByTeams);
router.get('/', authMiddleware, adminOnly, listAll);
router.get('/:id', authMiddleware, adminOnly, getById);
router.post('/:id/delete', authMiddleware, adminOnly, deleteAttendance);

module.exports = router;
