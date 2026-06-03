const { sequelize } = require('./config/dbconnect');
const { User } = require('./associations');

const check = async () => {
  try {
    await sequelize.authenticate();
    console.log('DB connected.');
    const users = await User.findAll({ attributes: ['id', 'email', 'role'] });
    console.log('All Users in DB:', users.map(u => u.toJSON()));
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
};
check();
