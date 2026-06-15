const { sequelize } = require('../config/dbconnect');

const migrate = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Connected to database. Running migration to add fcm_token...');
    const queryInterface = sequelize.getQueryInterface();
    const { DataTypes } = require('sequelize');

    // Safe column addition helper
    try {
      await queryInterface.addColumn('users', 'fcm_token', {
        type: DataTypes.STRING,
        allowNull: true,
        defaultValue: null,
      });
      console.log('✅ Added column "fcm_token" to table "users".');
    } catch (err) {
      if (
        err.message.includes('Duplicate column') ||
        err.message.includes('already exists') ||
        err.code === 'ER_DUP_FIELDNAME'
      ) {
        console.log('ℹ️ Column "fcm_token" already exists. Skipping.');
      } else {
        console.error('❌ Error adding column "fcm_token":', err.message);
      }
    }

    console.log('🎉 Migration successfully completed.');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
};

migrate();
