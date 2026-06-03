const User = require('./models/User');
const Attendance = require('./models/Attendance');
const Leave = require('./models/Leave');
const LocationLog = require('./models/LocationLog');
const Company = require('./models/Company');
const Team = require('./models/Team');
const CompanySetting = require('./models/CompanySetting');
const Holiday = require('./models/Holiday');
const HolidayException = require('./models/HolidayException');

// Define model relationships
User.hasMany(Attendance, { foreignKey: 'userId', as: 'attendances' });
Attendance.belongsTo(User, { foreignKey: 'userId', as: 'user' });

User.hasMany(Leave, { foreignKey: 'userId', as: 'leaves' });
Leave.belongsTo(User, { foreignKey: 'userId', as: 'user' });

User.hasMany(LocationLog, { foreignKey: 'userId', as: 'locationLogs' });
LocationLog.belongsTo(User, { foreignKey: 'userId', as: 'user' });

// Company relationships
Company.hasMany(User, { foreignKey: 'companyId', as: 'users' });
User.belongsTo(Company, { foreignKey: 'companyId', as: 'company' });

Company.hasMany(Team, { foreignKey: 'companyId', as: 'teams' });
Team.belongsTo(Company, { foreignKey: 'companyId', as: 'company' });

Company.hasOne(CompanySetting, { foreignKey: 'companyId', as: 'settings' });
CompanySetting.belongsTo(Company, { foreignKey: 'companyId', as: 'company' });

// Team relationships
Team.hasMany(User, { foreignKey: 'teamId', as: 'users' });
User.belongsTo(Team, { foreignKey: 'teamId', as: 'team' });

Team.belongsTo(User, { foreignKey: 'managerId', as: 'manager' });
Team.belongsTo(User, { foreignKey: 'teamLeaderId', as: 'teamLeader' });

// Holiday relationships
Company.hasMany(Holiday, { foreignKey: 'companyId', as: 'holidays' });
Holiday.belongsTo(Company, { foreignKey: 'companyId', as: 'company' });

Holiday.hasMany(HolidayException, { foreignKey: 'holidayId', as: 'exceptions' });
HolidayException.belongsTo(Holiday, { foreignKey: 'holidayId', as: 'holiday' });

HolidayException.belongsTo(User, { foreignKey: 'userId', as: 'user' });
HolidayException.belongsTo(Team, { foreignKey: 'teamId', as: 'team' });

module.exports = {
  User,
  Attendance,
  Leave,
  LocationLog,
  Company,
  Team,
  CompanySetting,
  Holiday,
  HolidayException,
};
