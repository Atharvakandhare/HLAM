const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { User, Company, Team, CompanySetting } = require('../associations');
const { sendOtpEmail } = require('../services/mailService');

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

// Register new company and its admin user (public POST)
const registerCompany = async (req, res) => {
  try {
    const { companyName, adminName, adminEmail, adminPassword } = req.body;

    if (!companyName || !adminName || !adminEmail || !adminPassword) {
      return res.status(400).json({ message: 'Company name, admin name, email, and password are required.' });
    }

    // 1. Check if user email exists
    let existingUser = await User.findOne({ where: { email: adminEmail } });
    if (existingUser) {
      // Check if user is associated with a company
      if (existingUser.companyId) {
        const userCompany = await Company.findByPk(existingUser.companyId);
        if (userCompany && userCompany.status === 'rejected') {
          // Clean up the rejected company and its users
          await User.destroy({ where: { companyId: userCompany.id } });
          await CompanySetting.destroy({ where: { companyId: userCompany.id } });
          await Company.destroy({ where: { id: userCompany.id } });
          existingUser = null;
        } else {
          return res.status(409).json({ message: 'Email address already registered.' });
        }
      } else {
        return res.status(409).json({ message: 'Email address already registered as an individual employee.' });
      }
    }

    // 2. Check if company name exists
    let existingCompany = await Company.findOne({ where: { name: companyName } });
    if (existingCompany) {
      if (existingCompany.status === 'rejected') {
        // Clean up the rejected company and its users
        await User.destroy({ where: { companyId: existingCompany.id } });
        await CompanySetting.destroy({ where: { companyId: existingCompany.id } });
        await Company.destroy({ where: { id: existingCompany.id } });
        existingCompany = null;
      } else {
        return res.status(409).json({ message: 'Company name already registered.' });
      }
    }

    // 3. Create the Company with pending status and isActive: false
    const company = await Company.create({
      name: companyName,
      status: 'pending',
      isActive: false
    });

    // 4. Initialize company settings
    await CompanySetting.create({
      companyId: company.id,
      checkInTime: '09:00:00',
      checkOutTime: '18:00:00',
      latitude: 0.0,
      longitude: 0.0,
      address: null,
      radius: 100.0
    });

    // 5. Create company admin user
    const hashedPassword = await bcrypt.hash(adminPassword, 10);
    const adminUser = await User.create({
      name: adminName,
      email: adminEmail,
      password: hashedPassword,
      role: 'company_admin',
      isActive: true, // User is active, but blocked by company pending status
      companyId: company.id
    });

    return res.status(201).json({
      message: 'Company registration request submitted successfully. Waiting for System Admin approval.',
      company,
      adminUser
    });
  } catch (error) {
    console.error('[Auth] Register company error:', error);
    return res.status(500).json({ message: 'Company registration failed', error: error.message });
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

    if (user.companyId) {
      const company = await Company.findByPk(user.companyId);
      if (company) {
        if (company.status === 'pending') {
          return res.status(403).json({ message: 'Your company registration is pending approval by the System Admin.' });
        }
        if (company.status === 'rejected') {
          return res.status(403).json({
            message: `Your company registration was rejected. Reason: ${company.rejectionReason || 'No reason specified'}. Please register again.`
          });
        }
      }
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

// Request OTP (Forgot Password)
const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ message: 'Email address is required' });
    }

    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(404).json({ message: 'Email address not registered' });
    }

    // Generate 4-digit OTP
    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const expiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    user.otpCode = otp;
    user.otpExpiresAt = expiry;
    await user.save();

    // Send email
    const emailSent = await sendOtpEmail({ email: user.email, name: user.name, otp });
    if (!emailSent.success) {
      return res.status(500).json({ message: 'Failed to send verification email' });
    }

    return res.json({ message: 'Verification code sent to your registered email address' });
  } catch (error) {
    console.error('[Auth] Forgot password error:', error);
    return res.status(500).json({ message: 'Forgot password request failed', error: error.message });
  }
};

// Verify OTP
const verifyOtp = async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) {
      return res.status(400).json({ message: 'Email and verification code are required' });
    }

    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Check OTP code and expiration
    if (String(user.otpCode) !== String(otp) || !user.otpExpiresAt || new Date(user.otpExpiresAt) < new Date()) {
      return res.status(400).json({ message: 'Invalid or expired verification code' });
    }

    // Generate a temporary reset token valid for 15 minutes
    const resetToken = jwt.sign(
      { id: user.id, purpose: 'reset-password' },
      process.env.JWT_SECRET || 'dev-secret',
      { expiresIn: '15m' }
    );

    return res.json({
      message: 'Email verified successfully',
      resetToken,
    });
  } catch (error) {
    console.error('[Auth] Verify OTP error:', error);
    return res.status(500).json({ message: 'Verification failed', error: error.message });
  }
};

// Reset Password
const resetPassword = async (req, res) => {
  try {
    const { resetToken, newPassword } = req.body;
    if (!resetToken || !newPassword) {
      return res.status(400).json({ message: 'Reset token and new password are required' });
    }

    // Verify resetToken
    let decoded;
    try {
      decoded = jwt.verify(resetToken, process.env.JWT_SECRET || 'dev-secret');
      if (decoded.purpose !== 'reset-password') {
        throw new Error('Invalid token purpose');
      }
    } catch (err) {
      return res.status(401).json({ message: 'Invalid or expired reset token' });
    }

    const user = await User.findByPk(decoded.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Hash and save new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    user.password = hashedPassword;
    user.otpCode = null;
    user.otpExpiresAt = null;
    await user.save();

    return res.json({ message: 'Password reset completed successfully' });
  } catch (error) {
    console.error('[Auth] Reset password error:', error);
    return res.status(500).json({ message: 'Password reset failed', error: error.message });
  }
};

const updateFcmToken = async (req, res) => {
  try {
    const userId = req.user.id;
    const { fcmToken } = req.body;
    await User.update({ fcmToken: fcmToken || null }, { where: { id: userId } });
    return res.json({ message: 'FCM token updated successfully' });
  } catch (error) {
    console.error('[Auth] Update FCM token error:', error);
    return res.status(500).json({ message: 'Failed to update FCM token', error: error.message });
  }
};

module.exports = {
  register,
  registerCompany,
  login,
  me,
  logout,
  refreshToken,
  changePassword,
  updateProfilePicture,
  deleteProfilePicture,
  forgotPassword,
  verifyOtp,
  resetPassword,
  updateFcmToken,
};

