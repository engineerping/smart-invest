import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { authApi } from '../../api/authApi';
import { useAuthStore } from '../../store/authStore';

export default function RegisterPage() {
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const setToken = useAuthStore(s => s.setToken);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (password.length < 8) { setError('Password must be at least 8 characters.'); return; }
    try {
      const res = await authApi.register(email, password, fullName);
      setToken(res.data.accessToken);
      navigate('/');
    } catch {
      setError('Registration failed. Email may already be in use.');
    }
  };

  return (
    <div className="min-h-screen flex flex-col justify-center px-6 bg-white">
      <div className="mb-8">
        <div className="w-12 h-12 bg-si-red rounded-lg mb-4" />
        <h1 className="text-2xl font-bold text-si-dark">Create Account</h1>
      </div>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">Full Name</label>
          <input value={fullName} onChange={e => setFullName(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">Email</label>
          <input type="email" value={email} onChange={e => setEmail(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">Password</label>
          <input type="password" value={password} onChange={e => setPassword(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        {error && <p className="text-red-600 text-sm">{error}</p>}
        <button type="submit"
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm active:bg-red-700">
          Register
        </button>
      </form>
      <p className="mt-6 text-center text-sm text-si-gray">
        Have an account? <Link to="/login" className="text-si-red font-medium">Sign in</Link>
      </p>
    </div>
  );
}
