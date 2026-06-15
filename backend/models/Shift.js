const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/dbconnect');

const Shift = sequelize.define(
  'Shift',
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    companyId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
      field: 'company_id',
    },
    name: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    checkInTime: {
      type: DataTypes.TIME,
      allowNull: false,
      field: 'check_in_time',
    },
    checkOutTime: {
      type: DataTypes.TIME,
      allowNull: false,
      field: 'check_out_time',
    },
    lateInLimit: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 15,
      field: 'late_in_limit',
    },
    lateOutLimit: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 15,
      field: 'late_out_limit',
    },
    earlyInLimit: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 15,
      field: 'early_in_limit',
    },
    earlyOutLimit: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 15,
      field: 'early_out_limit',
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
      field: 'is_active',
    },
  },
  {
    tableName: 'shifts',
    timestamps: true,
    underscored: true,
  }
);

module.exports = Shift;
