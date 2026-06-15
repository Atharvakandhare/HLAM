const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/dbconnect');

const Attendance = sequelize.define(
  'Attendance',
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
      field: 'user_id',
    },
    date: {
      type: DataTypes.DATEONLY,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
    checkInTime: {
      type: DataTypes.DATE,
    },
    checkOutTime: {
      type: DataTypes.DATE,
    },
    selfieUrl: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    checkoutSelfieUrl: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    taskComments: {
      type: DataTypes.TEXT,
    },
    latitude: {
      type: DataTypes.DECIMAL(10, 7),
    },
    longitude: {
      type: DataTypes.DECIMAL(10, 7),
    },
    address: {
      type: DataTypes.STRING,
    },
    checkoutLatitude: {
      type: DataTypes.DECIMAL(10, 7),
    },
    checkoutLongitude: {
      type: DataTypes.DECIMAL(10, 7),
    },
    checkoutAddress: {
      type: DataTypes.STRING,
    },
    status: {
      type: DataTypes.ENUM('present', 'late', 'absent', 'half_day'),
      defaultValue: 'present',
    },
    loginStatus: {
      type: DataTypes.ENUM('success', 'rejected', 'pending'),
      defaultValue: 'pending',
      field: 'login_status',
    },
    logoutStatus: {
      type: DataTypes.ENUM('success', 'rejected', 'pending'),
      defaultValue: 'pending',
      field: 'logout_status',
    },
    workingHours: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'working_hours',
    },
    mood: {
      type: DataTypes.ENUM('happy', 'sad', 'exhausted', 'angry'),
      allowNull: true,
    },
    energyLevel: {
      type: DataTypes.ENUM('low', 'medium', 'high'),
      allowNull: true,
      field: 'energy_level',
    },
    distanceFromOffice: {
      type: DataTypes.FLOAT,
      allowNull: true,
      field: 'distance_from_office',
      comment: 'Distance in metres from the company office at check-in time',
    },
    shiftId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: true,
      field: 'shift_id',
    },
    isLateIn: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'is_late_in',
    },
    isLateOut: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'is_late_out',
    },
    isEarlyIn: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'is_early_in',
    },
    isEarlyOut: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'is_early_out',
    },
    overtimeAllowed: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'overtime_allowed',
    },
    overtimeDuration: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'overtime_duration',
    },
  },
  {
    tableName: 'attendances',
    timestamps: true,
    underscored: true,
  }
);

module.exports = Attendance;

