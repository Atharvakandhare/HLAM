import React, { useState, useEffect } from 'react';
import './App.css';
import { API_BASE } from './constants';

// Layout & Common Components
import Sidebar from './components/Sidebar';
import Navbar from './components/Navbar';

// Auth Screen
import LoginScreen from './screens/LoginScreen';

// Company Admin Screens
import DashboardScreen from './screens/company_admin/DashboardScreen';
import AttendanceJournalScreen from './screens/company_admin/AttendanceJournalScreen';
import TeamsAdminScreen from './screens/company_admin/TeamsAdminScreen';
import CompanyHolidaysScreen from './screens/company_admin/CompanyHolidaysScreen';
import GeofencingTimesScreen from './screens/company_admin/GeofencingTimesScreen';
import EmployeesScreen from './screens/company_admin/EmployeesScreen';
import LeaveRequestsScreen from './screens/company_admin/LeaveRequestsScreen';
import MarketingTrackerScreen from './screens/company_admin/MarketingTrackerScreen';

// System Admin Screen
import CompaniesAdminScreen from './screens/system_admin/CompaniesAdminScreen';

const App = () => {
  const [token, setToken] = useState(localStorage.getItem('admin_token') || '');
  const [user, setUser] = useState(null);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [isLoadingUser, setIsLoadingUser] = useState(true);

  const handleSignOut = () => {
    localStorage.removeItem('admin_token');
    setToken('');
    setUser(null);
    setActiveTab('dashboard');
  };

  const fetchMe = async (authToken) => {
    setIsLoadingUser(true);
    try {
      const res = await fetch(`${API_BASE}/auth/me`, {
        headers: { 'Authorization': `Bearer ${authToken}` }
      });
      if (res.ok) {
        const data = await res.json();
        setUser(data);
        if (data.role === 'system_admin') {
          setActiveTab('dashboard');
        }
      } else {
        handleSignOut();
      }
    } catch (err) {
      console.error(err);
      handleSignOut();
    } finally {
      setIsLoadingUser(false);
    }
  };

  // Fetch user profile on token change
  useEffect(() => {
    if (token) {
      fetchMe(token);
    } else {
      setUser(null);
      setIsLoadingUser(false);
    }
  }, [token]);

  if (isLoadingUser) {
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        backgroundColor: '#090a0f',
        color: '#ffffff',
        fontFamily: 'sans-serif'
      }}>
        <h2>Validating Session...</h2>
      </div>
    );
  }

  if (!token || !user) {
    return <LoginScreen setToken={setToken} setUser={setUser} />;
  }

  // Active screen routing logic
  const renderActiveScreen = () => {
    switch (activeTab) {
      case 'dashboard':
        return <DashboardScreen token={token} setActiveTab={setActiveTab} />;
      case 'attendance':
        return <AttendanceJournalScreen token={token} />;
      case 'companies':
        if (user.role === 'system_admin') {
          return <CompaniesAdminScreen token={token} />;
        }
        return <DashboardScreen token={token} setActiveTab={setActiveTab} />;
      case 'teams':
        if (['system_admin', 'company_admin'].includes(user.role)) {
          return <TeamsAdminScreen token={token} />;
        }
        return <DashboardScreen token={token} setActiveTab={setActiveTab} />;
      case 'holidays':
        if (['system_admin', 'company_admin'].includes(user.role)) {
          return <CompanyHolidaysScreen token={token} />;
        }
        return <DashboardScreen token={token} setActiveTab={setActiveTab} />;
      case 'settings':
        if (['system_admin', 'company_admin'].includes(user.role)) {
          return <GeofencingTimesScreen token={token} />;
        }
        return <DashboardScreen token={token} setActiveTab={setActiveTab} />;
      case 'users':
        return <EmployeesScreen token={token} />;
      case 'leaves':
        return <LeaveRequestsScreen token={token} />;
      case 'marketing':
        if (['system_admin', 'company_admin'].includes(user.role)) {
          return <MarketingTrackerScreen token={token} />;
        }
        return <DashboardScreen token={token} setActiveTab={setActiveTab} />;
      default:
        return <DashboardScreen token={token} setActiveTab={setActiveTab} />;
    }
  };

  return (
    <div className="app-container">
      <Sidebar user={user} activeTab={activeTab} setActiveTab={setActiveTab} />
      <div className="main-content">
        <Navbar activeTab={activeTab} handleSignOut={handleSignOut} />
        <div className="content-body">
          {renderActiveScreen()}
        </div>
      </div>
    </div>
  );
};

export default App;
