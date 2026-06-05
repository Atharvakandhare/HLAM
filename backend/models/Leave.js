const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/dbconnect');

const Leave = sequelize.define(
  'Leave',
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
    startDate: {
      type: DataTypes.DATEONLY,
      allowNull: false,
      field: 'start_date',
    },
    endDate: {
      type: DataTypes.DATEONLY,
      allowNull: false,
      field: 'end_date',
    },
    reason: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM('pending', 'approved', 'rejected'),
      defaultValue: 'pending',
    },
    adminComment: {
      type: DataTypes.TEXT,
      allowNull: true,
      field: 'admin_comment',
    },
    isPaidRequest: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
      field: 'is_paid_request',
    },
    allowNextMonthQuota: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
      field: 'allow_next_month_quota',
    },
    paidDays: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      field: 'paid_days',
    },
    nextMonthPaidDays: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      field: 'next_month_paid_days',
    },
    unpaidDays: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      field: 'unpaid_days',
    },
  },
  {
    tableName: 'leaves',
    timestamps: true,
    underscored: true,
  }
);

module.exports = Leave;
