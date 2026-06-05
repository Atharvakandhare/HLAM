const express = require('express');
const {
  applyLeave,
  getMyLeaves,
  getAllLeaves,
  updateLeaveStatus,
  updateLeave,
} = require('../controllers/leaveController');
const { authMiddleware, approverOnly } = require('../middleware/auth');

const router = express.Router();

// Apply authentication to all leave endpoints
router.use(authMiddleware);

// Employee routes
router.post('/apply', applyLeave);
router.get('/my', getMyLeaves);
router.post('/update/:id', updateLeave);

// Approver routes
router.get('/admin', approverOnly, getAllLeaves);
router.post('/admin/:id', approverOnly, updateLeaveStatus);

module.exports = router;
