const { sequelize } = require('../config/dbconnect');

const migrate = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Connected to database. Running migrations...');
    const queryInterface = sequelize.getQueryInterface();
    const { DataTypes } = require('sequelize');

    const addColumnSafe = async (table, column, definition) => {
      try {
        await queryInterface.addColumn(table, column, definition);
        console.log(`✅ Added column "${column}" to table "${table}".`);
      } catch (err) {
        if (err.message.includes('Duplicate column') || err.message.includes('already exists') || err.code === 'ER_DUP_FIELDNAME') {
          console.log(`ℹ️ Column "${column}" already exists in table "${table}". Skipping.`);
        } else {
          console.log(`ℹ️ Attempted to add "${column}" to table "${table}". Error message: ${err.message}`);
        }
      }
    };

    // Add OTP columns to users table
    await addColumnSafe('users', 'otp_code', { type: DataTypes.STRING, allowNull: true, field: 'otp_code' });
    await addColumnSafe('users', 'otp_expires_at', { type: DataTypes.DATE, allowNull: true, field: 'otp_expires_at' });

    console.log('🎉 Migrations successfully completed.');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
};

migrate();
