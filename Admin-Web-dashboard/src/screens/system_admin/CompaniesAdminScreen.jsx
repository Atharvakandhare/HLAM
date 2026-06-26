import React, { useState, useEffect } from 'react';
import { API_BASE, SERVER_BASE } from '../../constants';

const CompaniesAdminScreen = ({ token }) => {
  const [companies, setCompanies] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  // Add Company Modal State
  const [showCompanyModal, setShowCompanyModal] = useState(false);
  const [companyForm, setCompanyForm] = useState({ name: '', adminName: '', adminEmail: '', adminPassword: '' });

  // Rejection Modal State
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [selectedCompanyForReject, setSelectedCompanyForReject] = useState(null);
  const [rejectReason, setRejectReason] = useState('');

  // Manage Admins Modal State
  const [showAdminsModal, setShowAdminsModal] = useState(false);
  const [selectedCompanyForAdmins, setSelectedCompanyForAdmins] = useState(null);
  const [adminsList, setAdminsList] = useState([]);
  const [adminsLoading, setAdminsLoading] = useState(false);

  // Admin CRUD Form State
  const [showAdminCrudModal, setShowAdminCrudModal] = useState(false);
  const [editingAdmin, setEditingAdmin] = useState(null);
  const [adminForm, setAdminForm] = useState({ name: '', email: '', password: '' });

  const fetchCompanies = async () => {
    setIsLoading(true);
    try {
      const res = await fetch(`${API_BASE}/admin/companies`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setCompanies(data.companies || []);
      }
    } catch (err) {
      console.error('Error fetching companies:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchCompanies();
  }, [token]);

  const handleCreateCompany = async (e) => {
    e.preventDefault();
    try {
      const res = await fetch(`${API_BASE}/admin/companies`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(companyForm)
      });
      const data = await res.json();
      if (res.ok) {
        setShowCompanyModal(false);
        setCompanyForm({ name: '', adminName: '', adminEmail: '', adminPassword: '' });
        fetchCompanies();
        alert('Company & initial Admin created successfully!');
      } else {
        alert(data.message || 'Failed to create company');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleApproveCompany = async (id) => {
    if (!window.confirm('Are you sure you want to approve this company?')) return;
    try {
      const res = await fetch(`${API_BASE}/admin/companies/${id}/approve`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        fetchCompanies();
        alert('Company approved and activated successfully.');
      } else {
        alert('Failed to approve company.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const triggerRejectModal = (company) => {
    setSelectedCompanyForReject(company);
    setRejectReason('');
    setShowRejectModal(true);
  };

  const handleRejectCompany = async (e) => {
    e.preventDefault();
    if (!rejectReason.trim()) return alert('Please enter a rejection reason.');
    try {
      const res = await fetch(`${API_BASE}/admin/companies/${selectedCompanyForReject.id}/reject`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ reason: rejectReason })
      });
      if (res.ok) {
        setShowRejectModal(false);
        fetchCompanies();
        alert('Company registration rejected successfully.');
      } else {
        alert('Failed to reject company.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleDeactivateCompany = async (id) => {
    if (!window.confirm('Are you sure you want to deactivate this company? All activities will be blocked.')) return;
    try {
      const res = await fetch(`${API_BASE}/admin/companies/${id}/reject`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ reason: 'Deactivated by System Admin' })
      });
      if (res.ok) {
        fetchCompanies();
        alert('Company deactivated successfully.');
      } else {
        alert('Failed to deactivate company.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  // --- Company Admins Management ---

  const openAdminsModal = async (company) => {
    setSelectedCompanyForAdmins(company);
    setShowAdminsModal(true);
    fetchCompanyAdmins(company.id);
  };

  const fetchCompanyAdmins = async (companyId) => {
    setAdminsLoading(true);
    try {
      const res = await fetch(`${API_BASE}/admin/users?companyId=${companyId}&role=company_admin`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setAdminsList(data.users || []);
      }
    } catch (err) {
      console.error('Error fetching company admins:', err);
    } finally {
      setAdminsLoading(false);
    }
  };

  const openAddAdminModal = () => {
    setEditingAdmin(null);
    setAdminForm({ name: '', email: '', password: '' });
    setShowAdminCrudModal(true);
  };

  const openEditAdminModal = (admin) => {
    setEditingAdmin(admin);
    setAdminForm({ name: admin.name, email: admin.email, password: '' });
    setShowAdminCrudModal(true);
  };

  const handleSaveAdmin = async (e) => {
    e.preventDefault();
    if (!adminForm.name || !adminForm.email) return alert('Name and email are required.');
    if (!editingAdmin && !adminForm.password) return alert('Password is required for new admins.');

    const url = editingAdmin 
      ? `${API_BASE}/admin/users/${editingAdmin.id}` 
      : `${API_BASE}/admin/users`;
    const method = editingAdmin ? 'PUT' : 'POST';

    const payload = {
      ...adminForm,
      role: 'company_admin',
      companyId: selectedCompanyForAdmins.id
    };

    if (editingAdmin && !payload.password) {
      delete payload.password;
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
        setShowAdminCrudModal(false);
        fetchCompanyAdmins(selectedCompanyForAdmins.id);
        fetchCompanies(); // Refresh main dashboard counts
        alert(editingAdmin ? 'Admin updated successfully!' : 'Admin created successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to save admin.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleDeleteAdmin = async (id) => {
    if (!window.confirm('Are you sure you want to deactivate this admin account?')) return;
    try {
      const res = await fetch(`${API_BASE}/admin/users/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        fetchCompanyAdmins(selectedCompanyForAdmins.id);
        fetchCompanies(); // Refresh main dashboard counts
        alert('Admin deactivated successfully.');
      } else {
        alert('Failed to deactivate admin.');
      }
    } catch (err) {
      console.error(err);
    }
  };

  if (isLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
        Loading registered companies...
      </div>
    );
  }

  return (
    <div className="section-box">
      <div className="section-header">
        <h3>Registered Corporations</h3>
        <button className="btn-action" onClick={() => setShowCompanyModal(true)}>Add New Company</button>
      </div>
      <div className="table-wrapper">
        <table className="custom-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Company Name</th>
              <th>Company Admin(s)</th>
              <th>Teams</th>
              <th>Managers</th>
              <th>Team Leaders</th>
              <th>Employees</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {companies.map(c => (
              <tr key={c.id}>
                <td>{c.id}</td>
                <td>
                  <strong>{c.name}</strong>
                  <br/>
                  <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                    {new Date(c.createdAt).toLocaleDateString()}
                  </span>
                </td>
                <td>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {c.admins && c.admins.length > 0 ? (
                      c.admins.map(admin => (
                        <div key={admin.id} style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <img
                            src={admin.profilePicture ? `${SERVER_BASE}${admin.profilePicture}` : "https://avatar.iran.liara.run/public/boy"}
                            alt=""
                            style={{ width: '22px', height: '22px', borderRadius: '50%' }}
                          />
                          <div>
                            <div style={{ fontWeight: '600', fontSize: '12px' }}>{admin.name}</div>
                            <div style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>{admin.email}</div>
                          </div>
                        </div>
                      ))
                    ) : (
                      <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>No admins</span>
                    )}
                    <button 
                      className="btn-secondary-action" 
                      style={{ padding: '4px 8px', fontSize: '11px', alignSelf: 'flex-start', marginTop: '4px' }}
                      onClick={() => openAdminsModal(c)}
                    >
                      🛡️ Manage Admins
                    </button>
                  </div>
                </td>
                <td><span className="badge company_admin" style={{ fontSize: '12px' }}>{c.teamsCount ?? 0}</span></td>
                <td><span className="badge manager" style={{ fontSize: '12px' }}>{c.managersCount ?? 0}</span></td>
                <td><span className="badge team_leader" style={{ fontSize: '12px' }}>{c.teamLeadersCount ?? 0}</span></td>
                <td><span className="badge employee" style={{ fontSize: '12px' }}>{c.employeesCount ?? 0}</span></td>
                <td>
                  <span className={`badge ${c.status === 'approved' && c.isActive ? 'present' : c.status === 'pending' ? 'pending' : 'absent'}`}>
                    {c.status === 'approved' && c.isActive ? 'Active' : c.status === 'pending' ? 'Pending' : 'Suspended'}
                  </span>
                  {c.rejectionReason && c.status === 'rejected' && (
                    <div style={{ fontSize: '10px', color: 'var(--color-danger)', marginTop: '4px', maxWidth: '120px' }}>
                      Reason: {c.rejectionReason}
                    </div>
                  )}
                </td>
                <td>
                  <div style={{ display: 'flex', gap: '6px' }}>
                    {c.status === 'pending' && (
                      <>
                        <button className="btn-action" style={{ padding: '6px 12px', fontSize: '12px' }} onClick={() => handleApproveCompany(c.id)}>Approve</button>
                        <button className="btn-secondary-action" style={{ padding: '6px 12px', fontSize: '12px', color: 'var(--color-danger)', borderColor: 'rgba(244,63,94,0.2)' }} onClick={() => triggerRejectModal(c)}>Reject</button>
                      </>
                    )}
                    {c.status === 'approved' && c.isActive && (
                      <button className="btn-secondary-action" style={{ padding: '6px 12px', fontSize: '12px', color: 'var(--color-danger)' }} onClick={() => handleDeactivateCompany(c.id)}>Deactivate</button>
                    )}
                    {c.status === 'approved' && !c.isActive && (
                      <button className="btn-action" style={{ padding: '6px 12px', fontSize: '12px' }} onClick={() => handleApproveCompany(c.id)}>Activate</button>
                    )}
                    {c.status === 'rejected' && (
                      <button className="btn-action" style={{ padding: '6px 12px', fontSize: '12px' }} onClick={() => handleApproveCompany(c.id)}>Activate</button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
            {companies.length === 0 && (
              <tr>
                <td colSpan="9" style={{ textAlign: 'center', color: 'var(--text-secondary)' }}>No registered companies found.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* NEW COMPANY REGISTRATION MODAL */}
      {showCompanyModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3>Create Corporate Account</h3>
              <button className="modal-close" onClick={() => setShowCompanyModal(false)}>×</button>
            </div>
            <form onSubmit={handleCreateCompany}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Company / Corporation Name</label>
                  <input 
                    type="text" 
                    placeholder="E.g. LyftLabs India" 
                    value={companyForm.name} 
                    onChange={(e) => setCompanyForm({ ...companyForm, name: e.target.value })} 
                    required 
                  />
                </div>
                <div style={{ borderTop: '1px solid var(--card-border)', marginTop: '20px', paddingTop: '20px' }}>
                  <h4 style={{ marginBottom: '14px', fontSize: '14px', color: 'var(--color-primary)' }}>🔑 Initial Admin User Details</h4>
                  <div className="form-group">
                    <label>Admin Representative Name</label>
                    <input 
                      type="text" 
                      placeholder="E.g. Rajesh Kumar" 
                      value={companyForm.adminName} 
                      onChange={(e) => setCompanyForm({ ...companyForm, adminName: e.target.value })} 
                      required 
                    />
                  </div>
                  <div className="form-group">
                    <label>Admin Corporate Email</label>
                    <input 
                      type="email" 
                      placeholder="rajesh.kumar@lyftlabs.in" 
                      value={companyForm.adminEmail} 
                      onChange={(e) => setCompanyForm({ ...companyForm, adminEmail: e.target.value })} 
                      required 
                    />
                  </div>
                  <div className="form-group">
                    <label>Initial Passcode</label>
                    <input 
                      type="password" 
                      placeholder="Set initial password" 
                      value={companyForm.adminPassword} 
                      onChange={(e) => setCompanyForm({ ...companyForm, adminPassword: e.target.value })} 
                      required 
                    />
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn-cancel" onClick={() => setShowCompanyModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" style={{ width: 'auto' }}>Provision Corporate Portal</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* REJECTION REASON DIALOG */}
      {showRejectModal && selectedCompanyForReject && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '440px' }}>
            <div className="modal-header">
              <h3>Reject Registration: {selectedCompanyForReject.name}</h3>
              <button className="modal-close" onClick={() => setShowRejectModal(false)}>×</button>
            </div>
            <form onSubmit={handleRejectCompany}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Reason for Rejection *</label>
                  <textarea 
                    placeholder="E.g. Incomplete credentials, mismatch of documents..." 
                    value={rejectReason} 
                    onChange={e => setRejectReason(e.target.value)} 
                    rows="3" 
                    required 
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn-cancel" onClick={() => setShowRejectModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" style={{ width: 'auto', background: 'var(--color-danger)' }}>Reject Request</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MANAGE COMPANY ADMINS MODAL */}
      {showAdminsModal && selectedCompanyForAdmins && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '640px' }}>
            <div className="modal-header">
              <div>
                <h3>Manage Company Admins</h3>
                <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Company: <strong>{selectedCompanyForAdmins.name}</strong></span>
              </div>
              <button className="modal-close" onClick={() => setShowAdminsModal(false)}>×</button>
            </div>
            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <h4 style={{ margin: 0, fontSize: '15px' }}>Admin Representatives</h4>
                <button className="btn-action" onClick={openAddAdminModal} style={{ padding: '6px 12px', fontSize: '12px' }}>+ Provision Admin</button>
              </div>

              {adminsLoading ? (
                <div style={{ textAlign: 'center', padding: '20px', color: 'var(--text-secondary)' }}>Loading admin users...</div>
              ) : (
                <div className="table-wrapper">
                  <table className="custom-table" style={{ fontSize: '13px' }}>
                    <thead>
                      <tr>
                        <th>Admin Representative</th>
                        <th>Email</th>
                        <th>Status</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {adminsList.map(adm => (
                        <tr key={adm.id}>
                          <td>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                              <img 
                                src={adm.profilePicture ? `${SERVER_BASE}${adm.profilePicture}` : "https://avatar.iran.liara.run/public/boy"} 
                                alt="" 
                                style={{ width: '26px', height: '26px', borderRadius: '50%' }} 
                              />
                              <strong>{adm.name}</strong>
                            </div>
                          </td>
                          <td>{adm.email}</td>
                          <td>
                            <span className={`badge ${adm.isActive ? 'present' : 'absent'}`} style={{ fontSize: '10px' }}>
                              {adm.isActive ? 'Active' : 'Deactivated'}
                            </span>
                          </td>
                          <td>
                            <div style={{ display: 'flex', gap: '6px' }}>
                              <button className="btn-secondary-action" style={{ padding: '4px 8px', fontSize: '11px' }} onClick={() => openEditAdminModal(adm)}>✏️ Edit</button>
                              {adm.isActive && (
                                <button className="btn-secondary-action" style={{ padding: '4px 8px', fontSize: '11px', color: 'var(--color-danger)' }} onClick={() => handleDeleteAdmin(adm.id)}>Deactivate</button>
                              )}
                            </div>
                          </td>
                        </tr>
                      ))}
                      {adminsList.length === 0 && (
                        <tr>
                          <td colSpan="4" style={{ textAlign: 'center', color: 'var(--text-secondary)', padding: '16px' }}>No admin users found for this company.</td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
            <div className="modal-footer">
              <button type="button" className="btn-cancel" onClick={() => setShowAdminsModal(false)}>Close Console</button>
            </div>
          </div>
        </div>
      )}

      {/* ADMIN CRUD MODAL */}
      {showAdminCrudModal && selectedCompanyForAdmins && (
        <div className="modal-overlay" style={{ zIndex: 1010 }}>
          <div className="modal-content" style={{ maxWidth: '440px' }}>
            <div className="modal-header">
              <h3>{editingAdmin ? 'Edit Admin Credentials' : 'Register Corporate Admin'}</h3>
              <button className="modal-close" onClick={() => setShowAdminCrudModal(false)}>×</button>
            </div>
            <form onSubmit={handleSaveAdmin}>
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div className="form-group" style={{ margin: 0 }}>
                  <label>Full Name *</label>
                  <input
                    type="text"
                    value={adminForm.name}
                    onChange={e => setAdminForm({ ...adminForm, name: e.target.value })}
                    placeholder="E.g. Rajesh Kumar"
                    required
                  />
                </div>
                <div className="form-group" style={{ margin: 0 }}>
                  <label>Email Address *</label>
                  <input
                    type="email"
                    value={adminForm.email}
                    onChange={e => setAdminForm({ ...adminForm, email: e.target.value })}
                    placeholder="rajesh.kumar@lyftlabs.in"
                    required
                  />
                </div>
                <div className="form-group" style={{ margin: 0 }}>
                  <label>Passcode {editingAdmin ? '(Leave blank to keep current)' : '*'}</label>
                  <input
                    type="password"
                    value={adminForm.password}
                    onChange={e => setAdminForm({ ...adminForm, password: e.target.value })}
                    placeholder="Set passcode details"
                    required={!editingAdmin}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn-cancel" onClick={() => setShowAdminCrudModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" style={{ width: 'auto' }}>Save Admin</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default CompaniesAdminScreen;
