import React, { useState, useEffect } from 'react';
import { API_BASE } from '../../constants';
import AttendanceTable from '../../components/AttendanceTable';

const AttendanceJournalScreen = ({ token }) => {
  const [attendanceRecords, setAttendanceRecords] = useState([]);
  const [teams, setTeams] = useState([]);
  const [attendanceDate, setAttendanceDate] = useState(new Date().toISOString().split('T')[0]);
  const [attendanceMood, setAttendanceMood] = useState('');
  const [attendanceEnergy, setAttendanceEnergy] = useState('');
  const [attendanceTeamView, setAttendanceTeamView] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  const fetchData = async () => {
    setIsLoading(true);
    try {
      // Fetch teams first
      const teamsRes = await fetch(`${API_BASE}/admin/teams`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (teamsRes.ok) {
        const teamsData = await teamsRes.json();
        setTeams(teamsData.teams || []);
      }

      // Fetch attendance tab records
      let query = `?date=${attendanceDate}`;
      if (attendanceMood) query += `&mood=${attendanceMood}`;
      if (attendanceEnergy) query += `&energyLevel=${attendanceEnergy}`;
      const recordsRes = await fetch(`${API_BASE}/attendance${query}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (recordsRes.ok) {
        const recordsData = await recordsRes.json();
        setAttendanceRecords(recordsData.attendance || []);
      }
    } catch (err) {
      console.error('Error fetching attendance records:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [token, attendanceDate, attendanceMood, attendanceEnergy]);

  return (
    <div className="section-box">
      <div className="section-header" style={{ marginBottom: '20px' }}>
        <h3>Employee Attendance Journal</h3>
        <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '600', cursor: 'pointer' }}>
            <input 
              type="checkbox" 
              checked={attendanceTeamView} 
              onChange={e => setAttendanceTeamView(e.target.checked)} 
            />
            Group by Teams
          </label>
        </div>
      </div>

      {/* Filters Bar */}
      <div className="filters-container" style={{ display: 'flex', gap: '16px', flexWrap: 'wrap', padding: '16px', backgroundColor: 'var(--bg-secondary)', borderRadius: '12px', marginBottom: '20px', border: '1px solid var(--card-border)' }}>
        <div className="form-group" style={{ margin: 0, flex: 1, minWidth: '150px' }}>
          <label style={{ fontSize: '11px', fontWeight: 'bold', color: 'var(--text-secondary)' }}>DATE</label>
          <input 
            type="date" 
            value={attendanceDate} 
            onChange={e => setAttendanceDate(e.target.value)} 
          />
        </div>
        <div className="form-group" style={{ margin: 0, flex: 1, minWidth: '150px' }}>
          <label style={{ fontSize: '11px', fontWeight: 'bold', color: 'var(--text-secondary)' }}>FILTER BY MOOD</label>
          <select 
            value={attendanceMood} 
            onChange={e => setAttendanceMood(e.target.value)}
          >
            <option value="">All Moods</option>
            <option value="happy">😊 Happy</option>
            <option value="sad">😢 Sad</option>
            <option value="exhausted">😩 Exhausted</option>
            <option value="angry">😤 Angry</option>
          </select>
        </div>
        <div className="form-group" style={{ margin: 0, flex: 1, minWidth: '150px' }}>
          <label style={{ fontSize: '11px', fontWeight: 'bold', color: 'var(--text-secondary)' }}>FILTER BY ENERGY</label>
          <select 
            value={attendanceEnergy} 
            onChange={e => setAttendanceEnergy(e.target.value)}
          >
            <option value="">All Energy Levels</option>
            <option value="low">🔋 Low</option>
            <option value="medium">🔋🔋 Medium</option>
            <option value="high">🔋🔋🔋 High</option>
          </select>
        </div>
      </div>

      {isLoading ? (
        <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
          Loading records...
        </div>
      ) : attendanceRecords.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
          No attendance records found matching filters for this date.
        </div>
      ) : attendanceTeamView ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          {(() => {
            // Group records by team
            const teamGroups = {};
            teams.forEach(t => {
              teamGroups[t.id] = {
                teamName: t.name,
                managerName: t.manager?.name || 'No Manager Assigned',
                tlName: t.teamLeader?.name || 'No Team Leader Assigned',
                records: []
              };
            });
            teamGroups['unassigned'] = {
              teamName: 'Unassigned Employees (No Team)',
              managerName: 'N/A',
              tlName: 'N/A',
              records: []
            };

            attendanceRecords.forEach(rec => {
              const userTeamId = rec.user?.teamId;
              if (userTeamId && teamGroups[userTeamId]) {
                teamGroups[userTeamId].records.push(rec);
              } else {
                teamGroups['unassigned'].records.push(rec);
              }
            });

            return Object.entries(teamGroups)
              .filter(([_, group]) => group.records.length > 0)
              .map(([id, group]) => (
                <details key={id} className="team-collapse-card" open style={{ backgroundColor: 'white', border: '1px solid var(--card-border)', borderRadius: '12px', padding: '16px' }}>
                  <summary style={{ cursor: 'pointer', fontWeight: 'bold', fontSize: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <span>👥 {group.teamName}</span>
                      <span style={{ fontSize: '12px', color: 'var(--text-secondary)', marginLeft: '12px', fontWeight: 'normal' }}>
                        Manager: <strong>{group.managerName}</strong> | TL: <strong>{group.tlName}</strong>
                      </span>
                    </div>
                    <span className="badge employee" style={{ color: 'var(--text-primary)' }}>{group.records.length} records</span>
                  </summary>
                  <div style={{ marginTop: '16px' }}>
                    <AttendanceTable records={group.records} />
                  </div>
                </details>
              ));
          })()}
        </div>
      ) : (
        <AttendanceTable records={attendanceRecords} />
      )}
    </div>
  );
};

export default AttendanceJournalScreen;
