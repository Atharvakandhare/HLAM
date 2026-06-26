import React, { useState, useEffect } from 'react';
import { API_BASE, SERVER_BASE } from '../../constants';

const MarketingTrackerScreen = ({ token }) => {
  const [marketingEmployees, setMarketingEmployees] = useState([]);
  const [selectedMarketingUser, setSelectedMarketingUser] = useState(null);
  const [marketingTrail, setMarketingTrail] = useState([]);
  const [selectedTrailPoint, setSelectedTrailPoint] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  const fetchMarketingEmployees = async () => {
    setIsLoading(true);
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
      console.error('Error fetching marketing employees:', err);
    } finally {
      setIsLoading(false);
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

  useEffect(() => {
    fetchMarketingEmployees();
  }, [token]);

  if (isLoading && marketingEmployees.length === 0) {
    return (
      <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
        Loading marketing employees...
      </div>
    );
  }

  return (
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
                    src={emp.user.profilePicture ? `${SERVER_BASE}${emp.user.profilePicture}` : "https://avatar.iran.liara.run/public/boy"} 
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
            {marketingEmployees.length === 0 && (
              <div style={{ color: 'var(--text-secondary)', fontSize: '13px', textAlign: 'center', padding: '20px' }}>No marketing employees found.</div>
            )}
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

      <div className="marketing-map-panel" style={{ flexGrow: 1 }}>
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
  );
};

export default MarketingTrackerScreen;
