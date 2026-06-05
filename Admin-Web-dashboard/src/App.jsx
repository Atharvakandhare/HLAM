import React, { useState, useEffect } from 'react';
import './App.css';

const API_BASE = 'https://intime.hirelyft.in/api';

const INDIAN_STATES_CITIES = {
  "Maharashtra": ["Mumbai", "Pune", "Nagpur", "Thane", "Nashik"],
  "Karnataka": ["Bengaluru", "Mysore", "Hubli", "Mangalore", "Belgaum"],
  "Delhi": ["New Delhi", "Dwarka", "Saket", "Rohini", "Vasant Kunj"],
  "Gujarat": ["Ahmedabad", "Surat", "Vadodara", "Rajkot", "Gandhinagar"],
  "Tamil Nadu": ["Chennai", "Coimbatore", "Madurai", "Trichy", "Salem"],
  "Telangana": ["Hyderabad", "Warangal", "Nizamabad", "Karimnagar", "Khammam"],
  "Uttar Pradesh": ["Lucknow", "Kanpur", "Noida", "Ghaziabad", "Agra"],
  "West Bengal": ["Kolkata", "Howrah", "Darjeeling", "Siliguri", "Durgapur"]
};

const DEPARTMENTS = ["IT", "HR", "Marketing", "Sales", "Operations", "Finance", "Support", "Other"];
const WORK_MODES = ["Work From Office", "Work From Home", "Remote Work"];
const WORK_TYPES = ["Work From Office", "Field Work", "Office + Field Work"];
const PREDEFINED_TEAMS = ["IT Team", "HR Team", "Marketing Team", "Sales Team", "Operations Team", "Finance Team", "Support Team"];

