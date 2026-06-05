const { sequelize } = require('../config/dbconnect');

const migrate = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Connected to database. Running migrations...');
    const queryInterface = sequelize.getQueryInterface();
    const { DataTypes } = require('sequelize');

    // Helper to safely add column
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

    // 1. Add fields to company_settings
    await addColumnSafe('company_settings', 'monthly_paid_leaves', { type: DataTypes.INTEGER, defaultValue: 0, field: 'monthly_paid_leaves' });
    await addColumnSafe('company_settings', 'yearly_paid_leaves', { type: DataTypes.INTEGER, defaultValue: 0, field: 'yearly_paid_leaves' });
    await addColumnSafe('company_settings', 'leaves_refresh_month', { type: DataTypes.INTEGER, defaultValue: 1, field: 'leaves_refresh_month' });
    await addColumnSafe('company_settings', 'leaves_refresh_day', { type: DataTypes.INTEGER, defaultValue: 1, field: 'leaves_refresh_day' });

    // 2. Add fields to leaves
    await addColumnSafe('leaves', 'is_paid_request', { type: DataTypes.BOOLEAN, defaultValue: false, field: 'is_paid_request' });
    await addColumnSafe('leaves', 'allow_next_month_quota', { type: DataTypes.BOOLEAN, defaultValue: false, field: 'allow_next_month_quota' });
    await addColumnSafe('leaves', 'paid_days', { type: DataTypes.INTEGER, defaultValue: 0, field: 'paid_days' });
    await addColumnSafe('leaves', 'next_month_paid_days', { type: DataTypes.INTEGER, defaultValue: 0, field: 'next_month_paid_days' });
    await addColumnSafe('leaves', 'unpaid_days', { type: DataTypes.INTEGER, defaultValue: 0, field: 'unpaid_days' });

    console.log('🎉 Migrations successfully completed.');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
};

migrate();
