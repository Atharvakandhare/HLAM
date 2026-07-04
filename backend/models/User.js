const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/dbconnect');

// Basic user model to represent employees and admins
const User = sequelize.define(
  'User',
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    name: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    email: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: 'email',
      validate: {
        isEmail: true,
      },
    },
    password: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    role: {
      type: DataTypes.ENUM('system_admin', 'company_admin', 'manager', 'team_leader', 'employee'),
      defaultValue: 'employee',
    },
    department: {
      type: DataTypes.STRING,
    },
    employeeId: {
      type: DataTypes.STRING,
      unique: 'employee_id',
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
    profilePicture: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'profile_picture',
    },
    isProfilePictureAdminSet: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'is_profile_picture_admin_set',
    },
    companyId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: true,
      field: 'company_id',
    },
    teamId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: true,
      field: 'team_id',
    },
    dob: {
      type: DataTypes.DATEONLY,
      allowNull: true,
    },
    state: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    city: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    workMode: {
      type: DataTypes.ENUM('Work From Office', 'Work From Home', 'Remote Work'),
      defaultValue: 'Work From Office',
      field: 'work_mode',
    },
    workType: {
      type: DataTypes.ENUM('Work From Office', 'Field Work', 'Office + Field Work'),
      allowNull: true,
      field: 'work_type',
    },
    otpCode: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'otp_code',
    },
    otpExpiresAt: {
      type: DataTypes.DATE,
      allowNull: true,
      field: 'otp_expires_at',
    },
    defaultShiftId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: true,
      field: 'default_shift_id',
    },
    fcmToken: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'fcm_token',
    },
    currentDeviceId: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'current_device_id',
    },
    faceDescriptor: {
      type: DataTypes.JSON,
      allowNull: true,
      field: 'face_descriptor',
    },
  },
  {
    tableName: 'users',
    timestamps: true,
    underscored: true,
  }
);

module.exports = User;


