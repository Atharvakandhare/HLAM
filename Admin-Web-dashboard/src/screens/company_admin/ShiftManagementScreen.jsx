import React, { useState, useEffect } from 'react';
import { API_BASE } from '../../constants';

const ShiftManagementScreen = ({ token }) => {
  const [shifts, setShifts] = useState([]);
  const [users, setUsers] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  // Shift Modal State
  const [showShiftModal, setShowShiftModal] = useState(false);
  const [editingShift, setEditingShift] = useState(null);
  const [shiftForm, setShiftForm] = useState({
    name: '',
    checkInTime: '09:00:00',
    checkOutTime: '18:00:00',
    lateInLimit: 15,
    lateOutLimit: 15,
    earlyInLimit: 15,
    earlyOutLimit: 15
  });

  // Assign Modal State
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [assignForm, setAssignForm] = useState({ userId: '', shiftId: '' });
  const [isSaving, setIsSaving] = useState(false);

  const fetchData = async () => {
    setIsLoading(true);
    try {
      // Fetch shifts via POST /api/shifts/list
      const shiftsRes = await fetch(`${API_BASE}/shifts/list`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (shiftsRes.ok) {
        const shiftsData = await shiftsRes.json();
        setShifts(shiftsData.shifts || []);
      }

      // Fetch users
      const usersRes = await fetch(`${API_BASE}/admin/users`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (usersRes.ok) {
        const usersData = await usersRes.json();
        setUsers(usersData.users || []);
      }
    } catch (err) {
      console.error('Error fetching shift data:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [token]);

  const openAddShiftModal = () => {
    setEditingShift(null);
    setShiftForm({
      name: '',
      checkInTime: '09:00:00',
      checkOutTime: '18:00:00',
      lateInLimit: 15,
      lateOutLimit: 15,
      earlyInLimit: 15,
      earlyOutLimit: 15
    });
    setShowShiftModal(true);
  };

  const openEditShiftModal = (shift) => {
    setEditingShift(shift);
    setShiftForm({
      name: shift.name,
      checkInTime: shift.checkInTime ? shift.checkInTime.slice(0, 8) : '09:00:00',
      checkOutTime: shift.checkOutTime ? shift.checkOutTime.slice(0, 8) : '18:00:00',
      lateInLimit: shift.lateInLimit || 15,
      lateOutLimit: shift.lateOutLimit || 15,
      earlyInLimit: shift.earlyInLimit || 15,
      earlyOutLimit: shift.earlyOutLimit || 15
    });
    setShowShiftModal(true);
  };

  const handleSaveShift = async (e) => {
    e.preventDefault();
    if (!shiftForm.name || !shiftForm.checkInTime || !shiftForm.checkOutTime) {
      return alert('Name, check-in, and check-out times are required.');
    }

    const url = editingShift 
      ? `${API_BASE}/admin/shifts/update` 
      : `${API_BASE}/admin/shifts/create`;

    const payload = {
      ...shiftForm
    };

    if (editingShift) {
      payload.id = editingShift.id;
    }

    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });
      if (res.ok) {
        setShowShiftModal(false);
        fetchData();
        alert(editingShift ? 'Shift updated successfully!' : 'Shift created successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to save shift.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleDeleteShift = async (id) => {
    if (!window.confirm('Are you sure you want to deactivate/delete this shift?')) return;
    try {
      const res = await fetch(`${API_BASE}/admin/shifts/delete`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ id })
      });
      if (res.ok) {
        fetchData();
        alert('Shift deleted successfully.');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to delete shift.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const openAssignModal = () => {
    setAssignForm({ userId: '', shiftId: '' });
    setShowAssignModal(true);
  };

  const handleAssignShift = async (e) => {
    e.preventDefault();
    if (!assignForm.userId) return alert('Please select an employee.');
    setIsSaving(true);
    try {
      const res = await fetch(`${API_BASE}/admin/shifts/assign`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          userId: parseInt(assignForm.userId),
          shiftId: assignForm.shiftId ? parseInt(assignForm.shiftId) : null
        })
      });
      if (res.ok) {
        setShowAssignModal(false);
        fetchData();
        alert('Shift assigned successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to assign shift.');
      }
    } catch (err) {
      console.error(err);
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
        Loading shifts configuration...
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      <div className="section-box">
        <div className="section-header">
          <h3>Shift Directories</h3>
          <div style={{ display: 'flex', gap: '10px' }}>
            <button className="btn-secondary-action" onClick={openAssignModal}>👤 Assign Shift</button>
            <button className="btn-action" onClick={openAddShiftModal}>+ Add New Shift</button>
          </div>
        </div>
        <div className="table-wrapper">
          <table className="custom-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Shift Name</th>
                <th>Check-in / Check-out</th>
                <th>Late limits (In/Out)</th>
                <th>Early limits (In/Out)</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {shifts.map(s => (
                <tr key={s.id}>
                  <td>{s.id}</td>
                  <td><strong>{s.name}</strong></td>
                  <td>
                    <span style={{ color: 'var(--color-success)', fontWeight: 'bold' }}>↳ {s.checkInTime.slice(0, 5)}</span>
                    {' — '}
                    <span style={{ color: 'var(--color-danger)', fontWeight: 'bold' }}>↱ {s.checkOutTime.slice(0, 5)}</span>
                  </td>
                  <td>{s.lateInLimit}m / {s.lateOutLimit}m</td>
                  <td>{s.earlyInLimit}m / {s.earlyOutLimit}m</td>
                  <td>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button className="btn-secondary-action" style={{ padding: '6px 10px', fontSize: '12px' }} onClick={() => openEditShiftModal(s)}>✏️ Edit</button>
                      <button className="btn-secondary-action" style={{ padding: '6px 10px', fontSize: '12px', color: 'var(--color-danger)' }} onClick={() => handleDeleteShift(s.id)}>🗑️ Delete</button>
                    </div>
                  </td>
                </tr>
              ))}
              {shifts.length === 0 && (
                <tr>
                  <td colSpan="6" style={{ textAlign: 'center', color: 'var(--text-secondary)' }}>No corporate shifts configured yet.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* SHIFT CREATION / EDITION MODAL */}
      {showShiftModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3>{editingShift ? 'Edit Shift Details' : 'Configure New Shift'}</h3>
              <button className="modal-close" onClick={() => setShowShiftModal(false)}>×</button>
            </div>
            <form onSubmit={handleSaveShift}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Shift Identifier Name *</label>
                  <input
                    type="text"
                    placeholder="E.g. Morning Shift"
                    value={shiftForm.name}
                    onChange={e => setShiftForm({ ...shiftForm, name: e.target.value })}
                    required
                  />
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label>Shift Check-in Time *</label>
                    <input
                      type="time"
                      step="1"
                      value={shiftForm.checkInTime.slice(0, 5)}
                      onChange={e => setShiftForm({ ...shiftForm, checkInTime: e.target.value + ":00" })}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label>Shift Check-out Time *</label>
                    <input
                      type="time"
                      step="1"
                      value={shiftForm.checkOutTime.slice(0, 5)}
                      onChange={e => setShiftForm({ ...shiftForm, checkOutTime: e.target.value + ":00" })}
                      required
                    />
                  </div>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label>Late Check-in Limit (Minutes)</label>
                    <input
                      type="number"
                      value={shiftForm.lateInLimit}
                      onChange={e => setShiftForm({ ...shiftForm, lateInLimit: parseInt(e.target.value) || 0 })}
                    />
                  </div>
                  <div className="form-group">
                    <label>Late Check-out Limit (Minutes)</label>
                    <input
                      type="number"
                      value={shiftForm.lateOutLimit}
                      onChange={e => setShiftForm({ ...shiftForm, lateOutLimit: parseInt(e.target.value) || 0 })}
                    />
                  </div>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label>Early Check-in Limit (Minutes)</label>
                    <input
                      type="number"
                      value={shiftForm.earlyInLimit}
                      onChange={e => setShiftForm({ ...shiftForm, earlyInLimit: parseInt(e.target.value) || 0 })}
                    />
                  </div>
                  <div className="form-group">
                    <label>Early Check-out Limit (Minutes)</label>
                    <input
                      type="number"
                      value={shiftForm.earlyOutLimit}
                      onChange={e => setShiftForm({ ...shiftForm, earlyOutLimit: parseInt(e.target.value) || 0 })}
                    />
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn-cancel" onClick={() => setShowShiftModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" style={{ width: 'auto' }}>Save Shift</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* SHIFT ASSIGNMENT MODAL */}
      {showAssignModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '440px' }}>
            <div className="modal-header">
              <h3>Assign Default Shift</h3>
              <button className="modal-close" onClick={() => setShowAssignModal(false)}>×</button>
            </div>
            <form onSubmit={handleAssignShift}>
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div className="form-group" style={{ margin: 0 }}>
                  <label>Select Employee *</label>
                  <select
                    value={assignForm.userId}
                    onChange={e => setAssignForm({ ...assignForm, userId: e.target.value })}
                    required
                  >
                    <option value="">-- Choose Employee --</option>
                    {users.filter(u => u.isActive).map(u => (
                      <option key={u.id} value={u.id}>{u.name} ({u.email})</option>
                    ))}
                  </select>
                </div>
                <div className="form-group" style={{ margin: 0 }}>
                  <label>Select Default Shift</label>
                  <select
                    value={assignForm.shiftId}
                    onChange={e => setAssignForm({ ...assignForm, shiftId: e.target.value })}
                  >
                    <option value="">-- No Shift (Clear / Settings Default) --</option>
                    {shifts.map(s => (
                      <option key={s.id} value={s.id}>{s.name} ({s.checkInTime.slice(0, 5)} - {s.checkOutTime.slice(0, 5)})</option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn-cancel" onClick={() => setShowAssignModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" style={{ width: 'auto' }} disabled={isSaving}>
                  {isSaving ? 'Assigning...' : 'Confirm Assignment'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default ShiftManagementScreen;
