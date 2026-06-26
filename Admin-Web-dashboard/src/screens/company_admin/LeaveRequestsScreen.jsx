import React, { useState, useEffect } from 'react';
import { API_BASE } from '../../constants';

const LeaveRequestsScreen = ({ token }) => {
  const [leaves, setLeaves] = useState([]);
  const [selectedLeave, setSelectedLeave] = useState(null);
  const [selectedLeaveQuota, setSelectedLeaveQuota] = useState(null);
  const [showLeaveModal, setShowLeaveModal] = useState(false);
  const [leaveComment, setLeaveComment] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  const fetchData = async () => {
    setIsLoading(true);
    try {
      const res = await fetch(`${API_BASE}/leaves/admin`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setLeaves(data.leaves || []);
      }
    } catch (err) {
      console.error('Error fetching leaves:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [token]);

  const handleLeaveAction = async (approved) => {
    if (!selectedLeave) return;
    const status = approved ? 'approved' : 'rejected';
    try {
      const res = await fetch(`${API_BASE}/leaves/admin/${selectedLeave.id}`, {
        method: 'POST',
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
        fetchData();
        alert(`Leave request successfully ${status}!`);
      } else {
        alert('Failed to process leave request.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  if (isLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
        Loading leave applications...
      </div>
    );
  }

  return (
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
              <th>Paid Days</th>
              <th>Borrowed</th>
              <th>Unpaid</th>
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
                <td>{l.status === 'approved' ? (l.paidDays || 0) : '—'}</td>
                <td>{l.status === 'approved' ? (l.nextMonthPaidDays || 0) : '—'}</td>
                <td>{l.status === 'approved' ? (l.unpaidDays || 0) : '—'}</td>
                <td><span className={`badge ${l.status}`}>{l.status}</span></td>
                <td>
                  {l.status === 'pending' ? (
                    <button className="btn-action" style={{ padding: '6px 12px', fontSize: '12px' }} onClick={async () => {
                      setSelectedLeave(l);
                      setShowLeaveModal(true);
                      setSelectedLeaveQuota(null);
                      try {
                        const res = await fetch(`${API_BASE}/leaves/quota`, {
                          method: 'POST',
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': `Bearer ${token}`
                          },
                          body: JSON.stringify({ userId: l.userId })
                        });
                        if (res.ok) {
                          const data = await res.json();
                          setSelectedLeaveQuota(data.quota);
                        }
                      } catch (err) {
                        console.error(err);
                      }
                    }}>Review</button>
                  ) : (
                    <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Processed</span>
                  )}
                </td>
              </tr>
            ))}
            {leaves.length === 0 && (
              <tr>
                <td colSpan="10" style={{ textAlign: 'center', color: 'var(--text-secondary)' }}>No leave requests found.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

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

              <div style={{ padding: '14px', backgroundColor: 'var(--bg-secondary)', borderRadius: '12px', marginBottom: '20px', border: '1px solid var(--card-border)' }}>
                <h4 style={{ fontSize: '13px', color: 'var(--color-primary)', marginBottom: '10px' }}>Paid Leave Allocation Details</h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', fontSize: '13px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: 'var(--text-secondary)' }}>Requested as Paid:</span>
                    <strong style={{ color: selectedLeave.isPaidRequest ? 'var(--color-success)' : 'inherit' }}>{selectedLeave.isPaidRequest ? 'Yes' : 'No'}</strong>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: 'var(--text-secondary)' }}>Borrow Next Month:</span>
                    <strong>{selectedLeave.allowNextMonthQuota ? 'Yes' : 'No'}</strong>
                  </div>
                  {selectedLeaveQuota && (
                    <>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <span style={{ color: 'var(--text-secondary)' }}>Available (This Month):</span>
                        <strong>{selectedLeaveQuota.availableThisMonth} Days</strong>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <span style={{ color: 'var(--text-secondary)' }}>Available (Next Month):</span>
                        <strong>{selectedLeaveQuota.availableNextMonth} Days</strong>
                      </div>
                    </>
                  )}
                  {(() => {
                    const start = new Date(selectedLeave.startDate);
                    const end = new Date(selectedLeave.endDate);
                    const totalDays = Math.floor((end - start) / (1000 * 60 * 60 * 24)) + 1;
                    let paid = 0, borrowed = 0, unpaid = totalDays;
                    if (selectedLeave.isPaidRequest) {
                      const availableThisMonth = selectedLeaveQuota ? selectedLeaveQuota.availableThisMonth : 0;
                      const availableNextMonth = selectedLeaveQuota ? selectedLeaveQuota.availableNextMonth : 0;
                      if (totalDays <= availableThisMonth) {
                        paid = totalDays;
                        borrowed = 0;
                        unpaid = 0;
                      } else {
                        paid = availableThisMonth;
                        const rem = totalDays - availableThisMonth;
                        if (selectedLeave.allowNextMonthQuota) {
                          borrowed = Math.min(rem, availableNextMonth);
                          unpaid = rem - borrowed;
                        } else {
                          borrowed = 0;
                          unpaid = rem;
                        }
                      }
                    }
                    return (
                      <div style={{ marginTop: '10px', borderTop: '1px solid var(--card-border)', paddingTop: '8px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                          <span style={{ fontWeight: 'bold' }}>Expected Allocation:</span>
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                          <span>Paid Days:</span>
                          <strong style={{ color: 'var(--color-success)' }}>{paid} Days</strong>
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                          <span>Borrowed Days:</span>
                          <strong style={{ color: 'var(--color-primary)' }}>{borrowed} Days</strong>
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                          <span>Unpaid Days:</span>
                          <strong style={{ color: 'var(--color-danger)' }}>{unpaid} Days</strong>
                        </div>
                      </div>
                    );
                  })()}
                </div>
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
              <button type="button" className="btn-cancel" style={{ color: 'var(--color-danger)', borderColor: 'rgba(244, 63, 94, 0.2)' }} onClick={() => handleLeaveAction(false)}>Reject Application</button>
              <button type="button" className="btn-primary" style={{ width: 'auto' }} onClick={() => handleLeaveAction(true)}>Approve Application</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default LeaveRequestsScreen;
