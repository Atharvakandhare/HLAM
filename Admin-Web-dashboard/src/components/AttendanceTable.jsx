import React from 'react';
import { SERVER_BASE } from '../constants';

const AttendanceTable = ({ records }) => {
  return (
    <div className="table-wrapper">
      <table className="custom-table">
        <thead>
          <tr>
            <th>Employee</th>
            <th>Live Selfie</th>
            <th>Login Spot (In / Out)</th>
            <th>Mood / Energy</th>
            <th>Distance</th>
            <th>Status</th>
            <th>Working Hours</th>
          </tr>
        </thead>
        <tbody>
          {records.map(rec => {
            const moodEmoji = rec.mood === 'happy' ? '😊 Happy' : rec.mood === 'sad' ? '😢 Sad' : rec.mood === 'exhausted' ? '😩 Exhausted' : rec.mood === 'angry' ? '😤 Angry' : rec.mood;
            const energyEmoji = rec.energyLevel === 'low' ? '🔋 Low' : rec.energyLevel === 'medium' ? '🔋🔋 Medium' : rec.energyLevel === 'high' ? '🔋🔋🔋 High' : rec.energyLevel;
            return (
              <tr key={rec.id}>
                <td>
                  <strong>{rec.user?.name || 'Unknown'}</strong>
                  <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>ID: {rec.user?.employeeId || 'N/A'}</div>
                </td>
                <td>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    {rec.selfieUrl ? (
                      <a href={`${SERVER_BASE}${rec.selfieUrl}`} target="_blank" rel="noopener noreferrer">
                        <img src={`${SERVER_BASE}${rec.selfieUrl}`} alt="In" style={{ width: '40px', height: '40px', borderRadius: '8px', objectFit: 'cover', border: '1px solid var(--card-border)' }} />
                      </a>
                    ) : '—'}
                    {rec.checkoutSelfieUrl ? (
                      <a href={`${SERVER_BASE}${rec.checkoutSelfieUrl}`} target="_blank" rel="noopener noreferrer">
                        <img src={`${SERVER_BASE}${rec.checkoutSelfieUrl}`} alt="Out" style={{ width: '40px', height: '40px', borderRadius: '8px', objectFit: 'cover', border: '1px solid var(--card-border)' }} />
                      </a>
                    ) : null}
                  </div>
                </td>
                <td>
                  <div>
                    <span style={{ color: 'var(--color-success)', fontWeight: 'bold' }}>↳ IN:</span>{' '}
                    <span style={{ fontSize: '12px' }}>{rec.checkInTime ? new Date(rec.checkInTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '—'}</span>
                    {rec.address && <div style={{ fontSize: '10px', color: 'var(--text-secondary)', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={rec.address}>{rec.address}</div>}
                  </div>
                  {rec.checkOutTime && (
                    <div style={{ marginTop: '4px' }}>
                      <span style={{ color: 'var(--color-danger)', fontWeight: 'bold' }}>↱ OUT:</span>{' '}
                      <span style={{ fontSize: '12px' }}>{new Date(rec.checkOutTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                      {rec.checkoutAddress && <div style={{ fontSize: '10px', color: 'var(--text-secondary)', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={rec.checkoutAddress}>{rec.checkoutAddress}</div>}
                    </div>
                  )}
                </td>
                <td>
                  {rec.mood && <span className="badge" style={{ backgroundColor: 'var(--bg-secondary)', color: 'var(--text-primary)', marginRight: '6px', textTransform: 'none' }}>{moodEmoji}</span>}
                  {rec.energyLevel && <span className="badge" style={{ backgroundColor: 'var(--bg-secondary)', color: 'var(--text-primary)', textTransform: 'none' }}>{energyEmoji}</span>}
                  {!rec.mood && !rec.energyLevel && '—'}
                </td>
                <td>
                  {rec.distanceFromOffice !== null && rec.distanceFromOffice !== undefined ? (
                    <span className={`badge ${rec.distanceFromOffice < 100 ? 'present' : 'warning'}`} style={{ fontWeight: 'bold' }}>
                      {rec.distanceFromOffice < 100
                        ? 'In Zone'
                        : rec.distanceFromOffice < 1000
                          ? `${rec.distanceFromOffice}m away`
                          : `${(rec.distanceFromOffice / 1000).toFixed(2)}km away`}
                    </span>
                  ) : '—'}
                </td>
                <td>
                  <span className={`badge ${rec.status}`}>{rec.status.toUpperCase()}</span>
                </td>
                <td>
                  <strong style={{ fontFamily: 'monospace' }}>{rec.workingHours || '—'}</strong>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};

export default AttendanceTable;
