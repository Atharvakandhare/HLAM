import React, { useState, useEffect } from 'react';
import { API_BASE, PREDEFINED_TEAMS } from '../../constants';

const TeamsAdminScreen = ({ token }) => {
  const [teams, setTeams] = useState([]);
  const [users, setUsers] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showTeamModal, setShowTeamModal] = useState(false);
  const [teamForm, setTeamForm] = useState({ type: 'IT Team', customName: '' });

  const fetchData = async () => {
    setIsLoading(true);
    try {
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
      console.error('Error fetching teams:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [token]);

  const handleCreateTeam = async (e) => {
    e.preventDefault();
    const finalName = teamForm.type === 'Other' ? teamForm.customName : teamForm.type;
    if (!finalName) return alert('Team name is required.');

    try {
      const res = await fetch(`${API_BASE}/admin/teams`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ name: finalName })
      });
      if (res.ok) {
        setShowTeamModal(false);
        setTeamForm({ type: 'IT Team', customName: '' });
        fetchData();
        alert('Team created successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to create team');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleRenameTeam = async (id, newName) => {
    try {
      const res = await fetch(`${API_BASE}/admin/teams/${id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ name: newName })
      });
      if (res.ok) {
        fetchData();
        alert('Team renamed successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to rename team');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleDeleteTeam = async (id) => {
    if (!window.confirm('Are you sure you want to delete this team? All members will be unassigned.')) return;
    try {
      const res = await fetch(`${API_BASE}/admin/teams/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        fetchData();
        alert('Team deleted successfully!');
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to delete team');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleAssignTeamRole = async (userId, teamId, roleName, targetRole) => {
    try {
      const payload = { teamId };
      if (targetRole) {
        payload.role = targetRole;
      }
      const res = await fetch(`${API_BASE}/admin/users/${userId}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });
      if (res.ok) {
        fetchData();
        alert(`Team ${roleName} assigned successfully!`);
      } else {
        const data = await res.json();
        alert(data.message || 'Failed to assign team role');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const assignableList = users.filter(u => ['manager', 'team_leader', 'employee'].includes(u.role) && u.isActive);

  if (isLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
        Loading team details...
      </div>
    );
  }

  return (
    <div className="section-box">
      <div className="section-header">
        <h3>Company Teams</h3>
        <button className="btn-action" onClick={() => setShowTeamModal(true)}>Add New Team</button>
      </div>
      <div className="table-wrapper">
        <table className="custom-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Team Name</th>
              <th>Assigned Manager</th>
              <th>Assigned Team Leader</th>
              <th>Active Members Count</th>
              <th>Created At</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {teams.map(t => (
              <tr key={t.id}>
                <td>{t.id}</td>
                <td><strong>{t.name}</strong></td>
                <td>
                  <select
                    value={t.manager?.id || ''}
                    onChange={(e) => {
                      const val = e.target.value;
                      if (val) {
                        handleAssignTeamRole(val, t.id, 'Manager', 'manager');
                      } else if (t.manager?.id) {
                        handleAssignTeamRole(t.manager.id, null, 'Manager');
                      }
                    }}
                    style={{ padding: '6px', borderRadius: '6px', border: '1px solid var(--card-border)', backgroundColor: 'var(--bg-secondary)', color: 'var(--text-primary)' }}
                  >
                    <option value="">-- No Manager --</option>
                    {assignableList.map(m => (
                      <option key={m.id} value={m.id}>
                        {m.name} ({m.email})
                      </option>
                    ))}
                  </select>
                </td>
                <td>
                  <select
                    value={t.teamLeader?.id || ''}
                    onChange={(e) => {
                      const val = e.target.value;
                      if (val) {
                        handleAssignTeamRole(val, t.id, 'Team Leader', 'team_leader');
                      } else if (t.teamLeader?.id) {
                        handleAssignTeamRole(t.teamLeader.id, null, 'Team Leader');
                      }
                    }}
                    style={{ padding: '6px', borderRadius: '6px', border: '1px solid var(--card-border)', backgroundColor: 'var(--bg-secondary)', color: 'var(--text-primary)' }}
                  >
                    <option value="">-- No Team Leader --</option>
                    {assignableList.map(tl => (
                      <option key={tl.id} value={tl.id}>
                        {tl.name} ({tl.email})
                      </option>
                    ))}
                  </select>
                </td>
                <td>
                  <span className="badge employee" style={{ fontSize: '13px', color: 'var(--text-primary)' }}>{t.membersCount ?? 0} members</span>
                </td>
                <td>{new Date(t.createdAt).toLocaleDateString()}</td>
                <td>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <button className="btn-secondary-action" style={{ padding: '6px 10px', fontSize: '12px' }} onClick={() => {
                      const newName = prompt('Enter new team name:', t.name);
                      if (newName && newName.trim()) handleRenameTeam(t.id, newName.trim());
                    }}>✏️ Rename</button>
                    <button className="btn-secondary-action" style={{ padding: '6px 10px', fontSize: '12px', color: 'var(--color-danger)' }} onClick={() => handleDeleteTeam(t.id)}>🗑️ Delete</button>
                  </div>
                </td>
              </tr>
            ))}
            {teams.length === 0 && (
              <tr>
                <td colSpan="7" style={{ textAlign: 'center', color: 'var(--text-secondary)' }}>No teams registered yet.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* TEAM CREATION MODAL */}
      {showTeamModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '440px' }}>
            <div className="modal-header">
              <h3>Create Department Team</h3>
              <button className="modal-close" onClick={() => setShowTeamModal(false)}>×</button>
            </div>
            <form onSubmit={handleCreateTeam}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Select Team Template</label>
                  <select 
                    value={teamForm.type} 
                    onChange={(e) => setTeamForm({ ...teamForm, type: e.target.value })}
                  >
                    {PREDEFINED_TEAMS.map(team => (
                      <option key={team} value={team}>{team}</option>
                    ))}
                    <option value="Other">Other (Custom Name)</option>
                  </select>
                </div>
                {teamForm.type === 'Other' && (
                  <div className="form-group">
                    <label>Custom Team Name</label>
                    <input 
                      type="text" 
                      placeholder="E.g. Logistics Team" 
                      value={teamForm.customName} 
                      onChange={(e) => setTeamForm({ ...teamForm, customName: e.target.value })} 
                      required 
                    />
                  </div>
                )}
              </div>
              <div className="modal-footer">
                <button type="button" className="btn-cancel" onClick={() => setShowTeamModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" style={{ width: 'auto' }}>Save Team</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default TeamsAdminScreen;
