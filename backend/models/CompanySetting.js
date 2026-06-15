const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/dbconnect');

const CompanySetting = sequelize.define(
  'CompanySetting',
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    companyId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
      unique: 'company_id',
      field: 'company_id',
    },
    checkInTime: {
      type: DataTypes.TIME,
      allowNull: false,
      defaultValue: '09:00:00',
      field: 'check_in_time',
    },
    checkOutTime: {
      type: DataTypes.TIME,
      allowNull: false,
      defaultValue: '18:00:00',
      field: 'check_out_time',
    },
    latitude: {
      type: DataTypes.DECIMAL(10, 7),
      allowNull: false,
      defaultValue: 0.0,
    },
    longitude: {
      type: DataTypes.DECIMAL(10, 7),
      allowNull: false,
      defaultValue: 0.0,
    },
    address: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    radius: {
      type: DataTypes.FLOAT,
      allowNull: false,
      defaultValue: 100.0,
    },
    monthlyPaidLeaves: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      field: 'monthly_paid_leaves',
    },
    yearlyPaidLeaves: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      field: 'yearly_paid_leaves',
    },
    leavesRefreshMonth: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 1,
      field: 'leaves_refresh_month',
    },
    leavesRefreshDay: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 1,
      field: 'leaves_refresh_day',
    },
  },
  {
    tableName: 'company_settings',
    timestamps: true,
    underscored: true,
  }
);

module.exports = CompanySetting;
