import React, { useState, useEffect } from 'react';
import { API_BASE } from '../../constants';

const GeofencingTimesScreen = ({ token }) => {
  const [companySettings, setCompanySettings] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

  const fetchData = async () => {
    setIsLoading(true);
    try {
      const res = await fetch(`${API_BASE}/admin/company-settings`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setCompanySettings(data.settings || {});
      }
    } catch (err) {
      console.error('Error fetching company settings:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [token]);

  const saveCompanySettings = async (e) => {
    e.preventDefault();
    if (!companySettings) return;
    setIsSaving(true);
    try {
      const res = await fetch(`${API_BASE}/admin/company-settings`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(companySettings)
      });
      if (res.ok) {
        alert('Company settings updated successfully!');
        fetchData();
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to update company settings.');
      }
    } catch (err) {
      console.error(err);
      alert('Error updating settings.');
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
        Loading company settings...
      </div>
    );
  }

  if (!companySettings) {
    return (
      <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
        Failed to load settings. Settings may not be provisioned for your company.
      </div>
    );
  }

  return (
    <div className="section-box">
      <div className="section-header">
        <h3>Geofencing Boundaries & Office Timings</h3>
      </div>
      <form onSubmit={saveCompanySettings}>
        <div className="form-row">
          <div className="form-group">
            <label>Check-in Starts (Office Hours)</label>
            <input 
              type="time" 
              value={companySettings.checkInTime ? companySettings.checkInTime.slice(0, 5) : "09:00"} 
              onChange={(e) => setCompanySettings({ ...companySettings, checkInTime: e.target.value + ":00" })} 
              required
            />
          </div>
          <div className="form-group">
            <label>Check-out Ends (Office Hours)</label>
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
            <label>Office GPS Latitude</label>
            <input 
              type="number" 
              step="any"
              value={companySettings.latitude} 
              onChange={(e) => setCompanySettings({ ...companySettings, latitude: parseFloat(e.target.value) || 0 })} 
              required
            />
          </div>
          <div className="form-group">
            <label>Office GPS Longitude</label>
            <input 
              type="number" 
              step="any"
              value={companySettings.longitude} 
              onChange={(e) => setCompanySettings({ ...companySettings, longitude: parseFloat(e.target.value) || 0 })} 
              required
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>Geofence Lock Radius (In Meters)</label>
            <input 
              type="number" 
              value={companySettings.radius} 
              onChange={(e) => setCompanySettings({ ...companySettings, radius: parseFloat(e.target.value) || 0 })} 
              required
            />
          </div>
          <div className="form-group">
            <label>Office Human Address</label>
            <textarea 
              rows="2"
              value={companySettings.address || ''} 
              onChange={(e) => setCompanySettings({ ...companySettings, address: e.target.value })} 
              placeholder="Full physical office location..."
            />
          </div>
        </div>

        <h3 style={{ fontSize: '18px', fontWeight: '700', marginTop: '30px', marginBottom: '20px', borderTop: '1px solid var(--card-border)', paddingTop: '20px' }}>Leave Policies (Paid Entitlement)</h3>
        
        <div className="form-row">
          <div className="form-group">
            <label>Paid Leaves Allotted / Month</label>
            <input 
              type="number" 
              value={companySettings.monthlyPaidLeaves || 0} 
              onChange={(e) => setCompanySettings({ ...companySettings, monthlyPaidLeaves: parseInt(e.target.value) || 0 })} 
              required
            />
          </div>
          <div className="form-group">
            <label>Paid Leaves Allotted / Year</label>
            <input 
              type="number" 
              value={companySettings.yearlyPaidLeaves || 0} 
              onChange={(e) => setCompanySettings({ ...companySettings, yearlyPaidLeaves: parseInt(e.target.value) || 0 })} 
              required
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>Leaves Reset Month (1-12)</label>
            <input 
              type="number" 
              min="1" 
              max="12"
              value={companySettings.leavesRefreshMonth || 1} 
              onChange={(e) => setCompanySettings({ ...companySettings, leavesRefreshMonth: parseInt(e.target.value) || 1 })}
              required
            />
          </div>
          <div className="form-group">
            <label>Leaves Reset Day (1-31)</label>
            <input 
              type="number" 
              min="1" 
              max="31"
              value={companySettings.leavesRefreshDay || 1} 
              onChange={(e) => setCompanySettings({ ...companySettings, leavesRefreshDay: parseInt(e.target.value) || 1 })}
              required
            />
          </div>
        </div>

        <button type="submit" className="btn-primary" style={{ marginTop: '20px', width: 'auto', padding: '12px 24px' }} disabled={isSaving}>
          {isSaving ? 'Updating Settings...' : 'Update Corporate Settings'}
        </button>
      </form>
    </div>
  );
};

export default GeofencingTimesScreen;
