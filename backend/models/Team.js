const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/dbconnect');

const Team = sequelize.define(
  'Team',
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
    companyId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
      field: 'company_id',
    },
    managerId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: true,
      field: 'manager_id',
    },
    teamLeaderId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: true,
      field: 'team_leader_id',
    },
  },
  {
    tableName: 'teams',
    timestamps: true,
    underscored: true,
  }
);

module.exports = Team;
