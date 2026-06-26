import React from 'react';
import { SERVER_BASE } from '../constants';

const Sidebar = ({ user, activeTab, setActiveTab }) => {
  if (!user) return null;

  return (
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

        {user.role === 'system_admin' && (
          <li className={`sidebar-item ${activeTab === 'companies' ? 'active' : ''}`} onClick={() => setActiveTab('companies')}>
            <span>🏢 Companies Admin</span>
          </li>
        )}
        
        {['system_admin', 'company_admin'].includes(user.role) && (
          <>
            <li className={`sidebar-item ${activeTab === 'teams' ? 'active' : ''}`} onClick={() => setActiveTab('teams')}>
              <span>👥 Teams Admin</span>
            </li>
            <li className={`sidebar-item ${activeTab === 'shifts' ? 'active' : ''}`} onClick={() => setActiveTab('shifts')}>
              <span>⏰ Shift Management</span>
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

        {['system_admin', 'company_admin'].includes(user.role) && (
          <li className={`sidebar-item ${activeTab === 'marketing' ? 'active' : ''}`} onClick={() => setActiveTab('marketing')}>
            <span>📍 Marketing Tracker</span>
          </li>
        )}
      </ul>

      <div className="sidebar-user">
        <img 
          src={user.profilePicture ? `${SERVER_BASE}${user.profilePicture}` : "https://avatar.iran.liara.run/public/boy"} 
          alt="Avatar" 
          className="user-avatar" 
        />
        <div className="user-details">
          <span className="user-name">{user.name}</span>
          <span className="user-role">{user.role.replace('_', ' ')}</span>
        </div>
      </div>
    </div>
  );
};

export default Sidebar;
