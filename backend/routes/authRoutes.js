const express = require('express');
const {
  register,
  login,
  me,
  logout,
  refreshToken,
  changePassword,
  updateProfilePicture,
  deleteProfilePicture
} = require('../controllers/authController');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

router.post('/register', register);
router.post('/login', login);
router.post('/logout', authMiddleware, logout);
router.post('/refresh-token', refreshToken);
router.get('/me', authMiddleware, me);
router.post('/change-password', authMiddleware, changePassword);
router.post('/profile-picture', authMiddleware, updateProfilePicture);
router.post('/profile-picture/delete', authMiddleware, deleteProfilePicture);

module.exports = router;

