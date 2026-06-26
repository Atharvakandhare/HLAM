import React, { useState, useEffect } from 'react';

const Navbar = ({ activeTab, handleSignOut }) => {
  const [headerTime, setHeaderTime] = useState(
    new Date().toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' })
  );

  useEffect(() => {
    const timer = setInterval(() => {
      const now = new Date();
      setHeaderTime(now.toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' }));
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  return (
    <div className="main-header">
      <div className="page-title">
        <h2>{activeTab.toUpperCase().replace('_', ' ')}</h2>
      </div>
      <div className="header-actions">
        <span style={{ fontSize: '14px', color: 'var(--text-secondary)', fontWeight: 600 }}>
          {headerTime}
        </span>
        <button className="btn-signout" onClick={handleSignOut}>Sign Out</button>
      </div>
    </div>
  );
};

export default Navbar;
