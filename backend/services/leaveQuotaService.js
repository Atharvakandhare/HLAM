const { Leave, User, CompanySetting } = require('../associations');
const { Op } = require('sequelize');

const getMostRecentResetDate = (targetDateStr, refreshMonth, refreshDay) => {
  const target = new Date(targetDateStr);
  const year = target.getFullYear();
  let resetDate = new Date(year, refreshMonth - 1, refreshDay);
  if (target < resetDate) {
    resetDate = new Date(year - 1, refreshMonth - 1, refreshDay);
  }
  return resetDate;
};

const calculateUserLeavesQuota = async (userId, targetDateStr) => {
  const user = await User.findByPk(userId);
  if (!user) {
    throw new Error('User not found');
  }

  const companyId = user.companyId;
  const settings = await CompanySetting.findOne({ where: { companyId } });

  const M = settings ? settings.monthlyPaidLeaves : 0;
  const Y = settings ? settings.yearlyPaidLeaves : 0;
  const refreshMonth = settings ? settings.leavesRefreshMonth : 1;
  const refreshDay = settings ? settings.leavesRefreshDay : 1;

  const targetDate = new Date(targetDateStr);
  const mostRecentReset = getMostRecentResetDate(targetDateStr, refreshMonth, refreshDay);

  // Generate months in the current cycle up to the target month, AND the next month
  const monthsInCycle = [];
  let curr = new Date(mostRecentReset.getFullYear(), mostRecentReset.getMonth(), 1);
  
  // We want to calculate up to targetMonth + 1 (next month) to see what's available next month
  const targetNextMonth = new Date(targetDate.getFullYear(), targetDate.getMonth() + 1, 1);

  while (curr <= targetNextMonth) {
    monthsInCycle.push({
      year: curr.getFullYear(),
      month: curr.getMonth(), // 0-indexed
      label: curr.toLocaleString('default', { month: 'long', year: 'numeric' }),
    });
    curr.setMonth(curr.getMonth() + 1);
  }

  // Fetch all approved leaves for this user starting from mostRecentReset
  const approvedLeaves = await Leave.findAll({
    where: {
      userId,
      status: 'approved',
      startDate: {
        [Op.gte]: mostRecentReset.toISOString().split('T')[0]
      }
    },
    order: [['startDate', 'ASC']]
  });

  const isDateInMonth = (dateStr, year, month) => {
    const d = new Date(dateStr);
    return d.getFullYear() === year && d.getMonth() === month;
  };

  let carryForward = 0;
  let borrowedFromThisMonth = 0;
  const details = [];

  for (const m of monthsInCycle) {
    const monthLeaves = approvedLeaves.filter(l => isDateInMonth(l.startDate, m.year, m.month));
    const paidDaysUsed = monthLeaves.reduce((sum, l) => sum + (l.paidDays || 0), 0);
    const nextMonthPaidDaysUsed = monthLeaves.reduce((sum, l) => sum + (l.nextMonthPaidDays || 0), 0);

    const startBalance = Math.max(0, M + carryForward - borrowedFromThisMonth);
    const remaining = Math.max(0, startBalance - paidDaysUsed);

    details.push({
      year: m.year,
      month: m.month,
      label: m.label,
      startBalance,
      paidDaysUsed,
      nextMonthPaidDaysUsed,
      borrowedFromPrevMonth: borrowedFromThisMonth,
      remaining
    });

    carryForward = remaining;
    borrowedFromThisMonth = nextMonthPaidDaysUsed;
  }

  // Find detail for target month
  const targetDetail = details.find(d => d.year === targetDate.getFullYear() && d.month === targetDate.getMonth());
  const nextMonthDetail = details.find(d => {
    const nextDate = new Date(targetDate.getFullYear(), targetDate.getMonth() + 1, 1);
    return d.year === nextDate.getFullYear() && d.month === nextDate.getMonth();
  });

  const availableThisMonth = targetDetail ? targetDetail.remaining : Math.max(0, M - borrowedFromThisMonth);
  const availableNextMonth = nextMonthDetail ? nextMonthDetail.startBalance : M;

  return {
    monthlyPolicy: M,
    yearlyPolicy: Y,
    leavesRefreshMonth: refreshMonth,
    leavesRefreshDay: refreshDay,
    availableThisMonth,
    availableNextMonth,
    details
  };
};

module.exports = {
  getMostRecentResetDate,
  calculateUserLeavesQuota
};
