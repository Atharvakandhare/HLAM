const { Attendance, Shift, User, CompanySetting } = require('../associations');
const { Op } = require('sequelize');

// Helper to get local date string YYYY-MM-DD
const getLocalDateString = (d = new Date()) => {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

// Helper to parse time string "HH:MM:SS" into milliseconds from midnight
const getTimeMs = (timeStr) => {
  if (!timeStr) return 0;
  const [hrs, mins, secs] = timeStr.split(':').map(Number);
  return ((hrs * 60 + mins) * 60 + (secs || 0)) * 1000;
};

// Helper to get milliseconds from midnight of a Date object
const getDateMsSinceMidnight = (date) => {
  if (!date) return 0;
  const hrs = date.getHours();
  const mins = date.getMinutes();
  const secs = date.getSeconds();
  return ((hrs * 60 + mins) * 60 + secs) * 1000;
};

/**
 * 1. Shift-End Status Refresher
 * Runs periodically to refresh the status of all employees whose shifts have completed.
 */
const refreshShiftStatuses = async () => {
  try {
    const todayStr = getLocalDateString();
    const now = new Date();
    const currentMs = getDateMsSinceMidnight(now);

    console.log(`[Scheduler] Running Shift-End Status Refresher at local time ${now.toLocaleTimeString()}...`);

    // Find all active attendance records for today that are checked in but NOT yet checked out
    const activeAttendances = await Attendance.findAll({
      where: {
        date: todayStr,
        checkInTime: { [Op.ne]: null },
        checkOutTime: null
      },
      include: [{ model: Shift, as: 'shift' }]
    });

    for (const record of activeAttendances) {
      if (record.shift) {
        const shiftEndMs = getTimeMs(record.shift.checkOutTime);
        // If the current time is past the shift end time
        if (currentMs >= shiftEndMs) {
          // Calculate active session duration so far
          const sessionMs = now - new Date(record.checkInTime);
          
          // Get other completed sessions of today
          const otherRecords = await Attendance.findAll({
            where: {
              userId: record.userId,
              date: todayStr,
              id: { [Op.ne]: record.id },
              checkOutTime: { [Op.ne]: null }
            }
          });

          let totalWorkedMs = sessionMs;
          for (const r of otherRecords) {
            totalWorkedMs += (new Date(r.checkOutTime) - new Date(r.checkInTime));
          }

          const shiftStartMs = getTimeMs(record.shift.checkInTime);
          const requiredShiftMs = shiftEndMs - shiftStartMs;

          let finalStatus = 'present';
          if (totalWorkedMs < requiredShiftMs) {
            const ratio = totalWorkedMs / requiredShiftMs;
            finalStatus = ratio < 0.5 ? 'half_day' : 'present';
          }

          // Update this record and all today's records for this user
          record.status = finalStatus;
          await record.save();

          await Attendance.update({ status: finalStatus }, {
            where: { userId: record.userId, date: todayStr }
          });

          console.log(`[Scheduler] Auto-refreshed status to "${finalStatus}" for User ID ${record.userId} (Shift: ${record.shift.name}).`);
        }
      }
    }
  } catch (err) {
    console.error('[Scheduler] Error in refreshShiftStatuses:', err.message);
  }
};

/**
 * 2. Midnight Auto-Checkout
 * Auto-checks out any open sessions from the previous day(s) at 12:00 AM.
 */
const autoCheckoutOpenSessions = async () => {
  try {
    const todayStr = getLocalDateString();
    console.log(`[Scheduler] Running Midnight Auto-Checkout...`);

    // Find all attendance records from previous days where checkOutTime is NULL
    const openRecords = await Attendance.findAll({
      where: {
        date: { [Op.lt]: todayStr },
        checkOutTime: null
      },
      include: [{ model: Shift, as: 'shift' }]
    });

    for (const record of openRecords) {
      // Determine what checkout time to write: shift checkOutTime or company settings checkOutTime or midnight
      let autoCheckoutTime = new Date(record.date + 'T23:59:59'); // default to end of that day

      if (record.shift) {
        autoCheckoutTime = new Date(record.date + 'T' + record.shift.checkOutTime);
      } else {
        const user = await User.findByPk(record.userId);
        if (user && user.companyId) {
          const setting = await CompanySetting.findOne({ where: { companyId: user.companyId } });
          if (setting && setting.checkOutTime) {
            autoCheckoutTime = new Date(record.date + 'T' + setting.checkOutTime);
          }
        }
      }

      record.checkOutTime = autoCheckoutTime;
      record.checkoutSelfieUrl = 'system-auto-checkout';
      record.checkoutAddress = 'Auto checked out by system at midnight';
      record.logoutStatus = 'success';

      // Calculate working hours
      const diffMs = autoCheckoutTime - new Date(record.checkInTime);
      
      // Get other completed sessions of that day
      const otherRecords = await Attendance.findAll({
        where: {
          userId: record.userId,
          date: record.date,
          id: { [Op.ne]: record.id },
          checkOutTime: { [Op.ne]: null }
        }
      });

      let totalWorkedMs = diffMs > 0 ? diffMs : 0;
      for (const r of otherRecords) {
        totalWorkedMs += (new Date(r.checkOutTime) - new Date(r.checkInTime));
      }

      const diffHrs = Math.floor(totalWorkedMs / (1000 * 60 * 60));
      const diffMins = Math.floor((totalWorkedMs % (1000 * 60 * 60)) / (1000 * 60));
      record.workingHours = `${diffHrs}h ${diffMins}m`;

      // Assign status based on shift or company settings
      let finalStatus = 'present';
      if (record.shift) {
        const shiftStartMs = getTimeMs(record.shift.checkInTime);
        const shiftEndMs = getTimeMs(record.shift.checkOutTime);
        const requiredShiftMs = shiftEndMs - shiftStartMs;
        const ratio = totalWorkedMs / requiredShiftMs;
        finalStatus = ratio < 0.5 ? 'half_day' : 'present';
      }

      record.status = finalStatus;
      await record.save();

      // Propagate to other records of that date
      await Attendance.update({ status: finalStatus }, {
        where: { userId: record.userId, date: record.date }
      });

      console.log(`[Scheduler] Auto checked out User ID ${record.userId} for date ${record.date}. Status: ${finalStatus}.`);
    }
  } catch (err) {
    console.error('[Scheduler] Error in autoCheckoutOpenSessions:', err.message);
  }
};

// Cache to keep track of reminders sent today to avoid spamming
const sentReminders = {
  checkIn: {},  // userId: YYYY-MM-DD
  checkOut: {}, // userId: YYYY-MM-DD
};

/**
 * 3. Send Push Notification Reminders for Check-in & Check-out
 */
const sendReminderNotifications = async () => {
  try {
    const todayStr = getLocalDateString();
    const now = new Date();
    const currentMs = getDateMsSinceMidnight(now);

    console.log(`[Scheduler] Checking for push notification reminders at local time ${now.toLocaleTimeString()}...`);

    // Fetch all active users with their default shift and company settings
    const users = await User.findAll({
      where: { isActive: true },
      include: [
        { model: Shift, as: 'defaultShift' },
        { 
          model: Company, 
          as: 'company',
          include: [{ model: CompanySetting, as: 'settings' }]
        }
      ]
    });

    for (const user of users) {
      if (!user.fcmToken) continue; // No token, skip

      // Check if user has already checked in today
      const todayAttendance = await Attendance.findOne({
        where: { userId: user.id, date: todayStr }
      });

      // A. Check-In Reminder Logic
      if (!todayAttendance) {
        // User has not checked in today
        if (sentReminders.checkIn[user.id] !== todayStr) {
          let targetCheckInTime = null;
          if (user.defaultShift) {
            targetCheckInTime = user.defaultShift.checkInTime;
          } else if (user.company && user.company.settings && user.company.settings.checkInTime) {
            targetCheckInTime = user.company.settings.checkInTime;
          }

          if (targetCheckInTime) {
            const checkInMs = getTimeMs(targetCheckInTime);
            // Remind 15 minutes before the check-in time
            const remindStartMs = checkInMs - 15 * 60 * 1000;
            if (currentMs >= remindStartMs && currentMs < checkInMs) {
              await sendPush(
                user.fcmToken,
                "Check-In Reminder ⏰",
                `Hi ${user.name}, your shift starts soon. Don't forget to check in!`
              );
              sentReminders.checkIn[user.id] = todayStr;
            }
          }
        }
      }

      // B. Check-Out Reminder Logic
      if (todayAttendance && !todayAttendance.checkOutTime) {
        // User is currently checked in but hasn't checked out
        if (sentReminders.checkOut[user.id] !== todayStr) {
          let targetCheckOutTime = null;
          // Use shift of today's attendance record, or default shift, or company settings
          if (todayAttendance.shiftId) {
            const activeShift = await Shift.findByPk(todayAttendance.shiftId);
            if (activeShift) {
              targetCheckOutTime = activeShift.checkOutTime;
            }
          } else if (user.defaultShift) {
            targetCheckOutTime = user.defaultShift.checkOutTime;
          } else if (user.company && user.company.settings && user.company.settings.checkOutTime) {
            targetCheckOutTime = user.company.settings.checkOutTime;
          }

          if (targetCheckOutTime) {
            const checkOutMs = getTimeMs(targetCheckOutTime);
            // Remind when shift ends
            if (currentMs >= checkOutMs) {
              await sendPush(
                user.fcmToken,
                "Check-Out Reminder ⏰",
                `Hi ${user.name}, your shift has ended. Please don't forget to record your check-out!`
              );
              sentReminders.checkOut[user.id] = todayStr;
            }
          }
        }
      }
    }
  } catch (err) {
    console.error('[Scheduler] Error in sendReminderNotifications:', err.message);
  }
};

/**
 * Send push helper
 */
const sendPush = async (token, title, body) => {
  try {
    const admin = require('firebase-admin');
    if (admin.apps.length === 0) {
      console.log('[Scheduler] Firebase Admin is not initialized. Skipping push notification.');
      return;
    }
    const message = {
      notification: { title, body },
      token: token,
      android: { priority: 'high' },
      apns: { payload: { aps: { contentAvailable: true } } }
    };
    await admin.messaging().send(message);
    console.log(`[Scheduler] Push notification sent to token ${token.substring(0, 15)}...`);
  } catch (error) {
    console.error('[Scheduler] Error sending push notification:', error.message);
  }
};

/**
 * Initialize and start the background scheduler
 */
const startScheduler = () => {
  console.log('⏰ Starting Background Attendance Scheduler...');
  
  // 1. Run Shift-End Status Refresher every 15 minutes (15 * 60 * 1000 ms)
  setInterval(refreshShiftStatuses, 15 * 60 * 1000);
  
  // 2. Run Midnight Auto-Checkout check every hour (60 * 60 * 1000 ms)
  setInterval(async () => {
    const now = new Date();
    // If it is midnight (hour is 0), run auto-checkout
    if (now.getHours() === 0) {
      await autoCheckoutOpenSessions();
    }
  }, 60 * 60 * 1000);

  // 3. Run Check-In and Check-Out reminders every 5 minutes (5 * 60 * 1000 ms)
  setInterval(sendReminderNotifications, 5 * 60 * 1000);
 
  // Run initial checks on startup (non-blocking)
  setTimeout(async () => {
    await refreshShiftStatuses();
    await autoCheckoutOpenSessions();
    await sendReminderNotifications();
  }, 5000);
};

module.exports = {
  startScheduler,
};
