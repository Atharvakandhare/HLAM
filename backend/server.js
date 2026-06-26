const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

if (!process.env.JWT_SECRET) {
    console.error('[CRITICAL] JWT_SECRET is not defined in .env! Using fallback "dev-secret".');
} else {
    console.log('✅ JWT_SECRET loaded from .env');
}

// Global Error Handlers - KEEP SERVER ALIVE
process.on('uncaughtException', (err) => {
    console.error('[CRITICAL] Uncaught Exception:', err.message);
    console.error(err.stack);
    // Optionally: do NOT exit, or let nodemon restart
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('[CRITICAL] Unhandled Rejection at:', promise, 'reason:', reason);
});

const app = require('./app');
const { dbConnection, sequelize } = require('./config/dbconnect');
const { User, Company, CompanySetting } = require('./associations'); // sets up model relationships
const bcrypt = require('bcryptjs');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
try {
    const serviceAccount = require('./config/firebase-service-account.json');
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    console.log('✅ Firebase Admin SDK initialized successfully.');
} catch (error) {
    console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
}

const PORT = process.env.PORT || 8000;
const HOST = process.env.HOST || '0.0.0.0'; // Bind to all interfaces for deployment

const seedAdmin = async () => {
    try {
        // 1. Create default Company
        const [defaultCompany] = await Company.findOrCreate({
            where: { name: 'Hirelyft India Pvt. Ltd.' },
            defaults: { status: 'approved', isActive: true }
        });
        if (defaultCompany.status !== 'approved') {
            defaultCompany.status = 'approved';
            await defaultCompany.save();
        }

        // 2. Create default CompanySetting
        await CompanySetting.findOrCreate({
            where: { companyId: defaultCompany.id },
            defaults: {
                checkInTime: '09:00:00',
                checkOutTime: '18:00:00',
                latitude: 0.0,
                longitude: 0.0,
                address: null,
                radius: 100.0
            }
        });

        const adminEmail = process.env.ADMIN_EMAIL || 'admin@hirelyft.in';
        const adminPassword = process.env.ADMIN_PASSWORD || 'hirelyftadmin@123';
        const adminName = process.env.ADMIN_NAME || 'Hirelyft India Pvt. Ltd.';

        const existingAdmin = await User.findOne({ where: { email: adminEmail } });
        if (!existingAdmin) {
            const hashedPassword = await bcrypt.hash(adminPassword, 10);
            await User.create({
                name: adminName,
                email: adminEmail,
                password: hashedPassword,
                role: 'system_admin',
                isActive: true,
                companyId: defaultCompany.id
            });
            console.log(`✅ Default admin created: ${adminEmail}`);
        } else {
            existingAdmin.role = 'system_admin';
            existingAdmin.companyId = defaultCompany.id;
            await existingAdmin.save();
            console.log(`ℹ️ Admin user set to system_admin: ${adminEmail}`);
        }

        // Associate all existing users without companyId with the default company
        await User.update(
            { companyId: defaultCompany.id },
            { where: { companyId: null } }
        );
        console.log('✅ Associated all orphaned users with Hirelyft company.');
    } catch (error) {
        console.error('❌ Error seeding admin & company:', error.message);
    }
};

