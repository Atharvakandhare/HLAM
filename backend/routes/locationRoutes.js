const express = require('express');
const {
  logLocation,
  getMarketingTrail,
  getActiveMarketingEmployees,
  getAllMarketingEmployees
} = require('../controllers/locationController');
const { authMiddleware, adminOnly } = require('../middleware/auth');

const router = express.Router();

// Apply authentication to all location endpoints
router.use(authMiddleware);

// Employee route
router.post('/log', logLocation);

// Admin routes
router.get('/trail/:userId', adminOnly, getMarketingTrail);
router.get('/active', adminOnly, getActiveMarketingEmployees);
router.get('/all-marketing', adminOnly, getAllMarketingEmployees);

module.exports = router;
