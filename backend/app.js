const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/authRoutes');
const attendanceRoutes = require('./routes/attendanceRoutes');
const adminRoutes = require('./routes/adminRoutes');
const uploadRoutes = require('./routes/uploadRoutes');
const leaveRoutes = require('./routes/leaveRoutes');
const locationRoutes = require('./routes/locationRoutes');
const holidayRoutes = require('./routes/holidayRoutes');
const shiftRoutes = require('./routes/shiftRoutes');

const app = express();
const fs = require('fs');
const path = require('path');

// Ensure uploads directories exist
const uploadDir = path.join(__dirname, 'uploads', 'selfies');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}
const profilesUploadDir = path.join(__dirname, 'uploads', 'profiles');
if (!fs.existsSync(profilesUploadDir)) {
    fs.mkdirSync(profilesUploadDir, { recursive: true });
}
const holidaysUploadDir = path.join(__dirname, 'uploads', 'holidays');
if (!fs.existsSync(holidaysUploadDir)) {
    fs.mkdirSync(holidaysUploadDir, { recursive: true });
}
const facesUploadDir = path.join(__dirname, 'uploads', 'faces');
if (!fs.existsSync(facesUploadDir)) {
    fs.mkdirSync(facesUploadDir, { recursive: true });
}

// Simple Request Logger
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
    next();
});

// Middleware
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve uploaded files
app.use('/uploads', express.static('uploads'));

// Basic Route
app.get('/', (req, res) => {
    res.send('Smart Attendance System Backend is Running!');
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/leaves', leaveRoutes);
app.use('/api/location', locationRoutes);
app.use('/api/holidays', holidayRoutes);
app.use('/api/shifts', shiftRoutes);


module.exports = app;
