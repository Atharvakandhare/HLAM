const multer = require('multer');
const path = require('path');
const fs = require('fs');
const Jimp = require('jimp').Jimp;

// Ensure uploads directories exist
const uploadsDir = path.join(__dirname, '../uploads/selfies');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}
const profilesDir = path.join(__dirname, '../uploads/profiles');
if (!fs.existsSync(profilesDir)) {
  fs.mkdirSync(profilesDir, { recursive: true });
}

// Configure multer for image uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, `temp-${req.user.id}-${uniqueSuffix}${ext}`);
  }
});

const fileFilter = (req, file, cb) => {
  const allowedTypes = /jpeg|jpg|png|gif|webp/;
  const extension = path.extname(file.originalname).toLowerCase().substring(1);
  const mimetype = file.mimetype.split('/')[1];

  const isExtAllowed = allowedTypes.test(extension);
  const isMimeAllowed = allowedTypes.test(mimetype);

  if (isMimeAllowed || isExtAllowed) {
    return cb(null, true);
  } else {
    cb(new Error(`Only image files are allowed. Received: ${file.mimetype}`));
  }
};

const upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit (raw)
  fileFilter: fileFilter
});

// Handle both file upload and URL submission
const handleSelfie = async (req, res) => {
  try {
    if (req.file) {
      const fileName = `selfie-${req.user.id}-${Date.now()}.jpg`;
      const outputPath = path.join(uploadsDir, fileName);

      // Read with Jimp v1
      const image = await Jimp.read(req.file.path);

      // Only resize if wider than 600px (withoutEnlargement behaviour)
      if (image.bitmap.width > 600) {
        image.resize({ w: 600 });
      }

      // Encode as JPEG at quality 60, then write to disk
      const jpegBuffer = await image.getBuffer('image/jpeg', { quality: 60 });
      fs.writeFileSync(outputPath, jpegBuffer);

      // Delete the temp file
      fs.unlinkSync(req.file.path);

      const fileUrl = `/uploads/selfies/${fileName}`;
      return res.json({
        message: 'Selfie uploaded and optimized successfully',
        url: fileUrl,
        filename: fileName
      });
    }

    const { selfieUrl } = req.body;
    if (!selfieUrl) {
      return res.status(400).json({ message: 'Selfie image or URL is required' });
    }

    return res.json({
      message: 'Selfie URL received',
      url: selfieUrl
    });
  } catch (error) {
    console.error('[Upload] Error processing selfie:', error);
    if (req.file && fs.existsSync(req.file.path)) {
      try { fs.unlinkSync(req.file.path); } catch (e) {}
    }
    return res.status(500).json({ message: 'Failed to process selfie', error: error.message });
  }
};

// ─── Profile Picture Upload (Jimp) ─────────────────────────────────────────

// Multer storage for profile pictures (temp → profiles dir)
const profileStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, profilesDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, `temp-profile-${req.user.id}-${uniqueSuffix}${ext}`);
  }
});

const uploadProfile = multer({
  storage: profileStorage,
  limits: { fileSize: 3 * 1024 * 1024 }, // 3 MB limit for profile pictures
  fileFilter: fileFilter, // reuse same image filter
});

// Handle profile picture upload using Jimp
const handleProfilePicture = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'Profile picture image is required' });
    }

    const fileName = `profile-${req.user.id}-${Date.now()}.jpg`;
    const outputPath = path.join(profilesDir, fileName);

    // Read with Jimp v1
    const image = await Jimp.read(req.file.path);

    // Only resize if wider than 800px (withoutEnlargement behaviour)
    if (image.bitmap.width > 800) {
      image.resize({ w: 800 });
    }

    // Encode as JPEG at quality 60, then write to disk
    const jpegBuffer = await image.getBuffer('image/jpeg', { quality: 60 });
    fs.writeFileSync(outputPath, jpegBuffer);

    // Delete the temp file
    fs.unlinkSync(req.file.path);

    const fileUrl = `/uploads/profiles/${fileName}`;
    return res.json({
      message: 'Profile picture uploaded and optimized successfully',
      url: fileUrl,
      filename: fileName
    });
  } catch (error) {
    console.error('[Upload] Error processing profile picture:', error);
    if (req.file && fs.existsSync(req.file.path)) {
      try { fs.unlinkSync(req.file.path); } catch (e) {}
    }
    return res.status(500).json({ message: 'Failed to process profile picture', error: error.message });
  }
};

module.exports = { handleSelfie, upload, handleProfilePicture, uploadProfile };



