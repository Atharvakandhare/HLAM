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

    // Create shifts table if not exists
    try {
      await queryInterface.createTable('shifts', {
        id: {
          type: DataTypes.INTEGER.UNSIGNED,
          autoIncrement: true,
          primaryKey: true,
        },
        company_id: {
          type: DataTypes.INTEGER.UNSIGNED,
          allowNull: false,
        },
        name: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        check_in_time: {
          type: DataTypes.TIME,
          allowNull: false,
        },
        check_out_time: {
          type: DataTypes.TIME,
          allowNull: false,
        },
        late_in_limit: {
          type: DataTypes.INTEGER,
          allowNull: false,
          defaultValue: 15,
        },
        late_out_limit: {
          type: DataTypes.INTEGER,
          allowNull: false,
          defaultValue: 15,
        },
        early_in_limit: {
          type: DataTypes.INTEGER,
          allowNull: false,
          defaultValue: 15,
        },
        early_out_limit: {
          type: DataTypes.INTEGER,
          allowNull: false,
          defaultValue: 15,
        },
        is_active: {
          type: DataTypes.BOOLEAN,
          defaultValue: true,
        },
        created_at: {
          type: DataTypes.DATE,
          allowNull: false,
        },
        updated_at: {
          type: DataTypes.DATE,
          allowNull: false,
        },
      });
      console.log('✅ Created "shifts" table successfully.');
    } catch (err) {
      if (err.message.includes('already exists') || err.code === 'ER_TABLE_EXISTS_ERROR') {
        console.log('ℹ️ Table "shifts" already exists. Skipping.');
      } else {
        console.error('❌ Error creating "shifts" table:', err.message);
      }
    }

    // Add default_shift_id to users
    await addColumnSafe('users', 'default_shift_id', {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: true,
      field: 'default_shift_id',
    });

    // Add columns to attendances
    await addColumnSafe('attendances', 'shift_id', {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: true,
      field: 'shift_id',
    });

    await addColumnSafe('attendances', 'is_late_in', {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'is_late_in',
    });

    await addColumnSafe('attendances', 'is_late_out', {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'is_late_out',
    });

    await addColumnSafe('attendances', 'is_early_in', {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'is_early_in',
    });

    await addColumnSafe('attendances', 'is_early_out', {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'is_early_out',
    });

    await addColumnSafe('attendances', 'overtime_allowed', {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'overtime_allowed',
    });

    await addColumnSafe('attendances', 'overtime_duration', {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'overtime_duration',
    });

    console.log('🎉 Shift Migrations successfully completed.');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
};

migrate();
