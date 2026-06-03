const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/dbconnect');

const Company = sequelize.define(
  'Company',
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    name: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
      field: 'is_active',
    },
  },
  {
    tableName: 'companies',
    timestamps: true,
    underscored: true,
  }
);

module.exports = Company;
