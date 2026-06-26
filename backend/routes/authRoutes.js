const express = require('express');
const {
  register,
  registerCompany,
  login,
  me,
  logout,
  refreshToken,
  changePassword,
  updateProfilePicture,
  deleteProfilePicture,
  forgotPassword,
  verifyOtp,
  resetPassword,
  updateFcmToken,
  updateProfile
} = require('../controllers/authController');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

router.post('/register', register);
router.post('/register-company', registerCompany);
router.post('/login', login);
router.post('/logout', authMiddleware, logout);
router.post('/refresh-token', refreshToken);
router.get('/me', authMiddleware, me);
router.post('/change-password', authMiddleware, changePassword);
router.post('/profile-picture', authMiddleware, updateProfilePicture);
router.post('/profile-picture/delete', authMiddleware, deleteProfilePicture);
router.post('/fcm-token', authMiddleware, updateFcmToken);
router.put('/profile', authMiddleware, updateProfile);

router.post('/forgot-password', forgotPassword);
router.post('/verify-otp', verifyOtp);
router.post('/reset-password', resetPassword);

module.exports = router;

