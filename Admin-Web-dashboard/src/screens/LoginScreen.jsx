import React, { useState } from 'react';
import { API_BASE } from '../constants';

const LoginScreen = ({ setToken, setUser }) => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loginError, setLoginError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleLoginSubmit = async (e) => {
    e.preventDefault();
    setLoginError('');
    setIsLoading(true);

    try {
      const res = await fetch(`${API_BASE}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      const data = await res.json();
      
      if (res.ok) {
        if (['system_admin', 'company_admin'].includes(data.user.role)) {
          localStorage.setItem('admin_token', data.token);
          setToken(data.token);
          setUser(data.user);
        } else {
          setLoginError('Access denied. Only system and company administrators are allowed.');
        }
      } else {
        setLoginError(data.message || 'Login failed. Please check credentials.');
      }
    } catch (err) {
      console.error(err);
      setLoginError('Server connection error. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="login-wrapper">
      <div className="login-card">
        <div className="login-header">
          <h2>HireLyft Panel</h2>
          <p>Enter your administrator credentials to login.</p>
        </div>
        {loginError && <div className="error-message">{loginError}</div>}
        <form onSubmit={handleLoginSubmit}>
          <div className="form-group">
            <label>Email Address</label>
            <input 
              type="email" 
              placeholder="admin@hirelyft.in" 
              value={email} 
              onChange={(e) => setEmail(e.target.value)} 
              required 
              disabled={isLoading}
            />
          </div>
          <div className="form-group">
            <label>Password</label>
            <input 
              type="password" 
              placeholder="••••••••" 
              value={password} 
              onChange={(e) => setPassword(e.target.value)} 
              required 
              disabled={isLoading}
            />
          </div>
          <button type="submit" className="btn-primary" disabled={isLoading}>
            {isLoading ? 'Signing In...' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
};

export default LoginScreen;
