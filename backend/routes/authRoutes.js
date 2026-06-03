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
router.put('/profile-picture', authMiddleware, updateProfilePicture);
router.delete('/profile-picture', authMiddleware, deleteProfilePicture);

module.exports = router;

