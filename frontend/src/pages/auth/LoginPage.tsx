import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Eye, EyeOff } from 'lucide-react';
import { authApi } from '../../api/authApi';
import { useAuthStore } from '../../store/authStore';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const setToken = useAuthStore(s => s.setToken);
  const navigate = useNavigate();
  const { t, i18n } = useTranslation();

  const toggleLang = () => {
    const next = i18n.language === 'en' ? 'zh' : 'en';
    i18n.changeLanguage(next);
    localStorage.setItem('lang', next);
  };

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
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
    <div className="relative min-h-screen flex flex-col px-6 bg-white">
      {/* Top bar: logo left, lang toggle right */}
      <div className="flex items-center justify-between pt-5">
        <div className="w-10 h-10 bg-si-red rounded-lg shadow-md" />
        <button
          onClick={toggleLang}
          className="text-xs font-bold px-3 py-1 rounded-full bg-gradient-to-r from-si-red to-orange-400 text-white shadow hover:opacity-90 transition-opacity"
        >
          {i18n.language === 'en' ? '中文' : 'EN'}
        </button>
      </div>

      {/* Centered brand header */}
      <div className="mt-10 mb-8 text-center">
        <h1 className="text-4xl font-black tracking-tight bg-gradient-to-r from-si-red via-orange-500 to-yellow-400 bg-clip-text text-transparent drop-shadow-sm">
          Smart Invest
        </h1>
        <div className="inline-block mt-3 p-[2px] rounded-xl bg-gradient-to-r from-si-red via-orange-400 to-yellow-400">
          <div className="rounded-[10px] bg-white px-5 py-2">
            <p className="text-base font-bold bg-gradient-to-r from-si-red via-orange-500 to-yellow-400 bg-clip-text text-transparent italic tracking-wide whitespace-pre-line leading-relaxed">
              {t('login_tagline')}
            </p>
          </div>
        </div>
      </div>

      {/* Login form */}
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">{t('login_email')}</label>
          <input
            type="email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            onFocus={() => { if (!email) setEmail('demo@smartinvest.com'); }}
            placeholder="demo@smartinvest.com"
            required
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red placeholder-gray-300"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-si-dark mb-1">{t('login_password')}</label>
          <div className="relative">
            <input
              type={showPassword ? 'text' : 'password'}
              value={password}
              onChange={e => setPassword(e.target.value)}
              onFocus={() => { if (!password) setPassword('Demo1234!'); }}
              placeholder="Demo1234!"
              required
              className="w-full border border-si-border rounded-lg px-4 py-3 pr-11 text-sm focus:outline-none focus:ring-2 focus:ring-si-red placeholder-gray-300"
            />
            <button
              type="button"
              onClick={() => setShowPassword(v => !v)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-si-gray transition-colors"
              tabIndex={-1}
              aria-label={showPassword ? 'Hide password' : 'Show password'}
            >
              {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </div>
        </div>
        {error && <p className="text-red-600 text-sm">{error}</p>}
        <button
          type="submit"
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm active:bg-red-700"
        >
          {t('login_submit')}
        </button>
      </form>

      <p className="mt-6 text-center text-sm text-si-gray">
        {t('login_noAccount')} <Link to="/register" className="text-si-red font-medium">{t('login_register')}</Link>
      </p>

      <p className="mt-4 text-center text-sm font-bold text-si-dark tracking-wide">
        {t('login_madeBy')}
      </p>
    </div>
  );
}
