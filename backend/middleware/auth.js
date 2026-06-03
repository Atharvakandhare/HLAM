const jwt = require('jsonwebtoken');
const { User } = require('../associations');

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'Authorization header missing' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'dev-secret');

    const user = await User.findByPk(decoded.id);
    if (!user || !user.isActive) {
      return res.status(401).json({ message: 'User not found or inactive' });
    }

    req.user = user;
    next();
  } catch (error) {
    console.error(`[Auth] Token validation failed: ${error.message}`);
    console.error(`[Auth] Header used: ${req.headers.authorization}`);
    return res.status(401).json({ message: 'Invalid or expired token', error: error.message });
  }
};

const adminOnly = (req, res, next) => {
  // Admins, Managers, and Team Leaders can access attendance records
  const allowed = ['system_admin', 'company_admin', 'manager', 'team_leader'];
  if (!allowed.includes(req.user?.role)) {
    return res.status(403).json({ message: 'Admin, Manager, or Team Leader access required' });
  }
  next();
};

const systemAdminOnly = (req, res, next) => {
  if (req.user?.role !== 'system_admin') {
    return res.status(403).json({ message: 'System Admin access required' });
  }
  next();
};

const companyAdminOnly = (req, res, next) => {
  const allowed = ['system_admin', 'company_admin'];
  if (!allowed.includes(req.user?.role)) {
    return res.status(403).json({ message: 'Company Admin access required' });
  }
  next();
};

const approverOnly = (req, res, next) => {
  const allowed = ['system_admin', 'company_admin', 'manager', 'team_leader'];
  if (!allowed.includes(req.user?.role)) {
    return res.status(403).json({ message: 'Manager, Team Leader, or Admin access required' });
  }
  next();
};

module.exports = { authMiddleware, adminOnly, systemAdminOnly, companyAdminOnly, approverOnly };


