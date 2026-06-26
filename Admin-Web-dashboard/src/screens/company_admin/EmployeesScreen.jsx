import React, { useState, useEffect } from 'react';
import { 
  API_BASE, 
  SERVER_BASE, 
  DEPARTMENTS, 
  WORK_MODES, 
  WORK_TYPES, 
  INDIAN_STATES_CITIES 
} from '../../constants';

const EmployeesScreen = ({ token }) => {
  const [users, setUsers] = useState([]);
  const [teams, setTeams] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  // User Add/Edit modal states
  const [showUserModal, setShowUserModal] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [activeTab, setActiveTab] = useState(0);
  const [userForm, setUserForm] = useState({
    name: '', email: '', password: '', role: 'employee', department: 'IT',
    employeeId: '', dob: '', state: 'Maharashtra', city: 'Mumbai',
    workMode: 'Work From Office', workType: 'Work From Office', teamId: ''
  });

  // Bulk Upload states
  const [showBulkModal, setShowBulkModal] = useState(false);
  const [bulkFile, setBulkFile] = useState(null);
  const [bulkUploading, setBulkUploading] = useState(false);
  const [bulkError, setBulkError] = useState('');
  const [bulkResult, setBulkResult] = useState(null);

  // Calendar states
  const [showCalendarModal, setShowCalendarModal] = useState(false);
  const [calendarUser, setCalendarUser] = useState(null);
  const [currentYear, setCurrentYear] = useState(new Date().getFullYear());
  const [currentMonth, setCurrentMonth] = useState(new Date().getMonth() + 1);
  const [calendarRecords, setCalendarRecords] = useState([]);

  const fetchData = async () => {
    setIsLoading(true);
    try {
      const usersRes = await fetch(`${API_BASE}/admin/users`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (usersRes.ok) {
        const usersData = await usersRes.json();
        setUsers(usersData.users || []);
      }

      const teamsRes = await fetch(`${API_BASE}/admin/teams`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (teamsRes.ok) {
        const teamsData = await teamsRes.json();
        setTeams(teamsData.teams || []);
      }
    } catch (err) {
      console.error('Error fetching employees data:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [token]);

  const handleDownloadTemplate = async () => {
    try {
      const res = await fetch(`${API_BASE}/admin/users/template`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (!res.ok) throw new Error('Failed to download template');
      const blob = await res.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'employees_template.xlsx';
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      alert(err.message || 'Error downloading template');
    }
  };

  const handleBulkUpload = async (e) => {
    e.preventDefault();
    if (!bulkFile) {
      setBulkError('Please select a file to upload.');
      return;
    }
    setBulkUploading(true);
    setBulkError('');
    setBulkResult(null);
    try {
      const formData = new FormData();
      formData.append('file', bulkFile);
      const res = await fetch(`${API_BASE}/admin/users/bulk-upload`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData
      });
      const data = await res.json();
      if (res.ok) {
        setBulkResult(data);
        if (data.insertedCount > 0) {
          fetchData();
        }
      } else {
        setBulkError(data.message || 'Bulk upload failed.');
      }
    } catch (err) {
      setBulkError('Connection error. Failed to upload file.');
    } finally {
      setBulkUploading(false);
    }
  };

  const openAddUserModal = () => {
    setEditingUser(null);
    setUserForm({
      name: '', email: '', password: '', role: 'employee', department: 'IT',
      employeeId: '', dob: '', state: 'Maharashtra', city: 'Mumbai',
      workMode: 'Work From Office', workType: 'Work From Office', teamId: ''
    });
    setActiveTab(0);
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
    setActiveTab(0);
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
        fetchData();
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
        fetchData();
        alert('User deactivated successfully.');
      } else {
        alert('Failed to deactivate user.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleResetSession = async (id) => {
    if (!window.confirm("Are you sure you want to reset this employee's active device session?")) return;
    try {
      const res = await fetch(`${API_BASE}/admin/users/${id}/reset-session`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}` 
        }
      });
      if (res.ok) {
        alert('Session reset successfully. The employee can now log in from a new device.');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to reset session.');
      }
    } catch (err) {
      console.error('Error resetting session:', err);
      alert('Connection error. Failed to reset session.');
    }
  };

  // Calendar Logics
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

  const getDaysInMonth = (year, month) => new Date(year, month, 0).getDate();
  const getFirstDayOfMonth = (year, month) => new Date(year, month - 1, 1).getDay();

  const renderCalendarCells = () => {
    const daysCount = getDaysInMonth(currentYear, currentMonth);
    const firstDay = getFirstDayOfMonth(currentYear, currentMonth);
    const cells = [];

    for (let i = 0; i < firstDay; i++) {
      cells.push(<div key={`blank-${i}`} className="calendar-day-cell empty"></div>);
    }

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
        // weekend
      } else {
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

  if (isLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
        Loading employees directory...
      </div>
    );
  }

  return (
    <div className="section-box">
      <div className="section-header">
        <h3>Employee Directory</h3>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button className="btn-secondary-action" onClick={handleDownloadTemplate} style={{ border: '1px solid #c7d2fe', padding: '6px 12px', fontSize: '13px' }}>📥 Download Template</button>
          <button className="btn-secondary-action" onClick={() => {
            setBulkFile(null);
            setBulkError('');
            setBulkResult(null);
            setShowBulkModal(true);
          }} style={{ border: '1px solid #c7d2fe', padding: '6px 12px', fontSize: '13px' }}>📤 Bulk Upload</button>
          <button className="btn-action" onClick={openAddUserModal}>Add Employee</button>
        </div>
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
                      src={u.profilePicture ? `${SERVER_BASE}${u.profilePicture}` : "https://avatar.iran.liara.run/public/boy"} 
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
                    <button className="btn-secondary-action" style={{ padding: '6px 10px', fontSize: '12px', color: '#d97706', borderColor: '#fef3c7' }} onClick={() => handleResetSession(u.id)}>🔄 Reset Session</button>
                    <button className="btn-secondary-action" style={{ padding: '6px 10px', fontSize: '12px', color: 'var(--color-danger)' }} onClick={() => handleDeleteUser(u.id)}>🗑️ Deactivate</button>
                  </div>
                </td>
              </tr>
            ))}
            {users.length === 0 && (
              <tr>
                <td colSpan="8" style={{ textAlign: 'center', color: 'var(--text-secondary)' }}>No registered employees found.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* USER CREATION/EDIT MODAL */}
      {showUserModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3>{editingUser ? 'Edit Employee Details' : 'Register New Employee'}</h3>
              <button className="modal-close" onClick={() => setShowUserModal(false)}>×</button>
            </div>
            
            {/* Simple tabbed design */}
            <div className="modal-tabs" style={{ display: 'flex', gap: '15px', borderBottom: '1px solid #e2e8f0', marginBottom: '20px', padding: '0 5px' }}>
              <button 
                type="button" 
                onClick={() => setActiveTab(0)} 
                style={{ 
                  padding: '8px 12px', 
                  border: 'none', 
                  background: 'none', 
                  borderBottom: activeTab === 0 ? '2px solid var(--color-primary, #2563eb)' : 'none', 
                  fontWeight: activeTab === 0 ? 'bold' : 'normal', 
                  color: activeTab === 0 ? 'var(--color-primary, #2563eb)' : '#64748b', 
                  cursor: 'pointer' 
                }}
              >
                Personal Profile
              </button>
              <button 
                type="button" 
                onClick={() => setActiveTab(1)} 
                style={{ 
                  padding: '8px 12px', 
                  border: 'none', 
                  background: 'none', 
                  borderBottom: activeTab === 1 ? '2px solid var(--color-primary, #2563eb)' : 'none', 
                  fontWeight: activeTab === 1 ? 'bold' : 'normal', 
                  color: activeTab === 1 ? 'var(--color-primary, #2563eb)' : '#64748b', 
                  cursor: 'pointer' 
                }}
              >
                Residence Details
              </button>
              <button 
                type="button" 
                onClick={() => setActiveTab(2)} 
                style={{ 
                  padding: '8px 12px', 
                  border: 'none', 
                  background: 'none', 
                  borderBottom: activeTab === 2 ? '2px solid var(--color-primary, #2563eb)' : 'none', 
                  fontWeight: activeTab === 2 ? 'bold' : 'normal', 
                  color: activeTab === 2 ? 'var(--color-primary, #2563eb)' : '#64748b', 
                  cursor: 'pointer' 
                }}
              >
                Job Assignment
              </button>
            </div>

            <form onSubmit={handleSaveUser}>
              <div className="modal-body">
                {activeTab === 0 && (
                  <div>
                    <div className="form-row">
                      <div className="form-group">
                        <label>Full Name *</label>
                        <input 
                          type="text" 
                          placeholder="John Doe" 
                          value={userForm.name} 
                          onChange={(e) => setUserForm({ ...userForm, name: e.target.value })} 
                          required 
                        />
                      </div>
                      <div className="form-group">
                        <label>Email Address *</label>
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
                        <label>Password *</label>
                        <input 
                          type="password" 
                          placeholder="Set initial password" 
                          value={userForm.password} 
                          onChange={(e) => setUserForm({ ...userForm, password: e.target.value })} 
                          required 
                        />
                      </div>
                    )}

                    <div className="form-group">
                      <label>Date of Birth *</label>
                      <input 
                        type="date" 
                        value={userForm.dob} 
                        onChange={(e) => setUserForm({ ...userForm, dob: e.target.value })} 
                        required 
                      />
                    </div>
                  </div>
                )}

                {activeTab === 1 && (
                  <div>
                    <div className="form-row">
                      <div className="form-group">
                        <label>State (India)</label>
                        <select 
                          value={userForm.state} 
                          onChange={(e) => {
                            const state = e.target.value;
                            const defaultCity = INDIAN_STATES_CITIES[state] ? INDIAN_STATES_CITIES[state][0] : '';
                            setUserForm({ ...userForm, state, city: defaultCity });
                          }}
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
                )}

                {activeTab === 2 && (
                  <div>
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
                        <label>Employee ID *</label>
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
                        <label>Department *</label>
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
                  </div>
                )}
              </div>
              <div className="modal-footer" style={{ display: 'flex', justifyContent: 'space-between' }}>
                <div>
                  {activeTab > 0 && (
                    <button type="button" className="btn-cancel" onClick={() => setActiveTab(activeTab - 1)}>
                      Back
                    </button>
                  )}
                </div>
                <div style={{ display: 'flex', gap: '10px' }}>
                  <button type="button" className="btn-cancel" onClick={() => setShowUserModal(false)}>Cancel</button>
                  {activeTab < 2 ? (
                    <button 
                      type="button" 
                      className="btn-primary" 
                      onClick={() => {
                        // Validate active tab requirements
                        if (activeTab === 0) {
                          if (!userForm.name.trim()) {
                            alert('Full Name is required');
                            return;
                          }
                          if (!userForm.email.trim() || !userForm.email.includes('@')) {
                            alert('A valid Email Address is required');
                            return;
                          }
                          if (!editingUser && !userForm.password) {
                            alert('Password is required');
                            return;
                          }
                          if (!userForm.dob) {
                            alert('Date of Birth is required');
                            return;
                          }
                        }
                        setActiveTab(activeTab + 1);
                      }} 
                      style={{ width: 'auto' }}
                    >
                      Next
                    </button>
                  ) : (
                    <button type="submit" className="btn-primary" style={{ width: 'auto' }}>
                      {editingUser ? 'Save Changes' : 'Register Employee'}
                    </button>
                  )}
                </div>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* BULK UPLOAD MODAL */}
      {showBulkModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '500px' }}>
            <div className="modal-header">
              <h3>Bulk Employee Upload</h3>
              <button className="modal-close" onClick={() => setShowBulkModal(false)}>×</button>
            </div>
            <form onSubmit={handleBulkUpload}>
              <div className="modal-body">
                <p style={{ color: 'var(--text-secondary)', fontSize: '14px', marginBottom: '20px' }}>
                  Download the template spreadsheet, fill in details for your Employees, Managers, and Team Leaders, and upload the completed sheet below.
                </p>
                
                <div className="form-group" style={{ marginBottom: '20px' }}>
                  <label>Select Spreadsheet (.xlsx, .xls, .csv)</label>
                  <input 
                    type="file" 
                    accept=".xlsx,.xls,.csv"
                    onChange={(e) => setBulkFile(e.target.files[0])}
                    style={{
                      padding: '10px',
                      border: '1px dashed #c7d2fe',
                      borderRadius: '8px',
                      background: '#f8fafc',
                      width: '100%',
                      cursor: 'pointer'
                    }}
                    required
                  />
                </div>

                {bulkUploading && (
                  <div style={{ textAlign: 'center', margin: '20px 0', color: 'var(--color-primary)' }}>
                    <strong>Uploading and processing sheet... Please wait.</strong>
                  </div>
                )}

                {bulkError && (
                  <div style={{ color: 'var(--color-danger)', background: '#fef2f2', padding: '12px', borderRadius: '8px', marginBottom: '15px', fontSize: '13px' }}>
                    {bulkError}
                  </div>
                )}

                {bulkResult && (
                  <div style={{ background: '#f0fdf4', border: '1px solid #bbf7d0', padding: '16px', borderRadius: '10px', marginBottom: '15px' }}>
                    <h4 style={{ margin: '0 0 10px 0', color: '#166534', fontSize: '15px' }}>Bulk Registration Complete</h4>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '6px' }}>
                      <span>Successfully Registered:</span>
                      <strong style={{ color: '#15803d' }}>{bulkResult.insertedCount}</strong>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '6px' }}>
                      <span>Failed Rows:</span>
                      <strong style={{ color: bulkResult.failedCount > 0 ? '#b91c1c' : '#4b5563' }}>{bulkResult.failedCount}</strong>
                    </div>

                    {bulkResult.errors && bulkResult.errors.length > 0 && (
                      <div style={{ marginTop: '12px' }}>
                         <span style={{ fontSize: '12px', fontWeight: 'bold', color: '#b91c1c' }}>Errors:</span>
                         <div style={{
                           maxHeight: '120px',
                           overflowY: 'auto',
                           background: '#fff',
                           border: '1px solid #fca5a5',
                           borderRadius: '6px',
                           padding: '8px',
                           marginTop: '5px',
                           fontSize: '11px',
                           color: '#b91c1c'
                         }}>
                           {bulkResult.errors.map((err, idx) => (
                             <div key={idx} style={{ marginBottom: '4px' }}>• {err}</div>
                           ))}
                         </div>
                       </div>
                    )}
                  </div>
                )}
              </div>
              <div className="modal-footer">
                <button type="button" className="btn-cancel" onClick={() => setShowBulkModal(false)}>Cancel</button>
                {!bulkResult ? (
                  <button type="submit" className="btn-primary" disabled={bulkUploading} style={{ width: 'auto' }}>
                    {bulkUploading ? 'Uploading...' : 'Upload & Register'}
                  </button>
                ) : (
                  <button type="button" className="btn-primary" onClick={() => setShowBulkModal(false)} style={{ width: 'auto' }}>Close</button>
                )}
              </div>
            </form>
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
    </div>
  );
};

export default EmployeesScreen;
