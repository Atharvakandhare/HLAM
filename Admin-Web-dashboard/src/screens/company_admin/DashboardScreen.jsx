import React, { useState, useEffect } from 'react';
import { API_BASE } from '../../constants';

const DashboardScreen = ({ token, setActiveTab }) => {
  const [stats, setStats] = useState({
    totalPresent: 0,
    totalLate: 0,
    totalHalfDay: 0,
    totalAbsent: 0,
    attendanceRate: 0
  });
  const [recentUsers, setRecentUsers] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  const fetchData = async () => {
    setIsLoading(true);
    try {
      // Fetch stats
      const statsRes = await fetch(`${API_BASE}/admin/attendance/stats`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (statsRes.ok) {
        const statsData = await statsRes.json();
        setStats(statsData);
      }

      // Fetch recent users
      const usersRes = await fetch(`${API_BASE}/admin/users`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (usersRes.ok) {
        const usersData = await usersRes.json();
        setRecentUsers(usersData.users || []);
      }
    } catch (err) {
      console.error('Error fetching dashboard data:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [token]);

  if (isLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
        Loading dashboard metrics...
      </div>
    );
  }

  return (
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
              {recentUsers.slice(0, 5).map(u => (
                <tr key={u.id}>
                  <td>{u.employeeId || 'N/A'}</td>
                  <td>{u.name}</td>
                  <td>{u.email}</td>
                  <td><span className={`badge ${u.role}`}>{u.role.replace('_', ' ')}</span></td>
                  <td>{u.department || 'N/A'}</td>
                  <td><span className={`badge ${u.isActive ? 'present' : 'absent'}`}>{u.isActive ? 'Active' : 'Inactive'}</span></td>
                </tr>
              ))}
              {recentUsers.length === 0 && (
                <tr>
                  <td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-secondary)' }}>No registered employees found.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
};

export default DashboardScreen;