const startServer = async () => {
    // Connect to Database
    const isConnected = await dbConnection();
    if (!isConnected) {
        process.exit(1);
    }

    // 3-Step migration to safely alter role enum
    try {
        // Step 1: Add all new values to the ENUM while keeping 'admin'
        await sequelize.query("ALTER TABLE users MODIFY COLUMN role ENUM('admin', 'system_admin', 'company_admin', 'manager', 'team_leader', 'employee') DEFAULT 'employee';");
        console.log('✅ Step 1: Added new values to users role enum.');

        // Step 2: Update existing 'admin' users to 'system_admin'
        await sequelize.query("UPDATE users SET role = 'system_admin' WHERE role = 'admin';");
        console.log('✅ Step 2: Updated existing admin roles to system_admin.');

        // Step 3: Remove 'admin' from the ENUM list
        await sequelize.query("ALTER TABLE users MODIFY COLUMN role ENUM('system_admin', 'company_admin', 'manager', 'team_leader', 'employee') DEFAULT 'employee';");
        console.log('✅ Step 3: Removed admin from users role enum.');
    } catch (err) {
        console.log('ℹ️ Role enum migration skipped or failed. Error:', err.message);
    }

    try {
        await sequelize.query("ALTER TABLE attendances MODIFY COLUMN status ENUM('present', 'late', 'absent', 'half_day') DEFAULT 'present';");
        console.log('✅ Altered attendances status enum successfully.');
    } catch (err) {
        console.log('ℹ️ attendances status enum alteration skipped or table does not exist yet.');
    }

    // Convert database and tables to utf8mb4 to support Unicode (e.g., Hindi addresses/emojis)
    try {
        const dbName = sequelize.config.database;
        await sequelize.query(`ALTER DATABASE \`${dbName}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
        console.log(`✅ Altered database \`${dbName}\` character set to utf8mb4.`);
    } catch (err) {
        console.log('ℹ️ Altering database character set failed:', err.message);
    }

    try {
        await sequelize.query("ALTER TABLE attendances CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
        console.log('✅ Converted attendances table to utf8mb4 successfully.');
    } catch (err) {
        console.log('ℹ️ Converting attendances table to utf8mb4 skipped or failed:', err.message);
    }

    try {
        await sequelize.query("ALTER TABLE location_logs CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
        console.log('✅ Converted location_logs table to utf8mb4 successfully.');
    } catch (err) {
        console.log('ℹ️ Converting location_logs table to utf8mb4 skipped or failed:', err.message);
    }

    try {
        await sequelize.query("ALTER TABLE users CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
        console.log('✅ Converted users table to utf8mb4 successfully.');
    } catch (err) {
        console.log('ℹ️ Converting users table to utf8mb4 skipped or failed:', err.message);
    }

    // Sync models with database with retry logic
    const forceSync = process.env.DB_SYNC_FORCE === 'true';
    let synced = false;
    let retries = 5;

    while (retries > 0 && !synced) {
        try {
            const queryInterface = sequelize.getQueryInterface();
            try {
                const tableDefinition = await queryInterface.describeTable('users');
                const { DataTypes } = require('sequelize');

                if (!tableDefinition.profile_picture) {
                    await queryInterface.addColumn('users', 'profile_picture', {
                        type: DataTypes.STRING,
                        allowNull: true
                    });
                    console.log('✅ Added profile_picture column.');
                }
                if (!tableDefinition.is_profile_picture_admin_set) {
                    await queryInterface.addColumn('users', 'is_profile_picture_admin_set', {
                        type: DataTypes.BOOLEAN,
                        defaultValue: false
                    });
                    console.log('✅ Added is_profile_picture_admin_set column.');
                }
                if (!tableDefinition.company_id) {
                    await queryInterface.addColumn('users', 'company_id', {
                        type: DataTypes.INTEGER.UNSIGNED,
                        allowNull: true
                    });
                    console.log('✅ Added company_id column.');
                }
                if (!tableDefinition.team_id) {
                    await queryInterface.addColumn('users', 'team_id', {
                        type: DataTypes.INTEGER.UNSIGNED,
                        allowNull: true
                    });
                    console.log('✅ Added team_id column.');
                }
                if (!tableDefinition.dob) {
                    await queryInterface.addColumn('users', 'dob', {
                        type: DataTypes.DATEONLY,
                        allowNull: true
                    });
                    console.log('✅ Added dob column.');
                }
                if (!tableDefinition.state) {
                    await queryInterface.addColumn('users', 'state', {
                        type: DataTypes.STRING,
                        allowNull: true
                    });
                    console.log('✅ Added state column.');
                }
                if (!tableDefinition.city) {
                    await queryInterface.addColumn('users', 'city', {
                        type: DataTypes.STRING,
                        allowNull: true
                    });
                    console.log('✅ Added city column.');
                }
                if (!tableDefinition.work_mode) {
                    await queryInterface.addColumn('users', 'work_mode', {
                        type: DataTypes.ENUM('Work From Office', 'Work From Home', 'Remote Work'),
                        defaultValue: 'Work From Office'
                    });
                    console.log('✅ Added work_mode column.');
                }
                if (!tableDefinition.work_type) {
                    await queryInterface.addColumn('users', 'work_type', {
                        type: DataTypes.ENUM('Work From Office', 'Field Work', 'Office + Field Work'),
                        allowNull: true
                    });
                    console.log('✅ Added work_type column.');
                }
            } catch (err) {
                console.log('ℹ️ Dynamic migration skipped for users (table does not exist yet).');
            }

            try {
                const locationTableDefinition = await queryInterface.describeTable('location_logs');
                const { DataTypes } = require('sequelize');
                if (!locationTableDefinition.address) {
                    await queryInterface.addColumn('location_logs', 'address', {
                        type: DataTypes.STRING,
                        allowNull: true
                    });
                    console.log('✅ Added address column to location_logs table.');
                }
            } catch (err) {
                console.log('ℹ️ Dynamic migration skipped for location_logs (table does not exist yet).');
            }

            try {
                const attendanceTableDefinition = await queryInterface.describeTable('attendances');
                const { DataTypes } = require('sequelize');
                if (!attendanceTableDefinition.mood) {
                    await queryInterface.addColumn('attendances', 'mood', {
                        type: DataTypes.ENUM('happy', 'sad', 'exhausted', 'angry'),
                        allowNull: true
                    });
                    console.log('✅ Added mood column to attendances table.');
                }
                if (!attendanceTableDefinition.energy_level) {
                    await queryInterface.addColumn('attendances', 'energy_level', {
                        type: DataTypes.ENUM('low', 'medium', 'high'),
                        allowNull: true
                    });
                    console.log('✅ Added energy_level column to attendances table.');
                }
                if (!attendanceTableDefinition.distance_from_office) {
                    await queryInterface.addColumn('attendances', 'distance_from_office', {
                        type: DataTypes.FLOAT,
                        allowNull: true
                    });
                    console.log('✅ Added distance_from_office column to attendances table.');
                }
            } catch (err) {
                console.log('ℹ️ Dynamic migration skipped for attendances (table does not exist yet).');
            }

            try {
                const teamsTableDefinition = await queryInterface.describeTable('teams');
                const { DataTypes } = require('sequelize');
                if (!teamsTableDefinition.manager_id) {
                    await queryInterface.addColumn('teams', 'manager_id', {
                        type: DataTypes.INTEGER.UNSIGNED,
                        allowNull: true
                    });
                    console.log('✅ Added manager_id column to teams table.');
                }
                if (!teamsTableDefinition.team_leader_id) {
                    await queryInterface.addColumn('teams', 'team_leader_id', {
                        type: DataTypes.INTEGER.UNSIGNED,
                        allowNull: true
                    });
                    console.log('✅ Added team_leader_id column to teams table.');
                }
            } catch (err) {
                console.log('ℹ️ Dynamic migration skipped for teams (table does not exist yet).');
            }

            // Dynamic self-healing block to clean up duplicate/redundant index keys on the users table
            try {
                const [results] = await sequelize.query("SHOW INDEX FROM users;");
                const indexNamesToDrop = [];
                const indexesByColumn = {};

                for (const row of results) {
                    const keyName = row.Key_name;
                    const columnName = row.Column_name;

                    if (keyName === 'PRIMARY') continue;

                    if (!indexesByColumn[columnName]) {
                        indexesByColumn[columnName] = [];
                    }
                    if (!indexesByColumn[columnName].includes(keyName)) {
                        indexesByColumn[columnName].push(keyName);
                    }
                }

                // Group by column and keep the cleanest index name (the one without trailing _number)
                for (const columnName in indexesByColumn) {
                    const keyNames = indexesByColumn[columnName];
                    if (keyNames.length > 1) {
                        keyNames.sort((a, b) => {
                            const aIsSuffix = /_\d+$/.test(a);
                            const bIsSuffix = /_\d+$/.test(b);
                            if (aIsSuffix && !bIsSuffix) return 1;
                            if (!aIsSuffix && bIsSuffix) return -1;
                            return a.localeCompare(b);
                        });

                        // Keep keyNames[0], add others to drop list
                        for (let i = 1; i < keyNames.length; i++) {
                            if (!indexNamesToDrop.includes(keyNames[i])) {
                                indexNamesToDrop.push(keyNames[i]);
                            }
                        }
                    }
                }

                for (const indexName of indexNamesToDrop) {
                    try {
                        await sequelize.query(`ALTER TABLE users DROP INDEX \`${indexName}\`;`);
                        console.log(`✅ Cleaned up redundant key/index "${indexName}" from users table.`);
                    } catch (dropErr) {
                        console.log(`ℹ️ Redundant index key cleanup skipped/failed for "${indexName}":`, dropErr.message);
                    }
                }
            } catch (err) {
                console.log('ℹ️ Redundant index key cleanup skipped or table does not exist yet.');
            }

            await sequelize.sync({ force: forceSync, alter: false });
            synced = true;
            console.log(forceSync ? '⚠️ Database cleared and recreated.' : '✅ Database synced.');
        } catch (syncError) {
            retries -= 1;
            console.error(`❌ Sync error (retries left: ${retries}):`, syncError.message);
            if (retries === 0) throw syncError;
            await new Promise(res => setTimeout(res, 2000)); // wait 2s before retry
        }
    }

    // Seed default admin
    await seedAdmin();

    // Start background scheduler
    const { startScheduler } = require('./services/scheduler');
    startScheduler();

    // Start Server
    app.listen(PORT, HOST, () => {
        console.log(`Server is running on ${HOST}:${PORT}`);
    });
};

startServer();

