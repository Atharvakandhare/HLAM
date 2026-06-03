const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/dbconnect');

const Holiday = sequelize.define(
  'Holiday',
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
    date: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    name: {
      type: DataTypes.STRING,
      allowNull: false,
      defaultValue: 'Company Holiday',
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
      field: 'is_active',
    },
  },
  {
    tableName: 'holidays',
    timestamps: true,
    underscored: true,
    indexes: [
      {
        unique: true,
        fields: ['company_id', 'date'],
      },
    ],
  }
);

module.exports = Holiday;
