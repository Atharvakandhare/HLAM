const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { User, Company, Team, CompanySetting } = require('../associations');

const generateToken = (userId) =>
  jwt.sign({ id: userId }, process.env.JWT_SECRET || 'dev-secret', {
    expiresIn: process.env.JWT_EXPIRES_IN || '35d',
  });

// Helper function to build detailed user profile response
const getUserProfileResponse = async (userId) => {
  const user = await User.findByPk(userId, {
    include: [
      {
        model: Company,
        as: 'company',
        include: [{ model: CompanySetting, as: 'settings' }]
      },
      {
        model: Team,
        as: 'team'
      }
    ]
  });

  if (!user) return null;

  const data = user.toJSON();

  // Find manager and team leader for this team if applicable
  let manager = null;
  let teamLeader = null;

  if (user.teamId) {
    manager = await User.findOne({
      where: {
        teamId: user.teamId,
        role: 'manager',
        isActive: true
      },
      attributes: ['id', 'name', 'email', 'employeeId']
    });

    teamLeader = await User.findOne({
      where: {
        teamId: user.teamId,
        role: 'team_leader',
        isActive: true
      },
      attributes: ['id', 'name', 'email', 'employeeId']
    });
  }

  return {
    id: data.id,
    name: data.name,
    email: data.email,
    role: data.role,
    department: data.department,
    employeeId: data.employeeId,
    profilePicture: data.profilePicture,
    isProfilePictureAdminSet: data.isProfilePictureAdminSet,
    companyId: data.companyId,
    teamId: data.teamId,
    dob: data.dob,
    state: data.state,
    city: data.city,
    workMode: data.workMode,
    workType: data.workType,
    company: data.company ? {
      id: data.company.id,
      name: data.company.name,
      settings: data.company.settings ? {
        checkInTime: data.company.settings.checkInTime,
        checkOutTime: data.company.settings.checkOutTime,
        latitude: parseFloat(data.company.settings.latitude),
        longitude: parseFloat(data.company.settings.longitude),
        address: data.company.settings.address,
        radius: parseFloat(data.company.settings.radius)
      } : null
    } : null,
    team: data.team ? {
      id: data.team.id,
      name: data.team.name
    } : null,
    manager: manager ? {
      id: manager.id,
      name: manager.name,
      email: manager.email,
      employeeId: manager.employeeId
    } : null,
    teamLeader: teamLeader ? {
      id: teamLeader.id,
      name: teamLeader.name,
      email: teamLeader.email,
      employeeId: teamLeader.employeeId
    } : null
  };
};

// Register new user (employee/admin)
const register = async (req, res) => {
  try {
    const { name, email, password, role, department, employeeId, dob, state, city, workMode, workType, companyId, teamId } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ message: 'Name, email, and password are required' });
    }

    const existing = await User.findOne({ where: { email } });
    if (existing) {
      return res.status(409).json({ message: 'Email already registered' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await User.create({
      name,
      email,
      password: hashedPassword,
      role: role || 'employee',
      department,
      employeeId,
      dob,
      state,
      city,
      workMode: workMode || 'Work From Office',
      workType: department?.toLowerCase() === 'marketing' ? workType : null,
      companyId: companyId || null,
      teamId: teamId || null,
    });

    const token = generateToken(user.id);
    const userResponse = await getUserProfileResponse(user.id);
    return res.status(201).json({
      message: 'User registered successfully',
      token,
      user: userResponse,
    });
  } catch (error) {
    return res.status(500).json({ message: 'Registration failed', error: error.message });
  }
};

// Login user (supports email or employeeId)
const login = async (req, res) => {
  try {
    const { email, employeeId, password } = req.body;
    const identifier = email || employeeId;

    if (!identifier || !password) {
      return res.status(400).json({ message: 'Email/Employee ID and password are required' });
    }

    // Try to find user by email or employeeId
    const user = await User.findOne({
      where: email
        ? { email }
        : { employeeId: identifier }
    });

    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    if (!user.isActive) {
      return res.status(401).json({ message: 'Account is inactive' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const token = generateToken(user.id);
    const userResponse = await getUserProfileResponse(user.id);
    return res.json({
      message: 'Login successful',
      token,
      user: userResponse,
    });
  } catch (error) {
    return res.status(500).json({ message: 'Login failed', error: error.message });
  }
};

// Get current profile
const me = async (req, res) => {
  try {
    const userResponse = await getUserProfileResponse(req.user.id);
    if (!userResponse) return res.status(404).json({ message: 'User profile not found' });
    return res.json(userResponse);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to retrieve profile', error: error.message });
  }
};

// Logout (stateless JWT) - client should discard token
const logout = async (_req, res) => {
  return res.json({ message: 'Logged out (client-side token discarded)' });
};

// Refresh token (stateless simple re-issue)
const refreshToken = async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'Authorization header missing' });
    }
    const oldToken = authHeader.split(' ')[1];
    const decoded = jwt.verify(oldToken, process.env.JWT_SECRET || 'dev-secret', { ignoreExpiration: true });
    const newToken = generateToken(decoded.id);
    return res.json({ message: 'Token refreshed', token: newToken });
  } catch (error) {
    return res.status(401).json({ message: 'Invalid token', error: error.message });
  }
};

// Change password
const changePassword = async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    if (!oldPassword || !newPassword) {
      return res.status(400).json({ message: 'Old and new passwords are required' });
    }

    const user = await User.findByPk(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const isMatch = await bcrypt.compare(oldPassword, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Incorrect old password' });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    user.password = hashedPassword;
    await user.save();

    return res.json({ message: 'Password changed successfully' });
  } catch (error) {
    return res.status(500).json({ message: 'Password change failed', error: error.message });
  }
};

// Update employee's own profile picture
const updateProfilePicture = async (req, res) => {
  try {
    const { profilePicture } = req.body;
    if (!profilePicture) {
      return res.status(400).json({ message: 'Profile picture URL is required' });
    }

    const user = await User.findByPk(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    if (user.isProfilePictureAdminSet) {
      return res.status(403).json({
        message: 'Your profile picture has been locked by the administrator and cannot be modified.'
      });
    }

    user.profilePicture = profilePicture;
    await user.save();

    return res.json({
      message: 'Profile picture updated successfully',
      profilePicture: user.profilePicture,
    });
  } catch (error) {
    return res.status(500).json({ message: 'Profile picture update failed', error: error.message });
  }
};

// Delete employee's own profile picture
const deleteProfilePicture = async (req, res) => {
  try {
    const user = await User.findByPk(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    if (user.isProfilePictureAdminSet) {
      return res.status(403).json({
        message: 'Your profile picture has been locked by the administrator and cannot be deleted.'
      });
    }

    user.profilePicture = null;
    await user.save();

    return res.json({
      message: 'Profile picture deleted successfully',
      profilePicture: null,
    });
  } catch (error) {
    return res.status(500).json({ message: 'Profile picture deletion failed', error: error.message });
  }
};

module.exports = {
  register,
  login,
  me,
  logout,
  refreshToken,
  changePassword,
  updateProfilePicture,
  deleteProfilePicture,
};

