import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { authApi } from '../../api/authApi';
import { useAuthStore } from '../../store/authStore';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const setToken = useAuthStore(s => s.setToken);
  const navigate = useNavigate();
  const { t, i18n } = useTranslation();

  const toggleLang = () => {
    const next = i18n.language === 'en' ? 'zh' : 'en';
    i18n.changeLanguage(next);
    localStorage.setItem('lang', next);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    try {
      const res = await authApi.login(email, password);
      setToken(res.data.accessToken);
      navigate('/');
    } catch {
      setError(t('login_error'));
    }
  };

  return (
    <div className="relative min-h-screen flex flex-col justify-center px-6 bg-white">
      <div className="absolute top-4 right-6">
        <button
          onClick={toggleLang}
          className="text-xs font-bold px-3 py-1 rounded-full bg-gradient-to-r from-si-red to-orange-400 text-white shadow hover:opacity-90 transition-opacity"
        >
          {i18n.language === 'en' ? '中文' : 'EN'}
        </button>
      </div>
      <div className="mb-8">
        <div className="w-12 h-12 bg-si-red rounded-lg mb-4" />
        <h1 className="text-2xl font-bold text-si-dark">Smart Invest</h1>
        <p className="text-si-gray text-sm mt-1">{t('login_subtitle')}</p>
      </div>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">{t('login_email')}</label>
          <input type="email" value={email} onChange={e => setEmail(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">{t('login_password')}</label>
          <input type="password" value={password} onChange={e => setPassword(e.target.value)} required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>
        {error && <p className="text-red-600 text-sm">{error}</p>}
        <button type="submit"
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm active:bg-red-700">
          {t('login_submit')}
        </button>
      </form>
      <p className="mt-6 text-center text-sm text-si-gray">
        {t('login_noAccount')} <Link to="/register" className="text-si-red font-medium">{t('login_register')}</Link>
      </p>
    </div>
  );
}
