const express = require('express');
const { listShifts } = require('../controllers/adminController');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// Apply auth to all shift routes
router.use(authMiddleware);

// Retrieve active shifts list (POST only as requested)
router.post('/list', listShifts);

module.exports = router;
