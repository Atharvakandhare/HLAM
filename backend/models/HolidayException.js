const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/dbconnect');

// HolidayException allows a specific team or user to work on an otherwise blocked holiday
const HolidayException = sequelize.define(
  'HolidayException',
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    holidayId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
      field: 'holiday_id',
    },
    companyId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
      field: 'company_id',
    },
    // If teamId is set, the entire team is exempt
    teamId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: true,
      field: 'team_id',
    },
    // If userId is set, that individual user is exempt
    userId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: true,
      field: 'user_id',
    },
    note: {
      type: DataTypes.STRING,
      allowNull: true,
    },
  },
  {
    tableName: 'holiday_exceptions',
    timestamps: true,
    underscored: true,
  }
);

module.exports = HolidayException;