function App() {
  const [token, setToken] = useState(localStorage.getItem('admin_token') || '');
  const [user, setUser] = useState(null);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loginError, setLoginError] = useState('');

  // Active Tab
  const [activeTab, setActiveTab] = useState('dashboard');

  // Common data lists
  const [users, setUsers] = useState([]);
  const [stats, setStats] = useState({ totalPresent: 0, totalLate: 0, totalHalfDay: 0, totalAbsent: 0, attendanceRate: 0, totalUsers: 0 });
  const [companies, setCompanies] = useState([]);
  const [teams, setTeams] = useState([]);
  const [leaves, setLeaves] = useState([]);
  const [companySettings, setCompanySettings] = useState(null);

  // Marketing Tracker states
  const [marketingEmployees, setMarketingEmployees] = useState([]);
  const [selectedMarketingUser, setSelectedMarketingUser] = useState(null);
  const [marketingTrail, setMarketingTrail] = useState([]);
  const [selectedTrailPoint, setSelectedTrailPoint] = useState(null);

  // Modals state
  const [showCompanyModal, setShowCompanyModal] = useState(false);
  const [showTeamModal, setShowTeamModal] = useState(false);
  const [showUserModal, setShowUserModal] = useState(false);
  const [showCalendarModal, setShowCalendarModal] = useState(false);
  const [showLeaveModal, setShowLeaveModal] = useState(false);

  // Form states for Creation/Edit
  const [editingUser, setEditingUser] = useState(null);
  const [userForm, setUserForm] = useState({
    name: '', email: '', password: '', role: 'employee', department: 'IT',
    employeeId: '', dob: '', state: 'Maharashtra', city: 'Mumbai',
    workMode: 'Work From Office', workType: 'Work From Office', teamId: ''
  });

  const [companyForm, setCompanyForm] = useState({ name: '', adminName: '', adminEmail: '', adminPassword: '' });
  const [teamForm, setTeamForm] = useState({ type: 'IT Team', customName: '' });
  const [selectedLeave, setSelectedLeave] = useState(null);
  const [leaveComment, setLeaveComment] = useState('');

  // Calendar Modal details
  const [calendarUser, setCalendarUser] = useState(null);
  const [calendarRecords, setCalendarRecords] = useState([]);
  const [currentYear, setCurrentYear] = useState(new Date().getFullYear());
  const [currentMonth, setCurrentMonth] = useState(new Date().getMonth() + 1); // 1-indexed

  // Attendance Tab states
  const [attendanceRecords, setAttendanceRecords] = useState([]);
  const [attendanceDate, setAttendanceDate] = useState(new Date().toISOString().slice(0, 10));
  const [attendanceMood, setAttendanceMood] = useState('');
  const [attendanceEnergy, setAttendanceEnergy] = useState('');
  const [attendanceTeamView, setAttendanceTeamView] = useState(true);

  // Holidays Tab states
  const [holidays, setHolidays] = useState([]);
  const [parsedHolidays, setParsedHolidays] = useState([]);
  const [holidayForm, setHolidayForm] = useState({ name: '', date: '' });
  const [selectedHoliday, setSelectedHoliday] = useState(null);
  const [holidayExceptions, setHolidayExceptions] = useState([]);
  const [showExceptionsModal, setShowExceptionsModal] = useState(false);
  const [exceptionForm, setExceptionForm] = useState({ targetType: 'team', teamId: '', userId: '' });

  // Time & Date Header
  const [headerTime, setHeaderTime] = useState('');

  useEffect(() => {
    const timer = setInterval(() => {
      const now = new Date();
      setHeaderTime(now.toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' }));
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  // Fetch current user details if token exists
  useEffect(() => {
    if (token) {
      fetchMe();
    } else {
      setUser(null);
    }
  }, [token]);

  // Load active tab data
  useEffect(() => {
    if (user) {
      if (activeTab === 'dashboard') {
        fetchStats();
        fetchUsers();
      } else if (activeTab === 'companies' && user.role === 'system_admin') {
        fetchCompanies();
      } else if (activeTab === 'teams') {
        fetchTeams();
        fetchUsers();
      } else if (activeTab === 'users') {
        fetchUsers();
        fetchTeams();
      } else if (activeTab === 'leaves') {
        fetchLeaves();
      } else if (activeTab === 'settings') {
        fetchCompanySettings();
      } else if (activeTab === 'marketing') {
        fetchMarketingEmployees();
      } else if (activeTab === 'attendance') {
        fetchAttendanceTabRecords();
        fetchTeams();
      } else if (activeTab === 'holidays') {
        fetchHolidays();
        fetchTeams();
        fetchUsers();
      }
    }
  }, [activeTab, user, attendanceDate, attendanceMood, attendanceEnergy]);

  const fetchMe = async () => {
    try {
      const res = await fetch(`${API_BASE}/auth/me`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setUser(data);
        // Default system admin tab to dashboard
        if (data.role === 'system_admin') {
          setActiveTab('dashboard');
        }
      } else {
        handleSignOut();
      }
    } catch (err) {
      console.error(err);
      handleSignOut();
    }
  };

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoginError('');
    try {
      const res = await fetch(`${API_BASE}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      const data = await res.json();
      if (res.ok) {
        if (['system_admin', 'company_admin'].includes(data.user.role)) {
          localStorage.setItem('admin_token', data.token);
          setToken(data.token);
        } else {
          setLoginError('Access denied. Only system and company administrators are allowed.');
        }
      } else {
        setLoginError(data.message || 'Login failed. Please check credentials.');
      }
    } catch (err) {
      setLoginError('Server connection error. Please try again.');
    }
  };

  const handleSignOut = () => {
    localStorage.removeItem('admin_token');
    setToken('');
    setUser(null);
    setUsers([]);
    setCompanies([]);
    setTeams([]);
    setLeaves([]);
    setCompanySettings(null);
  };

  // API Call Helpers
  const fetchStats = async () => {
    try {
      const res = await fetch(`${API_BASE}/admin/attendance/stats`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setStats(data);
      }
    } catch (err) {
      console.error(err);
    }
  };

  const fetchUsers = async () => {
    try {
      const res = await fetch(`${API_BASE}/admin/users`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setUsers(data.users);
      }
    } catch (err) {
      console.error(err);
    }
  };

  const fetchCompanies = async () => {
    try {
      const res = await fetch(`${API_BASE}/admin/companies`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setCompanies(data.companies);
      }
    } catch (err) {
      console.error(err);
    }
  };

  const fetchTeams = async () => {
    try {
      const res = await fetch(`${API_BASE}/admin/teams`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setTeams(data.teams);
      }
    } catch (err) {
      console.error(err);
    }
  };

  const fetchLeaves = async () => {
    try {
      const res = await fetch(`${API_BASE}/leaves/admin`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setLeaves(data.leaves);
      }
    } catch (err) {
      console.error(err);
    }
  };

  const fetchCompanySettings = async () => {
    try {
      const res = await fetch(`${API_BASE}/admin/company-settings`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setCompanySettings(data.settings);
      }
    } catch (err) {
      console.error(err);
    }
  };

  const fetchAttendanceTabRecords = async () => {
    try {
      let query = `?date=${attendanceDate}`;
      if (attendanceMood) query += `&mood=${attendanceMood}`;
      if (attendanceEnergy) query += `&energyLevel=${attendanceEnergy}`;
      const res = await fetch(`${API_BASE}/attendance${query}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setAttendanceRecords(data.attendance || []);
      }
    } catch (err) {
      console.error(err);
    }
  };

  const fetchHolidays = async () => {
    try {
      const res = await fetch(`${API_BASE}/holidays`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setHolidays(data.holidays || []);
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleCreateHoliday = async (e) => {
    e.preventDefault();
    if (!holidayForm.name || !holidayForm.date) return;
    try {
      const res = await fetch(`${API_BASE}/holidays`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(holidayForm)
      });
      if (res.ok) {
        setHolidayForm({ name: '', date: '' });
        fetchHolidays();
        alert('Holiday created successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to create holiday');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleDeleteHoliday = async (id) => {
    if (!window.confirm('Are you sure you want to delete this holiday?')) return;
    try {
      const res = await fetch(`${API_BASE}/holidays/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        fetchHolidays();
        alert('Holiday deleted successfully!');
      } else {
        alert('Failed to delete holiday');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const downloadHolidayTemplate = () => {
    const csvContent = "Date,Holiday Name\n" +
      "2026-01-01,New Year's Day\n" +
      "2026-01-26,Republic Day\n" +
      "2026-08-15,Independence Day\n" +
      "2026-10-02,Mahatma Gandhi Jayanti\n" +
      "2026-12-25,Christmas Day\n";
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", "holidays_template.csv");
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleUploadHolidaySheet = async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const formData = new FormData();
    formData.append('sheet', file);

    try {
      const res = await fetch(`${API_BASE}/holidays/parse-sheet`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData
      });
      if (res.ok) {
        const data = await res.json();
        setParsedHolidays(data.parsed || []);
        alert(`Successfully parsed ${data.parsed?.length || 0} holiday dates! Please review and confirm below.`);
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to parse holiday sheet.');
      }
    } catch (err) {
      console.error(err);
      alert('Error uploading and parsing sheet.');
    }
  };

  const handleConfirmBulkHolidays = async () => {
    if (parsedHolidays.length === 0) return;
    try {
      const res = await fetch(`${API_BASE}/holidays/bulk`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ holidays: parsedHolidays })
      });
      if (res.ok) {
        alert('All parsed holidays saved successfully!');
        setParsedHolidays([]);
        fetchHolidays();
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to save bulk holidays.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const openExceptionsModal = (holiday) => {
    setSelectedHoliday(holiday);
    setHolidayExceptions([]);
    setExceptionForm({ targetType: 'team', teamId: '', userId: '' });
    setShowExceptionsModal(true);
    fetchExceptions(holiday.id);
  };

  const fetchExceptions = async (holidayId) => {
    try {
      const res = await fetch(`${API_BASE}/holidays/${holidayId}/exceptions`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setHolidayExceptions(data.exceptions || []);
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleAddException = async (e) => {
    e.preventDefault();
    const payload = {};
    if (exceptionForm.targetType === 'team') {
      if (!exceptionForm.teamId) return alert('Please select a team.');
      payload.teamId = parseInt(exceptionForm.teamId);
    } else {
      if (!exceptionForm.userId) return alert('Please select an employee.');
      payload.userId = parseInt(exceptionForm.userId);
    }

    try {
      const res = await fetch(`${API_BASE}/holidays/${selectedHoliday.id}/exceptions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });
      if (res.ok) {
        setExceptionForm({ targetType: 'team', teamId: '', userId: '' });
        fetchExceptions(selectedHoliday.id);
        alert('Holiday exception added successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to add exception');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleDeleteException = async (exceptionId) => {
    if (!window.confirm('Are you sure you want to remove this exception?')) return;
    try {
      const res = await fetch(`${API_BASE}/holidays/${selectedHoliday.id}/exceptions/${exceptionId}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        fetchExceptions(selectedHoliday.id);
        alert('Exception removed successfully.');
      } else {
        alert('Failed to remove exception.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const saveCompanySettings = async (e) => {
    e.preventDefault();
    try {
      const res = await fetch(`${API_BASE}/admin/company-settings`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(companySettings)
      });
      if (res.ok) {
        alert('Company settings updated successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to update settings');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleCreateCompany = async (e) => {
    e.preventDefault();
    try {
      const res = await fetch(`${API_BASE}/admin/companies`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(companyForm)
      });
      if (res.ok) {
        setShowCompanyModal(false);
        setCompanyForm({ name: '', adminName: '', adminEmail: '', adminPassword: '' });
        fetchCompanies();
        alert('Company & Admin created successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to create company');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleCreateTeam = async (e) => {
    e.preventDefault();
    const finalName = teamForm.type === 'Other' ? teamForm.customName : teamForm.type;
    if (!finalName) return alert('Team name is required.');
    try {
      const res = await fetch(`${API_BASE}/admin/teams`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ name: finalName })
      });
      if (res.ok) {
        setShowTeamModal(false);
        setTeamForm({ type: 'IT Team', customName: '' });
        fetchTeams();
        alert('Team created successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to create team');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleRenameTeam = async (id, newName) => {
    try {
      const res = await fetch(`${API_BASE}/admin/teams/${id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ name: newName })
      });
      if (res.ok) {
        fetchTeams();
        alert('Team renamed successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to rename team');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleDeleteTeam = async (id) => {
    if (!window.confirm('Are you sure you want to delete this team? All members will be unassigned.')) return;
    try {
      const res = await fetch(`${API_BASE}/admin/teams/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        fetchTeams();
        alert('Team deleted successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to delete team');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleAssignTeamRole = async (userId, teamId, roleName, targetRole) => {
    try {
      const payload = { teamId };
      if (targetRole) {
        payload.role = targetRole;
      }
      const res = await fetch(`${API_BASE}/admin/users/${userId}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });
      if (res.ok) {
        fetchTeams();
        fetchUsers();
        alert(`Team ${roleName} assigned successfully!`);
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to assign team role');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const openAddUserModal = () => {
    setEditingUser(null);
    setUserForm({
      name: '', email: '', password: '', role: 'employee', department: 'IT',
      employeeId: '', dob: '', state: 'Maharashtra', city: 'Mumbai',
      workMode: 'Work From Office', workType: 'Work From Office', teamId: ''
    });
    setShowUserModal(true);
  };

  const openEditUserModal = (u) => {
    setEditingUser(u);
    setUserForm({
      name: u.name,
      email: u.email,
      password: '',
      role: u.role,
      department: u.department || 'IT',
      employeeId: u.employeeId || '',
      dob: u.dob || '',
      state: u.state || 'Maharashtra',
      city: u.city || 'Mumbai',
      workMode: u.workMode || 'Work From Office',
      workType: u.workType || 'Work From Office',
      teamId: u.teamId || ''
    });
    setShowUserModal(true);
  };

  const handleSaveUser = async (e) => {
    e.preventDefault();
    const url = editingUser 
      ? `${API_BASE}/admin/users/${editingUser.id}` 
      : `${API_BASE}/admin/users`;
    const method = editingUser ? 'PUT' : 'POST';

    const payload = { ...userForm };
    if (editingUser && !payload.password) {
      delete payload.password; // Do not update password if left blank
    }

    try {
      const res = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });
      if (res.ok) {
        setShowUserModal(false);
        fetchUsers();
        alert(editingUser ? 'Employee updated successfully!' : 'Employee created successfully! Credentials sent via Email.');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to save employee');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleDeleteUser = async (id) => {
    if (!window.confirm('Are you sure you want to deactivate this user account?')) return;
    try {
      const res = await fetch(`${API_BASE}/admin/users/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        fetchUsers();
        alert('User deactivated successfully.');
      } else {
        alert('Failed to deactivate user.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleLeaveAction = async (approved) => {
    if (!selectedLeave) return;
    const status = approved ? 'approved' : 'rejected';
    try {
      const res = await fetch(`${API_BASE}/leaves/admin/${selectedLeave.id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ status, adminComment: leaveComment })
      });
      if (res.ok) {
        setShowLeaveModal(false);
        setSelectedLeave(null);
        setLeaveComment('');
        fetchLeaves();
        alert(`Leave request successfully ${status}!`);
      } else {
        alert('Failed to process leave request.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  // Calendar View Logic
  const openCalendarModal = async (u) => {
    setCalendarUser(u);
    setCurrentYear(new Date().getFullYear());
    setCurrentMonth(new Date().getMonth() + 1);
    setShowCalendarModal(true);
    fetchUserCalendar(u.id, new Date().getFullYear(), new Date().getMonth() + 1);
  };

  const fetchUserCalendar = async (userId, year, month) => {
    try {
      const res = await fetch(`${API_BASE}/attendance?userId=${userId}&month=${month}&year=${year}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setCalendarRecords(data.attendance || []);
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleCalendarNav = (direction) => {
    let nextMonth = currentMonth + direction;
    let nextYear = currentYear;

    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear += 1;
    } else if (nextMonth < 1) {
      nextMonth = 12;
      nextYear -= 1;
    }

    setCurrentMonth(nextMonth);
    setCurrentYear(nextYear);
    fetchUserCalendar(calendarUser.id, nextYear, nextMonth);
  };

  // Render Calendar Grid Helper
  const getDaysInMonth = (year, month) => new Date(year, month, 0).getDate();
  const getFirstDayOfMonth = (year, month) => new Date(year, month - 1, 1).getDay(); // 0 = Sun, 6 = Sat

  const renderCalendarCells = () => {
    const daysCount = getDaysInMonth(currentYear, currentMonth);
    const firstDay = getFirstDayOfMonth(currentYear, currentMonth);
    const cells = [];

    // Fill preceding blank slots
    for (let i = 0; i < firstDay; i++) {
      cells.push(<div key={`blank-${i}`} className="calendar-day-cell empty"></div>);
    }

    // Fill actual days
    for (let day = 1; day <= daysCount; day++) {
      const dateString = `${currentYear}-${String(currentMonth).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      const record = calendarRecords.find(r => r.date === dateString);
      const isToday = new Date().toISOString().slice(0, 10) === dateString;
      const dayOfWeek = new Date(currentYear, currentMonth - 1, day).getDay();
      const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;

      let cellClass = "calendar-day-cell current-month";
      if (isToday) cellClass += " today";
      if (isWeekend) cellClass += " holiday";

      let statusDot = null;
      if (record) {
        const moodEmoji = record.mood ? (record.mood === 'happy' ? ' 😊' : record.mood === 'sad' ? ' 😢' : record.mood === 'exhausted' ? ' 😩' : record.mood === 'angry' ? ' 😤' : ' 😐') : '';
        const tooltip = `${record.status.toUpperCase()} (${record.workingHours || ''})${moodEmoji ? ' | Mood:' + moodEmoji : ''}`;
        statusDot = <div className={`calendar-day-status-dot ${record.status}`} title={tooltip}></div>;
      } else if (isWeekend) {
        // Highlight weekends without check-in as default holiday (gray/yellow indicator)
      } else {
        // Check if date is in past
        const cellDate = new Date(currentYear, currentMonth - 1, day);
        if (cellDate < new Date()) {
          statusDot = <div className="calendar-day-status-dot absent" title="Absent"></div>;
        }
      }

      cells.push(
        <div key={`day-${day}`} className={cellClass}>
          <span className="calendar-day-number">{day}</span>
          {statusDot}
          {record && record.workingHours && (
            <span style={{ fontSize: '9px', color: 'var(--text-secondary)', alignSelf: 'center' }}>
              {record.workingHours}
            </span>
          )}
        </div>
      );
    }

    return cells;
  };

  // Marketing Trail Loading
  const fetchMarketingEmployees = async () => {
    try {
      const res = await fetch(`${API_BASE}/location/all-marketing`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setMarketingEmployees(data.employees || []);
        if (data.employees.length > 0 && !selectedMarketingUser) {
          selectMarketingEmployee(data.employees[0].user);
        }
      }
    } catch (err) {
      console.error(err);
    }
  };

  const selectMarketingEmployee = async (user) => {
    setSelectedMarketingUser(user);
    setMarketingTrail([]);
    setSelectedTrailPoint(null);
    try {
      const res = await fetch(`${API_BASE}/location/trail/${user.id}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setMarketingTrail(data.logs || []);
        if (data.logs.length > 0) {
          setSelectedTrailPoint(data.logs[data.logs.length - 1]); // default to latest log
        }
      }
    } catch (err) {
      console.error(err);
    }
  };

  if (!token) {
    return (
      <div className="login-wrapper">
        <div className="login-card">
          <div className="login-header">
            <h2>HireLyft Panel</h2>
            <p>Enter your administrator credentials to login.</p>
          </div>
          {loginError && <div className="error-message">{loginError}</div>}
          <form onSubmit={handleLogin}>
            <div className="form-group">
              <label>Email Address</label>
              <input 
                type="email" 
                placeholder="admin@hirelyft.in" 
                value={email} 
                onChange={(e) => setEmail(e.target.value)} 
                required 
              />
            </div>
            <div className="form-group">
              <label>Password</label>
              <input 
                type="password" 
                placeholder="••••••••" 
                value={password} 
                onChange={(e) => setPassword(e.target.value)} 
                required 
              />
            </div>
            <button type="submit" className="btn-primary">Sign In</button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="app-container">
      {/* Sidebar */}
      <div className="sidebar">
        <div className="sidebar-logo">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect x="2" y="2" width="20" height="20" rx="6" fill="url(#logoGrad)" />
            <circle cx="12" cy="12" r="5" fill="#ffffff" />
            <defs>
              <linearGradient id="logoGrad" x1="2" y1="2" x2="22" y2="22" gradientUnits="userSpaceOnUse">
                <stop stopColor="#38BDF8" />
                <stop offset="1" stopColor="#818CF8" />
              </linearGradient>
            </defs>
          </svg>
          <h1>HireLyft App</h1>
        </div>
        
        <ul className="sidebar-menu">
          <li className={`sidebar-item ${activeTab === 'dashboard' ? 'active' : ''}`} onClick={() => setActiveTab('dashboard')}>
            <span>📊 Dashboard Overview</span>
          </li>
          
          <li className={`sidebar-item ${activeTab === 'attendance' ? 'active' : ''}`} onClick={() => setActiveTab('attendance')}>
            <span>📅 Attendance Journal</span>
          </li>

          {user?.role === 'system_admin' && (
            <li className={`sidebar-item ${activeTab === 'companies' ? 'active' : ''}`} onClick={() => setActiveTab('companies')}>
              <span>🏢 Companies Admin</span>
            </li>
          )}
          
          {['system_admin', 'company_admin'].includes(user?.role) && (
            <>
              <li className={`sidebar-item ${activeTab === 'teams' ? 'active' : ''}`} onClick={() => setActiveTab('teams')}>
                <span>👥 Teams Admin</span>
              </li>
              <li className={`sidebar-item ${activeTab === 'holidays' ? 'active' : ''}`} onClick={() => setActiveTab('holidays')}>
                <span>🗓️ Company Holidays</span>
              </li>
              <li className={`sidebar-item ${activeTab === 'settings' ? 'active' : ''}`} onClick={() => setActiveTab('settings')}>
                <span>⚙️ Geofencing & Times</span>
              </li>
            </>
          )}

          <li className={`sidebar-item ${activeTab === 'users' ? 'active' : ''}`} onClick={() => setActiveTab('users')}>
            <span>👤 Employees</span>
          </li>

          <li className={`sidebar-item ${activeTab === 'leaves' ? 'active' : ''}`} onClick={() => setActiveTab('leaves')}>
            <span>📋 Leave Requests</span>
          </li>

          {['system_admin', 'company_admin'].includes(user?.role) && (
            <li className={`sidebar-item ${activeTab === 'marketing' ? 'active' : ''}`} onClick={() => setActiveTab('marketing')}>
              <span>📍 Marketing Tracker</span>
            </li>
          )}
        </ul>

        {user && (
          <div className="sidebar-user">
            <img 
              src={user.profilePicture ? `https://intime.hirelyft.in${user.profilePicture}` : "https://avatar.iran.liara.run/public/boy"} 
              alt="Avatar" 
              className="user-avatar" 
            />
            <div className="user-details">
              <span className="user-name">{user.name}</span>
              <span className="user-role">{user.role.replace('_', ' ')}</span>
            </div>
          </div>
        )}
      </div>

      {/* Main Container */}
      <div className="main-content">
        <div className="main-header">
          <div className="page-title">
            <h2>{activeTab.toUpperCase().replace('_', ' ')}</h2>
          </div>
          <div className="header-actions">
            <span style={{ fontSize: '14px', color: 'var(--text-secondary)', fontWeight: 600 }}>{headerTime}</span>
            <button className="btn-signout" onClick={handleSignOut}>Sign Out</button>
          </div>
        </div>

        <div className="content-body">
          {/* DASHBOARD TAB */}
          {activeTab === 'dashboard' && (
            <>
              <div className="stats-grid">
                <div className="stat-card">
                  <div className="stat-icon green">✔️</div>
                  <div className="stat-info">
                    <span className="stat-value">{stats.totalPresent}</span>
                    <span className="stat-label">Present Users</span>
                  </div>
                </div>
                <div className="stat-card">
                  <div className="stat-icon orange">⏳</div>
                  <div className="stat-info">
                    <span className="stat-value">{stats.totalLate}</span>
                    <span className="stat-label">Late Logins</span>
                  </div>
                </div>
                <div className="stat-card">
                  <div className="stat-icon orange">🌓</div>
                  <div className="stat-info">
                    <span className="stat-value">{stats.totalHalfDay || 0}</span>
                    <span className="stat-label">Half Days</span>
                  </div>
                </div>
                <div className="stat-card">
                  <div className="stat-icon red">❌</div>
                  <div className="stat-info">
                    <span className="stat-value">{stats.totalAbsent}</span>
                    <span className="stat-label">Absent Days</span>
                  </div>
                </div>
                <div className="stat-card">
                  <div className="stat-icon blue">📈</div>
                  <div className="stat-info">
                    <span className="stat-value">{stats.attendanceRate}%</span>
                    <span className="stat-label">Attendance Rate</span>
                  </div>
                </div>
              </div>

              <div className="section-box">
                <div className="section-header">
                  <h3>Recent Employee Registrations</h3>
                  <button className="btn-action" onClick={() => setActiveTab('users')}>Manage Employees</button>
                </div>
                <div className="table-wrapper">
                  <table className="custom-table">
                    <thead>
                      <tr>
                        <th>Employee ID</th>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Role</th>
                        <th>Department</th>
                        <th>Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {users.slice(0, 5).map(u => (
                        <tr key={u.id}>
                          <td>{u.employeeId || 'N/A'}</td>
                          <td>{u.name}</td>
                          <td>{u.email}</td>
                          <td><span className={`badge ${u.role}`}>{u.role.replace('_', ' ')}</span></td>
                          <td>{u.department || 'N/A'}</td>
                          <td><span className={`badge ${u.isActive ? 'present' : 'absent'}`}>{u.isActive ? 'Active' : 'Inactive'}</span></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </>
          )}

          {/* ATTENDANCE RECORDS TAB */}
          {activeTab === 'attendance' && (
            <div className="section-box">
              <div className="section-header" style={{ marginBottom: '20px' }}>
                <h3>Employee Attendance Journal</h3>
                <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '600', cursor: 'pointer' }}>
                    <input 
                      type="checkbox" 
                      checked={attendanceTeamView} 
                      onChange={e => setAttendanceTeamView(e.target.checked)} 
                    />
                    Group by Teams
                  </label>
                </div>
              </div>

              {/* Filters Bar */}
              <div className="filters-container" style={{ display: 'flex', gap: '16px', flexWrap: 'wrap', padding: '16px', backgroundColor: 'var(--bg-secondary)', borderRadius: '12px', marginBottom: '20px', border: '1px solid var(--card-border)' }}>
                <div className="form-group" style={{ margin: 0, flex: 1, minWidth: '150px' }}>
                  <label style={{ fontSize: '11px', fontWeight: 'bold', color: 'var(--text-secondary)' }}>DATE</label>
                  <input 
                    type="date" 
                    value={attendanceDate} 
                    onChange={e => setAttendanceDate(e.target.value)} 
                    style={{ padding: '8px', borderRadius: '8px', border: '1px solid var(--card-border)' }}
                  />
                </div>
                <div className="form-group" style={{ margin: 0, flex: 1, minWidth: '150px' }}>
                  <label style={{ fontSize: '11px', fontWeight: 'bold', color: 'var(--text-secondary)' }}>FILTER BY MOOD</label>
                  <select 
                    value={attendanceMood} 
                    onChange={e => setAttendanceMood(e.target.value)}
                    style={{ padding: '8px', borderRadius: '8px', border: '1px solid var(--card-border)' }}
                  >
                    <option value="">All Moods</option>
                    <option value="happy">😊 Happy</option>
                    <option value="sad">😢 Sad</option>
                    <option value="exhausted">😩 Exhausted</option>
                    <option value="angry">😤 Angry</option>
                  </select>
                </div>
                <div className="form-group" style={{ margin: 0, flex: 1, minWidth: '150px' }}>
                  <label style={{ fontSize: '11px', fontWeight: 'bold', color: 'var(--text-secondary)' }}>FILTER BY ENERGY</label>
                  <select 
                    value={attendanceEnergy} 
                    onChange={e => setAttendanceEnergy(e.target.value)}
                    style={{ padding: '8px', borderRadius: '8px', border: '1px solid var(--card-border)' }}
                  >
                    <option value="">All Energy Levels</option>
                    <option value="low">🔋 Low</option>
                    <option value="medium">🔋🔋 Medium</option>
                    <option value="high">🔋🔋🔋 High</option>
                  </select>
                </div>
              </div>

              {attendanceRecords.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
                  No attendance records found matching filters for this date.
                </div>
              ) : attendanceTeamView ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                  {(() => {
                    // Group records by team
                    const teamGroups = {};
                    teams.forEach(t => {
                      teamGroups[t.id] = {
                        teamName: t.name,
                        managerName: t.manager?.name || 'No Manager Assigned',
                        tlName: t.teamLeader?.name || 'No Team Leader Assigned',
                        records: []
                      };
                    });
                    teamGroups['unassigned'] = {
                      teamName: 'Unassigned Employees (No Team)',
                      managerName: 'N/A',
                      tlName: 'N/A',
                      records: []
                    };

                    attendanceRecords.forEach(rec => {
                      const userTeamId = rec.user?.teamId;
                      if (userTeamId && teamGroups[userTeamId]) {
                        teamGroups[userTeamId].records.push(rec);
                      } else {
                        teamGroups['unassigned'].records.push(rec);
                      }
                    });

                    return Object.entries(teamGroups)
                      .filter(([_, group]) => group.records.length > 0)
                      .map(([id, group]) => (
                        <details key={id} className="team-collapse-card" open style={{ backgroundColor: 'white', border: '1px solid var(--card-border)', borderRadius: '12px', padding: '16px' }}>
                          <summary style={{ cursor: 'pointer', fontWeight: 'bold', fontSize: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <div>
                              <span>👥 {group.teamName}</span>
                              <span style={{ fontSize: '12px', color: 'var(--text-secondary)', marginLeft: '12px', fontWeight: 'normal' }}>
                                Manager: <strong>{group.managerName}</strong> | TL: <strong>{group.tlName}</strong>
                              </span>
                            </div>
                            <span className="badge employee">{group.records.length} records</span>
                          </summary>
                          <div style={{ marginTop: '16px' }}>
                            <AttendanceTable records={group.records} />
                          </div>
                        </details>
                      ));
                  })()}
                </div>
              ) : (
                <AttendanceTable records={attendanceRecords} />
              )}
            </div>
          )}

          {/* COMPANY HOLIDAYS TAB */}
          {activeTab === 'holidays' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
              <div style={{ display: 'flex', gap: '20px', flexWrap: 'wrap' }}>
                {/* Left Form: Manual Add */}
                <div className="section-box" style={{ flex: 1, minWidth: '320px' }}>
                  <div className="section-header">
                    <h3>Manual Holiday Addition</h3>
                  </div>
                  <form onSubmit={handleCreateHoliday}>
                    <div className="form-group">
                      <label>Holiday Name / Label</label>
                      <input 
                        type="text" 
                        placeholder="E.g. Diwali Festival" 
                        value={holidayForm.name} 
                        onChange={e => setHolidayForm({ ...holidayForm, name: e.target.value })} 
                        required 
                      />
                    </div>
                    <div className="form-group">
                      <label>Holiday Date</label>
                      <input 
                        type="date" 
                        value={holidayForm.date} 
                        onChange={e => setHolidayForm({ ...holidayForm, date: e.target.value })} 
                        required 
                      />
                    </div>
                    <button type="submit" className="btn-primary">Add Holiday</button>
                  </form>
                </div>

                {/* Right Form: Bulk Upload */}
                <div className="section-box" style={{ flex: 1.5, minWidth: '320px' }}>
                  <div className="section-header">
                    <h3>Bulk Upload Holiday Sheet</h3>
                  </div>
                  <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '16px' }}>
                    Upload a CSV or Excel (.xlsx) file with a list of dates. The system will parse valid holiday dates for bulk configuration.
                  </p>
                  <div className="form-group" style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <label style={{ margin: 0 }}>Select CSV/Excel Sheet</label>
                      <button 
                        type="button" 
                        onClick={downloadHolidayTemplate}
                        style={{
                          background: 'none',
                          border: 'none',
                          color: '#4F46E5',
                          cursor: 'pointer',
                          fontSize: '12px',
                          fontWeight: '600',
                          padding: '0',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px'
                        }}
                      >
                        📥 Download Template
                      </button>
                    </div>
                    <input 
                      type="file" 
                      accept=".csv, .xlsx, .xls" 
                      onChange={handleUploadHolidaySheet} 
                      style={{ padding: '8px', border: '1px dashed var(--card-border)', borderRadius: '8px', width: '100%', cursor: 'pointer' }}
                    />
                  </div>

                  {parsedHolidays.length > 0 && (
                    <div style={{ marginTop: '20px', borderTop: '1px solid var(--card-border)', paddingTop: '16px' }}>
                      <h4 style={{ marginBottom: '12px' }}>Preview Parsed Dates ({parsedHolidays.length})</h4>
                      <div className="table-wrapper" style={{ maxHeight: '150px', overflowY: 'auto' }}>
                        <table className="custom-table" style={{ fontSize: '12px' }}>
                          <thead>
                            <tr>
                              <th>Date</th>
                              <th>Parsed Name</th>
                            </tr>
                          </thead>
                          <tbody>
                            {parsedHolidays.map((ph, idx) => (
                              <tr key={idx}>
                                <td><strong>{ph.date}</strong></td>
                                <td>{ph.name}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                      <div style={{ display: 'flex', gap: '10px', marginTop: '14px' }}>
                        <button className="btn-cancel" onClick={() => setParsedHolidays([])}>Clear Preview</button>
                        <button className="btn-primary" onClick={handleConfirmBulkHolidays} style={{ width: 'auto' }}>Confirm & Bulk Save</button>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* Holidays Directory List */}
              <div className="section-box">
                <div className="section-header">
                  <h3>Holidays Directory</h3>
                </div>
                <div className="table-wrapper">
                  <table className="custom-table">
                    <thead>
                      <tr>
                        <th>Date</th>
                        <th>Holiday Name</th>
                        <th>Exceptions Active</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {holidays.length === 0 ? (
                        <tr>
                          <td colSpan="4" style={{ textAlign: 'center', color: 'var(--text-secondary)' }}>No corporate holidays set yet.</td>
                        </tr>
                      ) : (
                        holidays.map(h => (
                          <tr key={h.id}>
                            <td><strong>{h.date}</strong></td>
                            <td>{h.name}</td>
                            <td>
                              <span className="badge company_admin" style={{ cursor: 'pointer', fontSize: '11px', textTransform: 'none' }} onClick={() => openExceptionsModal(h)}>
                                🛡️ Manage Exceptions ({h.exceptions?.length || 0})
                              </span>
                            </td>
                            <td>
                              <button className="btn-secondary-action" style={{ padding: '6px 12px', color: 'var(--color-danger)' }} onClick={() => handleDeleteHoliday(h.id)}>
                                🗑️ Delete
                              </button>
                            </td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {/* COMPANIES TAB */}
          {activeTab === 'companies' && (
            <div className="section-box">
              <div className="section-header">
                <h3>Registered Companies</h3>
                <button className="btn-action" onClick={() => setShowCompanyModal(true)}>Add New Company</button>
              </div>
              <div className="table-wrapper">
                <table className="custom-table">
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Company Name</th>
                      <th>Company Admin(s)</th>
                      <th>Teams</th>
                      <th>Managers</th>
                      <th>Team Leaders</th>
                      <th>Employees</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {companies.map(c => (
                      <tr key={c.id}>
                        <td>{c.id}</td>
                        <td><strong>{c.name}</strong><br/><span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>{new Date(c.createdAt).toLocaleDateString()}</span></td>
                        <td>
                          {c.admins && c.admins.length > 0 ? (
                            c.admins.map(admin => (
                              <div key={admin.id} style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
                                <img
                                  src={admin.profilePicture ? `https://intime.hirelyft.in${admin.profilePicture}` : "https://avatar.iran.liara.run/public/boy"}
                                  alt=""
                                  style={{ width: '22px', height: '22px', borderRadius: '50%' }}
                                />
                                <div>
                                  <div style={{ fontWeight: '600', fontSize: '12px' }}>{admin.name}</div>
                                  <div style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>{admin.email}</div>
                                </div>
                              </div>
                            ))
                          ) : (
                            <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>No admin assigned</span>
                          )}
                        </td>
                        <td><span className="badge company_admin" style={{ fontSize: '12px' }}>{c.teamsCount ?? 0}</span></td>
                        <td><span className="badge manager" style={{ fontSize: '12px' }}>{c.managersCount ?? 0}</span></td>
                        <td><span className="badge team_leader" style={{ fontSize: '12px' }}>{c.teamLeadersCount ?? 0}</span></td>
                        <td><span className="badge employee" style={{ fontSize: '12px' }}>{c.employeesCount ?? 0}</span></td>
                        <td><span className={`badge ${c.isActive ? 'present' : 'absent'}`}>{c.isActive ? 'Active' : 'Inactive'}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* TEAMS TAB */}
          {activeTab === 'teams' && (
            <div className="section-box">
              <div className="section-header">
                <h3>Company Teams</h3>
                <button className="btn-action" onClick={() => setShowTeamModal(true)}>Add New Team</button>
              </div>
              <div className="table-wrapper">
                <table className="custom-table">
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Team Name</th>
                      <th>Assigned Manager</th>
                      <th>Assigned Team Leader</th>
                      <th>Active Members Count</th>
                      <th>Created At</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {teams.map(t => {
                      const assignableList = users.filter(u => ['manager', 'team_leader', 'employee'].includes(u.role) && u.isActive);

                      return (
                        <tr key={t.id}>
                          <td>{t.id}</td>
                          <td><strong>{t.name}</strong></td>
                          <td>
                            <select
                              value={t.manager?.id || ''}
                              onChange={(e) => {
                                const val = e.target.value;
                                if (val) {
                                  handleAssignTeamRole(val, t.id, 'Manager', 'manager');
                                } else if (t.manager?.id) {
                                  handleAssignTeamRole(t.manager.id, null, 'Manager');
                                }
                              }}
                              style={{ padding: '6px', borderRadius: '6px', border: '1px solid var(--card-border)', backgroundColor: 'var(--bg-secondary)', color: 'var(--text-primary)' }}
                            >
                              <option value="">-- No Manager --</option>
                              {assignableList.map(m => (
                                <option key={m.id} value={m.id}>
                                  {m.name} ({m.email})
                                </option>
                              ))}
                            </select>
                          </td>
                          <td>
                            <select
                              value={t.teamLeader?.id || ''}
                              onChange={(e) => {
                                const val = e.target.value;
                                if (val) {
                                  handleAssignTeamRole(val, t.id, 'Team Leader', 'team_leader');
                                } else if (t.teamLeader?.id) {
                                  handleAssignTeamRole(t.teamLeader.id, null, 'Team Leader');
                                }
                              }}
                              style={{ padding: '6px', borderRadius: '6px', border: '1px solid var(--card-border)', backgroundColor: 'var(--bg-secondary)', color: 'var(--text-primary)' }}
                            >
                              <option value="">-- No Team Leader --</option>
                              {assignableList.map(tl => (
                                <option key={tl.id} value={tl.id}>
                                  {tl.name} ({tl.email})
                                </option>
                              ))}
                            </select>
                          </td>
                          <td>
                            <span className="badge employee" style={{ fontSize: '13px' }}>{t.membersCount ?? 0} members</span>
                          </td>
                          <td>{new Date(t.createdAt).toLocaleDateString()}</td>
                          <td>
                            <div style={{ display: 'flex', gap: '8px' }}>
                              <button className="btn-secondary-action" style={{ padding: '6px 10px', fontSize: '12px' }} onClick={() => {
                                const newName = prompt('Enter new team name:', t.name);
                                if (newName && newName.trim()) handleRenameTeam(t.id, newName.trim());
                              }}>✏️ Rename</button>
                              <button className="btn-secondary-action" style={{ padding: '6px 10px', fontSize: '12px', color: 'var(--color-danger)' }} onClick={() => handleDeleteTeam(t.id)}>🗑️ Delete</button>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* GEOFENCING & TIMES SETTINGS TAB */}
          {activeTab === 'settings' && companySettings && (
            <div className="section-box" style={{ maxWidth: '600px' }}>
              <div className="section-header">
                <h3>Geofencing & Timing Controls</h3>
              </div>
              <form onSubmit={saveCompanySettings}>
                <div className="form-row">
                  <div className="form-group">
                    <label>Check-In Scheduled Time</label>
                    <input 
                      type="time" 
                      value={companySettings.checkInTime ? companySettings.checkInTime.slice(0, 5) : "09:00"} 
                      onChange={(e) => setCompanySettings({ ...companySettings, checkInTime: e.target.value + ":00" })} 
                      required 
                    />
                  </div>
                  <div className="form-group">
                    <label>Check-Out Scheduled Time</label>
                    <input 
                      type="time" 
                      value={companySettings.checkOutTime ? companySettings.checkOutTime.slice(0, 5) : "18:00"} 
                      onChange={(e) => setCompanySettings({ ...companySettings, checkOutTime: e.target.value + ":00" })} 
                      required 
                    />
                  </div>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label>Latitude Coordinates</label>
                    <input 
                      type="number" 
                      step="any" 
                      value={companySettings.latitude} 
                      onChange={(e) => setCompanySettings({ ...companySettings, latitude: e.target.value })} 
                      required 
                    />
                  </div>
                  <div className="form-group">
                    <label>Longitude Coordinates</label>
                    <input 
                      type="number" 
                      step="any" 
                      value={companySettings.longitude} 
                      onChange={(e) => setCompanySettings({ ...companySettings, longitude: e.target.value })} 
                      required 
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label>Geofence Radius (Meters)</label>
                  <input 
                    type="number" 
                    value={companySettings.radius} 
                    onChange={(e) => setCompanySettings({ ...companySettings, radius: e.target.value })} 
                    required 
                  />
                </div>

                <div className="form-group">
                  <label>Office Reference Address</label>
                  <textarea 
                    value={companySettings.address || ''} 
                    onChange={(e) => setCompanySettings({ ...companySettings, address: e.target.value })} 
                    rows="3" 
                  />
                </div>

                <button type="submit" className="btn-primary">Save Settings</button>
              </form>
            </div>
          )}

          {/* EMPLOYEES TAB */}
          {activeTab === 'users' && (
            <div className="section-box">
              <div className="section-header">
                <h3>Employee Directory</h3>
                <button className="btn-action" onClick={openAddUserModal}>Add Employee</button>
              </div>
              <div className="table-wrapper">
                <table className="custom-table">
                  <thead>
                    <tr>
                      <th>Employee ID</th>
                      <th>Name</th>
                      <th>Email</th>
                      <th>Role</th>
                      <th>Department</th>
                      <th>State / City</th>
                      <th>Work Mode</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {users.map(u => (
                      <tr key={u.id}>
                        <td>{u.employeeId || 'N/A'}</td>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                            <img 
                              src={u.profilePicture ? `https://intime.hirelyft.in${u.profilePicture}` : "https://avatar.iran.liara.run/public/boy"} 
                              alt="" 
                              style={{ width: '30px', height: '30px', borderRadius: '50%' }} 
                            />
                            <strong>{u.name}</strong>
                          </div>
                        </td>
                        <td>{u.email}</td>
                        <td><span className={`badge ${u.role}`}>{u.role.replace('_', ' ')}</span></td>
                        <td>
                          {u.department || 'N/A'}
                          {u.workType && <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>({u.workType})</div>}
                        </td>
                        <td>{u.state ? `${u.state}, ${u.city}` : 'N/A'}</td>
                        <td><span style={{ fontSize: '12px', color: 'var(--color-primary)' }}>{u.workMode}</span></td>
                        <td>
                          <div style={{ display: 'flex', gap: '8px' }}>
                            <button className="btn-secondary-action" style={{ padding: '6px 10px', fontSize: '12px' }} onClick={() => openCalendarModal(u)}>📅 Calendar</button>
                            <button className="btn-secondary-action" style={{ padding: '6px 10px', fontSize: '12px' }} onClick={() => openEditUserModal(u)}>✏️ Edit</button>
                            <button className="btn-secondary-action" style={{ padding: '6px 10px', fontSize: '12px', color: 'var(--color-danger)' }} onClick={() => handleDeleteUser(u.id)}>🗑️ Deactivate</button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* LEAVE REQUESTS TAB */}
          {activeTab === 'leaves' && (
            <div className="section-box">
              <div className="section-header">
                <h3>Leave Applications</h3>
              </div>
              <div className="table-wrapper">
                <table className="custom-table">
                  <thead>
                    <tr>
                      <th>Employee</th>
                      <th>Role</th>
                      <th>Start Date</th>
                      <th>End Date</th>
                      <th>Reason</th>
                      <th>Status</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {leaves.map(l => (
                      <tr key={l.id}>
                        <td><strong>{l.user?.name}</strong><br/><span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>{l.user?.email}</span></td>
                        <td><span className={`badge ${l.user?.role}`}>{l.user?.role.replace('_', ' ')}</span></td>
                        <td>{l.startDate}</td>
                        <td>{l.endDate}</td>
                        <td>{l.reason}</td>
                        <td><span className={`badge ${l.status}`}>{l.status}</span></td>
                        <td>
                          {l.status === 'pending' ? (
                            <button className="btn-action" style={{ padding: '6px 12px', fontSize: '12px' }} onClick={() => { setSelectedLeave(l); setShowLeaveModal(true); }}>Review</button>
                          ) : (
                            <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Processed</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* MARKETING TRACKER TAB */}
          {activeTab === 'marketing' && (
            <div className="marketing-trail-wrapper">
              <div className="marketing-sidebar">
                <div className="section-box" style={{ padding: '20px' }}>
                  <h4 style={{ marginBottom: '14px' }}>Field Marketing Agents</h4>
                  <div className="marketing-user-list">
                    {marketingEmployees.map(emp => (
                      <div 
                        key={emp.user.id} 
                        className={`marketing-user-card ${selectedMarketingUser?.id === emp.user.id ? 'active' : ''}`}
                        onClick={() => selectMarketingEmployee(emp.user)}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                          <img 
                            src={emp.user.profilePicture ? `https://intime.hirelyft.in${emp.user.profilePicture}` : "https://avatar.iran.liara.run/public/boy"} 
                            alt="" 
                            style={{ width: '32px', height: '32px', borderRadius: '50%' }} 
                          />
                          <div>
                            <div style={{ fontWeight: '700', fontSize: '14px' }}>{emp.user.name}</div>
                            <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Type: {emp.user.workType || 'Field Work'}</div>
                            {emp.isCurrentlyActive ? (
                              <span style={{ color: 'var(--color-success)', fontSize: '10px', fontWeight: 'bold' }}>● ONLINE (Checked-In)</span>
                            ) : (
                              <span style={{ color: 'var(--text-muted)', fontSize: '10px' }}>OFFLINE</span>
                            )}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                {selectedMarketingUser && (
                  <div className="section-box" style={{ padding: '20px' }}>
                    <h4 style={{ marginBottom: '14px' }}>Today's Location Logs</h4>
                    <div className="marketing-trail-logs">
                      {marketingTrail.length === 0 ? (
                        <div style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>No logs recorded today.</div>
                      ) : (
                        marketingTrail.map(log => (
                          <div 
                            key={log.id} 
                            className={`trail-log-item ${selectedTrailPoint?.id === log.id ? 'active' : ''}`}
                            onClick={() => setSelectedTrailPoint(log)}
                            style={{ cursor: 'pointer', border: selectedTrailPoint?.id === log.id ? '1px solid var(--color-primary)' : '1px solid var(--card-border)' }}
                          >
                            <span className="trail-log-time">{new Date(log.recordedAt).toLocaleTimeString()}</span>
                            <span className="trail-log-address">{log.address || `${log.latitude}, ${log.longitude}`}</span>
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                )}
              </div>

              <div className="marketing-map-panel">
                <div className="section-box" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
                  <div className="section-header" style={{ marginBottom: '14px' }}>
                    <h3>Live Coordinate Tracking</h3>
                    {selectedTrailPoint && (
                      <span style={{ fontSize: '13px', color: 'var(--color-primary)', fontWeight: 'bold' }}>
                        Pinpoint: {new Date(selectedTrailPoint.recordedAt).toLocaleTimeString()}
                      </span>
                    )}
                  </div>

                  {selectedTrailPoint ? (
                    <div style={{ flexGrow: 1, display: 'flex', flexDirection: 'column', gap: '14px' }}>
                      <iframe 
                        width="100%" 
                        height="420" 
                        src={`https://maps.google.com/maps?q=${selectedTrailPoint.latitude},${selectedTrailPoint.longitude}&t=&z=15&ie=UTF8&iwloc=&output=embed`} 
                        frameBorder="0" 
                        style={{ border: 0, borderRadius: '12px', flexGrow: 1 }} 
                        allowFullScreen
                      ></iframe>
                      <div style={{ padding: '14px', backgroundColor: 'var(--bg-secondary)', borderRadius: '12px', border: '1px solid var(--card-border)' }}>
                        <strong>Logged Coordinates:</strong> {selectedTrailPoint.latitude}, {selectedTrailPoint.longitude}<br/>
                        <strong>Resolved GPS Address:</strong> {selectedTrailPoint.address || 'Address lookup skipped'}
                      </div>
                    </div>
                  ) : (
                    <div style={{ height: '400px', display: 'flex', justifyContent: 'center', alignItems: 'center', backgroundColor: 'var(--bg-secondary)', borderRadius: '12px', color: 'var(--text-secondary)' }}>
                      Select a marketing agent and coordinate log point to view on map.
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* MODALS */}
      
      {/* COMPANY CREATION MODAL */}
      {showCompanyModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3>Create Corporate Account</h3>
              <button className="modal-close" onClick={() => setShowCompanyModal(false)}>×</button>
            </div>
            <form onSubmit={handleCreateCompany}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Company / Corporation Name</label>
                  <input 
                    type="text" 
                    placeholder="E.g. LyftLabs India" 
                    value={companyForm.name} 
                    onChange={(e) => setCompanyForm({ ...companyForm, name: e.target.value })} 
                    required 
                  />
                </div>
                <div style={{ borderTop: '1px solid var(--card-border)', marginTop: '20px', paddingTop: '20px' }}>
                  <h4 style={{ marginBottom: '14px', fontSize: '14px', color: 'var(--color-primary)' }}>🔑 Initial Admin User Details</h4>
                  <div className="form-group">
                    <label>Admin Representative Name</label>
                    <input 
                      type="text" 
                      placeholder="E.g. Rajesh Kumar" 
                      value={companyForm.adminName} 
                      onChange={(e) => setCompanyForm({ ...companyForm, adminName: e.target.value })} 
                      required 
                    />
                  </div>
                  <div className="form-group">
                    <label>Corporate Email Address</label>
                    <input 
                      type="email" 
                      placeholder="rajesh.kumar@lyftlabs.in" 
                      value={companyForm.adminEmail} 
                      onChange={(e) => setCompanyForm({ ...companyForm, adminEmail: e.target.value })} 
                      required 
                    />
                  </div>
                  <div className="form-group">
                    <label>Set Secure Password</label>
                    <input 
                      type="password" 
                      placeholder="••••••••" 
                      value={companyForm.adminPassword} 
                      onChange={(e) => setCompanyForm({ ...companyForm, adminPassword: e.target.value })} 
                      required 
                    />
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn-cancel" onClick={() => setShowCompanyModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" style={{ width: 'auto' }}>Create Corporation</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* TEAM CREATION MODAL */}
      {showTeamModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '440px' }}>
            <div className="modal-header">
              <h3>Create Department Team</h3>
              <button className="modal-close" onClick={() => setShowTeamModal(false)}>×</button>
            </div>
            <form onSubmit={handleCreateTeam}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Select Team Template</label>
                  <select 
                    value={teamForm.type} 
                    onChange={(e) => setTeamForm({ ...teamForm, type: e.target.value })}
                  >
                    {PREDEFINED_TEAMS.map(team => (
                      <option key={team} value={team}>{team}</option>
                    ))}
                    <option value="Other">Other (Custom Name)</option>
                  </select>
                </div>
                {teamForm.type === 'Other' && (
                  <div className="form-group">
                    <label>Custom Team Name</label>
                    <input 
                      type="text" 
                      placeholder="E.g. Logistics Team" 
                      value={teamForm.customName} 
                      onChange={(e) => setTeamForm({ ...teamForm, customName: e.target.value })} 
                      required 
                    />
                  </div>
                )}
              </div>
              <div className="modal-footer">
                <button type="button" className="btn-cancel" onClick={() => setShowTeamModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" style={{ width: 'auto' }}>Save Team</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* USER CREATION/EDIT MODAL */}
      {showUserModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3>{editingUser ? 'Edit Employee Details' : 'Register New Employee'}</h3>
              <button className="modal-close" onClick={() => setShowUserModal(false)}>×</button>
            </div>
            <form onSubmit={handleSaveUser}>
              <div className="modal-body">
                <div className="form-row">
                  <div className="form-group">
                    <label>Full Name</label>
                    <input 
                      type="text" 
                      placeholder="John Doe" 
                      value={userForm.name} 
                      onChange={(e) => setUserForm({ ...userForm, name: e.target.value })} 
                      required 
                    />
                  </div>
                  <div className="form-group">
                    <label>Email Address</label>
                    <input 
                      type="email" 
                      placeholder="john.doe@company.in" 
                      value={userForm.email} 
                      onChange={(e) => setUserForm({ ...userForm, email: e.target.value })} 
                      required 
                    />
                  </div>
                </div>

                {!editingUser && (
                  <div className="form-group">
                    <label>Password</label>
                    <input 
                      type="password" 
                      placeholder="Set initial password" 
                      value={userForm.password} 
                      onChange={(e) => setUserForm({ ...userForm, password: e.target.value })} 
                      required 
                    />
                  </div>
                )}

                <div className="form-row">
                  <div className="form-group">
                    <label>Corporate Role</label>
                    <select 
                      value={userForm.role} 
                      onChange={(e) => setUserForm({ ...userForm, role: e.target.value })}
                    >
                      <option value="employee">Employee</option>
                      <option value="team_leader">Team Leader</option>
                      <option value="manager">Manager</option>
                    </select>
                  </div>
                  <div className="form-group">
                    <label>Employee ID</label>
                    <input 
                      type="text" 
                      placeholder="EMP00123" 
                      value={userForm.employeeId} 
                      onChange={(e) => setUserForm({ ...userForm, employeeId: e.target.value })} 
                      required 
                    />
                  </div>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label>Department</label>
                    <select 
                      value={userForm.department} 
                      onChange={(e) => setUserForm({ ...userForm, department: e.target.value })}
                    >
                      {DEPARTMENTS.map(d => (
                        <option key={d} value={d}>{d}</option>
                      ))}
                    </select>
                  </div>
                  <div className="form-group">
                    <label>Assign to Team</label>
                    <select 
                      value={userForm.teamId} 
                      onChange={(e) => setUserForm({ ...userForm, teamId: e.target.value })}
                    >
                      <option value="">No Team (Orphaned)</option>
                      {teams.map(t => (
                        <option key={t.id} value={t.id}>{t.name}</option>
                      ))}
                    </select>
                  </div>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label>Date of Birth</label>
                    <input 
                      type="date" 
                      value={userForm.dob} 
                      onChange={(e) => setUserForm({ ...userForm, dob: e.target.value })} 
                      required 
                    />
                  </div>
                  <div className="form-group">
                    <label>Work Mode</label>
                    <select 
                      value={userForm.workMode} 
                      onChange={(e) => setUserForm({ ...userForm, workMode: e.target.value })}
                    >
                      {WORK_MODES.map(mode => (
                        <option key={mode} value={mode}>{mode}</option>
                      ))}
                    </select>
                  </div>
                </div>

                {userForm.department === 'Marketing' && (
                  <div className="form-group">
                    <label>Marketing Work Type</label>
                    <select 
                      value={userForm.workType} 
                      onChange={(e) => setUserForm({ ...userForm, workType: e.target.value })}
                    >
                      {WORK_TYPES.map(t => (
                        <option key={t} value={t}>{t}</option>
                      ))}
                    </select>
                  </div>
                )}

                <div className="form-row">
                  <div className="form-group">
                    <label>State (India)</label>
                    <select 
                      value={userForm.state} 
                      onChange={(e) => setUserForm({ ...userForm, state: e.target.value, city: INDIAN_STATES_CITIES[e.target.value][0] })}
                    >
                      {Object.keys(INDIAN_STATES_CITIES).map(state => (
                        <option key={state} value={state}>{state}</option>
                      ))}
                    </select>
                  </div>
                  <div className="form-group">
                    <label>City</label>
                    <select 
                      value={userForm.city} 
                      onChange={(e) => setUserForm({ ...userForm, city: e.target.value })}
                    >
                      {(INDIAN_STATES_CITIES[userForm.state] || []).map(city => (
                        <option key={city} value={city}>{city}</option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn-cancel" onClick={() => setShowUserModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" style={{ width: 'auto' }}>Save Changes</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* LEAVE APPROVAL MODAL */}
      {showLeaveModal && selectedLeave && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '460px' }}>
            <div className="modal-header">
              <h3>Leave Request Review</h3>
              <button className="modal-close" onClick={() => setShowLeaveModal(false)}>×</button>
            </div>
            <div className="modal-body">
              <div style={{ marginBottom: '20px' }}>
                <p><strong>Employee:</strong> {selectedLeave.user?.name}</p>
                <p><strong>Duration:</strong> {selectedLeave.startDate} to {selectedLeave.endDate}</p>
                <p style={{ marginTop: '8px' }}><strong>Reason:</strong> "{selectedLeave.reason}"</p>
              </div>
              <div className="form-group">
                <label>Admin/Approver Remarks</label>
                <textarea 
                  placeholder="E.g. Approved, cover duties managed." 
                  value={leaveComment} 
                  onChange={(e) => setLeaveComment(e.target.value)} 
                  rows="3" 
                />
              </div>
            </div>
            <div className="modal-footer" style={{ justifyContent: 'space-between' }}>
              <button className="btn-cancel" style={{ color: 'var(--color-danger)', borderColor: 'rgba(244, 63, 94, 0.2)' }} onClick={() => handleLeaveAction(false)}>Reject Application</button>
              <button className="btn-primary" style={{ width: 'auto' }} onClick={() => handleLeaveAction(true)}>Approve Application</button>
            </div>
          </div>
        </div>
      )}

      {/* MONTHLY SUMMARY CALENDAR MODAL */}
      {showCalendarModal && calendarUser && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '640px' }}>
            <div className="modal-header">
              <div>
                <h3>Attendance Summary Calendar</h3>
                <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Employee: <strong>{calendarUser.name}</strong></span>
              </div>
              <button className="modal-close" onClick={() => setShowCalendarModal(false)}>×</button>
            </div>
            <div className="modal-body">
              <div className="calendar-view-container">
                <div className="calendar-header">
                  <button className="calendar-nav-btn" onClick={() => handleCalendarNav(-1)}>◀ Prev Month</button>
                  <h4 style={{ fontSize: '18px', fontWeight: 'bold' }}>
                    {new Date(currentYear, currentMonth - 1).toLocaleString('default', { month: 'long', year: 'numeric' })}
                  </h4>
                  <button className="calendar-nav-btn" onClick={() => handleCalendarNav(1)}>Next Month ▶</button>
                </div>

                <div className="calendar-days-grid">
                  <div className="calendar-weekday">Sun</div>
                  <div className="calendar-weekday">Mon</div>
                  <div className="calendar-weekday">Tue</div>
                  <div className="calendar-weekday">Wed</div>
                  <div className="calendar-weekday">Thu</div>
                  <div className="calendar-weekday">Fri</div>
                  <div className="calendar-weekday">Sat</div>
                  {renderCalendarCells()}
                </div>

                <div className="calendar-legend">
                  <div className="legend-item"><div className="calendar-day-status-dot present"></div> Present</div>
                  <div className="legend-item"><div className="calendar-day-status-dot late"></div> Late</div>
                  <div className="legend-item"><div className="calendar-day-status-dot half_day"></div> Half Day</div>
                  <div className="legend-item"><div className="calendar-day-status-dot absent"></div> Absent</div>
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={() => setShowCalendarModal(false)}>Close Calendar</button>
            </div>
          </div>
        </div>
      )}

      {/* HOLIDAY EXCEPTIONS MODAL */}
      {showExceptionsModal && selectedHoliday && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '520px' }}>
            <div className="modal-header">
              <div>
                <h3>Manage Holiday Exceptions</h3>
                <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Holiday: <strong>{selectedHoliday.name}</strong> ({selectedHoliday.date})</span>
              </div>
              <button className="modal-close" onClick={() => setShowExceptionsModal(false)}>×</button>
            </div>
            <div className="modal-body">
              {/* Form to Add Exception */}
              <form onSubmit={handleAddException} style={{ borderBottom: '1px solid var(--card-border)', paddingBottom: '20px', marginBottom: '20px' }}>
                <h4 style={{ marginBottom: '12px', fontSize: '14px', color: 'var(--color-primary)' }}>➕ Exempt a Team or Employee</h4>
                <div className="form-group">
                  <label>Exemption Scope</label>
                  <select 
                    value={exceptionForm.targetType} 
                    onChange={e => setExceptionForm({ ...exceptionForm, targetType: e.target.value, teamId: '', userId: '' })}
                  >
                    <option value="team">Team Scope (All team members exempt)</option>
                    <option value="user">Individual Employee Scope</option>
                  </select>
                </div>

                {exceptionForm.targetType === 'team' ? (
                  <div className="form-group">
                    <label>Select Team</label>
                    <select 
                      value={exceptionForm.teamId} 
                      onChange={e => setExceptionForm({ ...exceptionForm, teamId: e.target.value })}
                      required
                    >
                      <option value="">-- Choose Team --</option>
                      {teams.map(t => (
                        <option key={t.id} value={t.id}>{t.name}</option>
                      ))}
                    </select>
                  </div>
                ) : (
                  <div className="form-group">
                    <label>Select Employee</label>
                    <select 
                      value={exceptionForm.userId} 
                      onChange={e => setExceptionForm({ ...exceptionForm, userId: e.target.value })}
                      required
                    >
                      <option value="">-- Choose Employee --</option>
                      {users.filter(u => u.role === 'employee' && u.isActive).map(u => (
                        <option key={u.id} value={u.id}>{u.name} ({u.employeeId || u.email})</option>
                      ))}
                    </select>
                  </div>
                )}

                <button type="submit" className="btn-primary" style={{ marginTop: '10px' }}>Add Exemption</button>
              </form>

              {/* List of active exceptions */}
              <h4 style={{ marginBottom: '12px' }}>Active Exemptions</h4>
              <div className="table-wrapper" style={{ maxHeight: '200px', overflowY: 'auto' }}>
                <table className="custom-table" style={{ fontSize: '13px' }}>
                  <thead>
                    <tr>
                      <th>Scope Type</th>
                      <th>Exempt Target</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {holidayExceptions.length === 0 ? (
                      <tr>
                        <td colSpan="3" style={{ textAlign: 'center', color: 'var(--text-secondary)' }}>No exceptions registered for this holiday.</td>
                      </tr>
                    ) : (
                      holidayExceptions.map(exc => (
                        <tr key={exc.id}>
                          <td><strong>{exc.teamId ? '👥 Team' : '👤 Employee'}</strong></td>
                          <td>{exc.teamId ? (exc.team?.name || `Team ID: ${exc.teamId}`) : (exc.user?.name || `Employee ID: ${exc.userId}`)}</td>
                          <td>
                            <button className="btn-secondary-action" style={{ padding: '4px 8px', color: 'var(--color-danger)', fontSize: '11px' }} onClick={() => handleDeleteException(exc.id)}>
                              Remove
                            </button>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={() => setShowExceptionsModal(false)}>Close Exceptions Panel</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

const AttendanceTable = ({ records }) => {
  return (
    <div className="table-wrapper">
      <table className="custom-table">
        <thead>
          <tr>
            <th>Employee</th>
            <th>Live Selfie</th>
            <th>Login Spot (In / Out)</th>
            <th>Mood / Energy</th>
            <th>Distance</th>
            <th>Status</th>
            <th>Working Hours</th>
          </tr>
        </thead>
        <tbody>
          {records.map(rec => {
            const moodEmoji = rec.mood === 'happy' ? '😊 Happy' : rec.mood === 'sad' ? '😢 Sad' : rec.mood === 'exhausted' ? '😩 Exhausted' : rec.mood === 'angry' ? '😤 Angry' : rec.mood;
            const energyEmoji = rec.energyLevel === 'low' ? '🔋 Low' : rec.energyLevel === 'medium' ? '🔋🔋 Medium' : rec.energyLevel === 'high' ? '🔋🔋🔋 High' : rec.energyLevel;
            return (
              <tr key={rec.id}>
                <td>
                  <strong>{rec.user?.name || 'Unknown'}</strong>
                  <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>ID: {rec.user?.employeeId || 'N/A'}</div>
                </td>
                <td>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    {rec.selfieUrl ? (
                      <a href={`https://intime.hirelyft.in${rec.selfieUrl}`} target="_blank" rel="noopener noreferrer">
                        <img src={`https://intime.hirelyft.in${rec.selfieUrl}`} alt="In" style={{ width: '40px', height: '40px', borderRadius: '8px', objectFit: 'cover', border: '1px solid var(--card-border)' }} />
                      </a>
                    ) : '—'}
                    {rec.checkoutSelfieUrl ? (
                      <a href={`https://intime.hirelyft.in${rec.checkoutSelfieUrl}`} target="_blank" rel="noopener noreferrer">
                        <img src={`https://intime.hirelyft.in${rec.checkoutSelfieUrl}`} alt="Out" style={{ width: '40px', height: '40px', borderRadius: '8px', objectFit: 'cover', border: '1px solid var(--card-border)' }} />
                      </a>
                    ) : null}
                  </div>
                </td>
                <td>
                  <div>
                    <span style={{ color: 'var(--color-success)', fontWeight: 'bold' }}>↳ IN:</span>{' '}
                    <span style={{ fontSize: '12px' }}>{rec.checkInTime ? new Date(rec.checkInTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '—'}</span>
                    {rec.address && <div style={{ fontSize: '10px', color: 'var(--text-secondary)', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={rec.address}>{rec.address}</div>}
                  </div>
                  {rec.checkOutTime && (
                    <div style={{ marginTop: '4px' }}>
                      <span style={{ color: 'var(--color-danger)', fontWeight: 'bold' }}>↱ OUT:</span>{' '}
                      <span style={{ fontSize: '12px' }}>{new Date(rec.checkOutTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                      {rec.checkoutAddress && <div style={{ fontSize: '10px', color: 'var(--text-secondary)', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={rec.checkoutAddress}>{rec.checkoutAddress}</div>}
                    </div>
                  )}
                </td>
                <td>
                  {rec.mood && <span className="badge" style={{ backgroundColor: 'var(--bg-secondary)', color: 'var(--text-primary)', marginRight: '6px', textTransform: 'none' }}>{moodEmoji}</span>}
                  {rec.energyLevel && <span className="badge" style={{ backgroundColor: 'var(--bg-secondary)', color: 'var(--text-primary)', textTransform: 'none' }}>{energyEmoji}</span>}
                  {!rec.mood && !rec.energyLevel && '—'}
                </td>
                <td>
                  {rec.distanceFromOffice !== null && rec.distanceFromOffice !== undefined ? (
                    <span className={`badge ${rec.distanceFromOffice < 100 ? 'present' : 'warning'}`} style={{ fontWeight: 'bold' }}>
                      {rec.distanceFromOffice < 100
                        ? 'In Zone'
                        : rec.distanceFromOffice < 1000
                          ? `${rec.distanceFromOffice}m away`
                          : `${(rec.distanceFromOffice / 1000).toFixed(2)}km away`}
                    </span>
                  ) : '—'}
                </td>
                <td>
                  <span className={`badge ${rec.status}`}>{rec.status.toUpperCase()}</span>
                </td>
                <td>
                  <strong style={{ fontFamily: 'monospace' }}>{rec.workingHours || '—'}</strong>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};

export default App;
