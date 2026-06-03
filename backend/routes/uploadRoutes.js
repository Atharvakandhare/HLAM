const express = require('express');
const { handleSelfie, upload, handleProfilePicture, uploadProfile } = require('../controllers/uploadController');
const { authMiddleware } = require('../middleware/auth');

const multer = require('multer');

const router = express.Router();

// Upload selfie (file or URL) — uses Jimp → JPEG
router.post('/selfie', authMiddleware, (req, res, next) => {
    upload.single('selfie')(req, res, (err) => {
        if (err instanceof multer.MulterError) {
            return res.status(400).json({ message: `Multer Error: ${err.message}` });
        } else if (err) {
            return res.status(400).json({ message: err.message });
        }
        next();
    });
}, handleSelfie);

// Upload profile picture — uses Jimp → JPEG (max 3MB, 800px width, quality 60)
router.post('/profile-picture', authMiddleware, (req, res, next) => {
    uploadProfile.single('profilePicture')(req, res, (err) => {
        if (err instanceof multer.MulterError) {
            if (err.code === 'LIMIT_FILE_SIZE') {
                return res.status(400).json({ message: 'Profile picture must be under 3 MB. Please choose a smaller image.' });
            }
            return res.status(400).json({ message: `Upload Error: ${err.message}` });
        } else if (err) {
            return res.status(400).json({ message: err.message });
        }
        next();
    });
}, handleProfilePicture);

// Legacy endpoint for URL-only
router.post('/selfie-url', authMiddleware, handleSelfie);

module.exports = router;


