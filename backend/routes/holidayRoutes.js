const express = require('express');
const {
  listHolidays,
  createHoliday,
  updateHoliday,
  deleteHoliday,
  parseHolidaySheet,
  bulkCreateHolidays,
  listExceptions,
  addException,
  removeException,
} = require('../controllers/holidayController');
const { authMiddleware, companyAdminOnly } = require('../middleware/auth');

const router = express.Router();

// All authenticated users can view holidays (employees need to see them on calendar)
router.get('/', authMiddleware, listHolidays);

// Only company admins can manage holidays
router.post('/parse-sheet', authMiddleware, companyAdminOnly, ...parseHolidaySheet);
router.post('/bulk', authMiddleware, companyAdminOnly, bulkCreateHolidays);
router.post('/', authMiddleware, companyAdminOnly, createHoliday);
router.put('/:id', authMiddleware, companyAdminOnly, updateHoliday);
router.delete('/:id', authMiddleware, companyAdminOnly, deleteHoliday);

// Exceptions
router.get('/:id/exceptions', authMiddleware, companyAdminOnly, listExceptions);
router.post('/:id/exceptions', authMiddleware, companyAdminOnly, addException);
router.delete('/:id/exceptions/:eid', authMiddleware, companyAdminOnly, removeException);

module.exports = router;
