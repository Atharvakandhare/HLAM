const { sequelize } = require('./config/dbconnect');
const { User } = require('./associations');

const check = async () => {
  try {
    await sequelize.authenticate();
    console.log('DB connected.');
    const { Team } = require('./associations');
    const users = await User.findAll({ attributes: ['id', 'name', 'email', 'role', 'companyId', 'teamId'] });
    console.log('All Users in DB:', users.map(u => u.toJSON()));
    const teams = await Team.findAll();
    console.log('All Teams in DB:', teams.map(t => t.toJSON()));
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
};
check();
