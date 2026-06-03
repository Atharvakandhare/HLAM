const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const { Sequelize } = require('sequelize');

const sequelize = new Sequelize(
  process.env.DB_NAME || 'AttendanceManagement',
  process.env.DB_USER || 'root',
  process.env.DB_PASSWORD || 'mysql12',
  {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 3306,
    dialect: 'mysql',
    logging: process.env.NODE_ENV === 'development' ? console.log : false,
    pool: {
      max: 10,       // Increased for deployment
      min: 2,        // Keep at least 2 connections alive
      acquire: 60000, // Wait 60s for connection
      idle: 20000,    // Remove idle connections after 20s
      evict: 1000     // Run eviction check every 1s
    },
    dialectOptions: {
      // Net-retry logic if MySQL drops connection
      connectTimeout: 60000
    }
  }
);

const dbConnection = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ MySQL connection has been established successfully.');
    return true;
  } catch (error) {
    console.error('❌ Unable to connect to the database:', error.message);
    return false;
  }
};

module.exports = { dbConnection, sequelize };