import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { authApi } from '../../api/authApi';
import { useAuthStore } from '../../store/authStore';

export default function RegisterPage() {
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const setToken = useAuthStore(s => s.setToken);
  const navigate = useNavigate();
  const { t } = useTranslation();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (password.length < 8) { setError(t('register_errorPassword')); return; }
    try {
      const res = await authApi.register(email, password, fullName);
      setToken(res.data.accessToken);
      navigate('/');
    } catch {
      setError(t('register_errorEmail'));
    }
  };

  return (
    <div className="min-h-screen flex flex-col justify-center px-6 bg-white">
      <div className="mb-8">
        <div className="w-12 h-12 bg-si-red rounded-lg mb-4" />
        <h1 className="text-2xl font-bold text-si-dark">{t('register_title')}</h1>
      </div>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">{t('register_fullName')}</label>
          <input value={fullName} onChange={e => setFullName(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">{t('register_email')}</label>
          <input type="email" value={email} onChange={e => setEmail(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">{t('register_password')}</label>
          <input type="password" value={password} onChange={e => setPassword(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        {error && <p className="text-red-600 text-sm">{error}</p>}
        <button type="submit"
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm active:bg-red-700">
          {t('register_submit')}
        </button>
      </form>
      <p className="mt-6 text-center text-sm text-si-gray">
        {t('register_hasAccount')} <Link to="/login" className="text-si-red font-medium">{t('register_signIn')}</Link>
      </p>

      <p className="mt-4 text-center text-sm text-si-dark">
        github:{' '}
        <a
          href="https://github.com/engineerping/smart-invest"
          target="_blank"
          rel="noopener noreferrer"
          className="text-si-dark hover:underline"
        >
          https://github.com/engineerping/smart-invest
        </a>
      </p>

      <p className="mt-2 text-center text-sm font-bold text-si-dark tracking-wide">
        {t('login_madeBy')}
      </p>
    </div>
  );
}
