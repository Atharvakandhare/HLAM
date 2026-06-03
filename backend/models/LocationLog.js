const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/dbconnect');

const LocationLog = sequelize.define(
  'LocationLog',
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
    latitude: {
      type: DataTypes.DECIMAL(10, 7),
      allowNull: false,
    },
    longitude: {
      type: DataTypes.DECIMAL(10, 7),
      allowNull: false,
    },
    address: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    recordedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
      field: 'recorded_at',
    },
  },
  {
    tableName: 'location_logs',
    timestamps: false,
    underscored: true,
  }
);

module.exports = LocationLog;
