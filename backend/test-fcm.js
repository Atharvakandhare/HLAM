/**
 * FCM Test Script
 * Usage:
 *   node test-fcm.js                  → sends to ALL users who have an fcm_token
 *   node test-fcm.js <token>          → sends to a specific FCM token
 *   node test-fcm.js --checkin        → simulates a check-in reminder to all users
 *   node test-fcm.js --checkout       → simulates a check-out reminder to all users
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const admin = require('firebase-admin');
const { Sequelize, DataTypes } = require('sequelize');

// ─── Initialize Firebase ─────────────────────────────────────────────────────
try {
  const serviceAccount = require('./config/firebase-service-account.json');
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  console.log('✅ Firebase Admin SDK initialized.');
} catch (e) {
  console.error('❌ Firebase init failed:', e.message);
  process.exit(1);
}

// ─── Initialize DB ────────────────────────────────────────────────────────────
const sequelize = new Sequelize(
  process.env.DB_NAME,
  process.env.DB_USER,
  process.env.DB_PASSWORD,
  {
    host: process.env.DB_HOST || 'localhost',
    dialect: 'mysql',
    logging: false,
  }
);

const User = sequelize.define('User', {
  id: { type: DataTypes.INTEGER, primaryKey: true },
  name: { type: DataTypes.STRING },
  fcmToken: { type: DataTypes.STRING, field: 'fcm_token' },
}, { tableName: 'users', timestamps: false });

// ─── Send Push Helper ─────────────────────────────────────────────────────────
async function sendPush(token, title, body) {
  try {
    const message = {
      notification: { title, body },
      token,
      android: { priority: 'high' },
      apns: { payload: { aps: { contentAvailable: true } } },
    };
    const response = await admin.messaging().send(message);
    console.log(`  ✅ Sent! Message ID: ${response}`);
  } catch (err) {
    console.error(`  ❌ Failed: ${err.message}`);
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────
(async () => {
  const args = process.argv.slice(2);
  const specificToken = args.find(a => !a.startsWith('--'));
  const isCheckin  = args.includes('--checkin');
  const isCheckout = args.includes('--checkout');

  // Default titles
  let title = '🔔 Test Notification';
  let body  = 'FCM is working correctly on your HLAM app!';

  if (isCheckin) {
    title = 'Check-In Reminder ⏰';
    body  = 'Your shift starts soon. Don\'t forget to check in!';
  } else if (isCheckout) {
    title = 'Check-Out Reminder ⏰';
    body  = 'Your shift has ended. Please record your check-out!';
  }

  // ── Case 1: specific token passed as argument ──────────────────────────────
  if (specificToken) {
    console.log(`\n📤 Sending to specific token: ${specificToken.substring(0, 20)}...`);
    await sendPush(specificToken, title, body);
    process.exit(0);
  }

  // ── Case 2: send to ALL users in DB with an fcm_token ─────────────────────
  try {
    await sequelize.authenticate();
    console.log('✅ DB connected.\n');

    const users = await User.findAll({
      where: sequelize.literal('fcm_token IS NOT NULL AND fcm_token != ""'),
      attributes: ['id', 'name', 'fcmToken'],
    });

    if (users.length === 0) {
      console.log('⚠️  No users with FCM tokens found in the database.');
      console.log('   → Open the app on your phone and login first, then try again.');
      process.exit(0);
    }

    console.log(`Found ${users.length} user(s) with FCM tokens:\n`);
    for (const user of users) {
      console.log(`  👤 ${user.name} (ID: ${user.id}) — token: ${user.fcmToken.substring(0, 20)}...`);
      await sendPush(user.fcmToken, title, `Hi ${user.name}, ${body}`);
    }
  } catch (err) {
    console.error('DB Error:', err.message);
  } finally {
    await sequelize.close();
    process.exit(0);
  }
})();
