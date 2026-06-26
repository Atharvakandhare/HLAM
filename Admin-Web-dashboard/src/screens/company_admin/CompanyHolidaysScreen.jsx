import React, { useState, useEffect } from 'react';
import { API_BASE } from '../../constants';

const CompanyHolidaysScreen = ({ token }) => {
  const [holidays, setHolidays] = useState([]);
  const [teams, setTeams] = useState([]);
  const [users, setUsers] = useState([]);
  const [parsedHolidays, setParsedHolidays] = useState([]);
  const [selectedHoliday, setSelectedHoliday] = useState(null);
  const [holidayExceptions, setHolidayExceptions] = useState([]);
  const [showExceptionsModal, setShowExceptionsModal] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  const [holidayForm, setHolidayForm] = useState({ name: '', date: '' });
  const [exceptionForm, setExceptionForm] = useState({ targetType: 'team', teamId: '', userId: '' });

  const fetchData = async () => {
    setIsLoading(true);
    try {
      const holidaysRes = await fetch(`${API_BASE}/holidays`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (holidaysRes.ok) {
        const holidaysData = await holidaysRes.json();
        setHolidays(holidaysData.holidays || []);
      }

      const teamsRes = await fetch(`${API_BASE}/admin/teams`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (teamsRes.ok) {
        const teamsData = await teamsRes.json();
        setTeams(teamsData.teams || []);
      }

      const usersRes = await fetch(`${API_BASE}/admin/users`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (usersRes.ok) {
        const usersData = await usersRes.json();
        setUsers(usersData.users || []);
      }
    } catch (err) {
      console.error('Error fetching holidays data:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [token]);

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
        fetchData();
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
      const res = await fetch(`${API_BASE}/holidays/${id}/delete`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        }
      });
      if (res.ok) {
        fetchData();
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
        fetchData();
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
      const res = await fetch(`${API_BASE}/holidays/${selectedHoliday.id}/exceptions/${exceptionId}/delete`, {
        method: 'POST',
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

  if (isLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
        Loading holidays directory...
      </div>
    );
  }

  return (
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
                <button type="button" className="btn-cancel" onClick={() => setParsedHolidays([])}>Clear Preview</button>
                <button type="button" className="btn-primary" onClick={handleConfirmBulkHolidays} style={{ width: 'auto' }}>Confirm & Bulk Save</button>
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
              {holidays.map(h => (
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
              ))}
              {holidays.length === 0 && (
                <tr>
                  <td colSpan="4" style={{ textAlign: 'center', color: 'var(--text-secondary)' }}>No corporate holidays set yet.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* HOLIDAY EXCEPTIONS MODAL */}
      {showExceptionsModal && selectedHoliday && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '520px' }}>
            <div className="modal-header">
              <h3>Manage Exceptions: {selectedHoliday.name}</h3>
              <button className="modal-close" onClick={() => setShowExceptionsModal(false)}>×</button>
            </div>
            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
              <div>
                <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '14px' }}>
                  Add exception rules to allow specific teams or employees to mark attendance on this holiday.
                </p>
                <form onSubmit={handleAddException} style={{ display: 'flex', gap: '10px', alignItems: 'flex-end', flexWrap: 'wrap' }}>
                  <div className="form-group" style={{ flex: 1, minWidth: '130px', margin: 0 }}>
                    <label>Exception Scope</label>
                    <select
                      value={exceptionForm.targetType}
                      onChange={e => setExceptionForm({ ...exceptionForm, targetType: e.target.value, teamId: '', userId: '' })}
                    >
                      <option value="team">👥 Team Scope</option>
                      <option value="user">👤 Individual Staff</option>
                    </select>
                  </div>

                  {exceptionForm.targetType === 'team' ? (
                    <div className="form-group" style={{ flex: 1.5, minWidth: '150px', margin: 0 }}>
                      <label>Select Company Team</label>
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
                    <div className="form-group" style={{ flex: 1.5, minWidth: '150px', margin: 0 }}>
                      <label>Select Colleague</label>
                      <select
                        value={exceptionForm.userId}
                        onChange={e => setExceptionForm({ ...exceptionForm, userId: e.target.value })}
                        required
                      >
                        <option value="">-- Choose Staff --</option>
                        {users.filter(u => u.isActive).map(u => (
                          <option key={u.id} value={u.id}>{u.name} ({u.email})</option>
                        ))}
                      </select>
                    </div>
                  )}
                  <button type="submit" className="btn-primary" style={{ width: 'auto', padding: '12px 20px', height: '45px' }}>Add Exception</button>
                </form>
              </div>

              <div>
                <h4 style={{ fontSize: '14px', marginBottom: '10px' }}>Current Active Rules ({holidayExceptions.length})</h4>
                <div className="table-wrapper" style={{ maxHeight: '200px', overflowY: 'auto' }}>
                  <table className="custom-table" style={{ fontSize: '12px' }}>
                    <thead>
                      <tr>
                        <th>Exception Rule</th>
                        <th>Type</th>
                        <th>Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {holidayExceptions.map(exc => (
                        <tr key={exc.id}>
                          <td>
                            {exc.targetType === 'team' ? (
                              <strong>👥 Team: {exc.team?.name || 'Unknown Team'}</strong>
                            ) : (
                              <strong>👤 Colleague: {exc.user?.name || 'Unknown User'} ({exc.user?.email || 'N/A'})</strong>
                            )}
                          </td>
                          <td>
                            <span className={`badge ${exc.targetType === 'team' ? 'manager' : 'employee'}`} style={{ fontSize: '10px' }}>
                              {exc.targetType}
                            </span>
                          </td>
                          <td>
                            <button
                              type="button"
                              className="btn-secondary-action"
                              style={{ padding: '4px 8px', fontSize: '11px', color: 'var(--color-danger)' }}
                              onClick={() => handleDeleteException(exc.id)}
                            >
                              Remove
                            </button>
                          </td>
                        </tr>
                      ))}
                      {holidayExceptions.length === 0 && (
                        <tr>
                          <td colSpan="3" style={{ textAlign: 'center', color: 'var(--text-secondary)', padding: '12px' }}>No exceptions added. All staff are blocked from check-in.</td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button type="button" className="btn-cancel" onClick={() => setShowExceptionsModal(false)}>Close Exceptions Console</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default CompanyHolidaysScreen;
