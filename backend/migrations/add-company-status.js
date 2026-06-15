const { sequelize } = require('../config/dbconnect');
const { DataTypes } = require('sequelize');

const migrate = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Connected to database. Running migration to add status and rejection_reason to companies...');
    const queryInterface = sequelize.getQueryInterface();

    // 1. Add status column to companies
    try {
      await queryInterface.addColumn('companies', 'status', {
        type: DataTypes.ENUM('pending', 'approved', 'rejected'),
        defaultValue: 'pending',
        allowNull: false
      });
      console.log('✅ Added column "status" to table "companies".');
    } catch (err) {
      if (
        err.message.includes('Duplicate column') ||
        err.message.includes('already exists') ||
        err.code === 'ER_DUP_FIELDNAME'
      ) {
        console.log('ℹ️ Column "status" already exists in "companies". Skipping.');
      } else {
        console.error('❌ Error adding column "status":', err.message);
      }
    }

    // 2. Add rejection_reason column to companies
    try {
      await queryInterface.addColumn('companies', 'rejection_reason', {
        type: DataTypes.TEXT,
        allowNull: true,
        defaultValue: null
      });
      console.log('✅ Added column "rejection_reason" to table "companies".');
    } catch (err) {
      if (
        err.message.includes('Duplicate column') ||
        err.message.includes('already exists') ||
        err.code === 'ER_DUP_FIELDNAME'
      ) {
        console.log('ℹ️ Column "rejection_reason" already exists in "companies". Skipping.');
      } else {
        console.error('❌ Error adding column "rejection_reason":', err.message);
      }
    }

    // 3. Mark the default Hirelyft company as approved
    try {
      await sequelize.query("UPDATE companies SET status = 'approved' WHERE name = 'Hirelyft India Pvt. Ltd.';");
      console.log('✅ Checked and updated Hirelyft India Pvt. Ltd. company status to approved.');
    } catch (err) {
      console.error('❌ Error updating default company status:', err.message);
    }

    console.log('🎉 Migration successfully completed.');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
};

migrate();
