import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { useAuthStore } from '../../store/authStore';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';

export default function SmartInvestHomePage() {
  const logout = useAuthStore(s => s.logout);
  const navigate = useNavigate();
  const { t, i18n } = useTranslation();
  const { data: summary } = useQuery<{ totalMarketValue: number }>({
    queryKey: ['portfolio-summary'],
    queryFn: () => apiClient.get('/api/portfolio/me/summary').then(r => r.data),
  });

  const toggleLang = () => {
    const next = i18n.language === 'en' ? 'zh' : 'en';
    i18n.changeLanguage(next);
    localStorage.setItem('lang', next);
  };

  const fundCategories = [
    { labelKey: 'home_moneyMarket', descKey: 'home_moneyMarketDesc', type: 'MONEY_MARKET' },
    { labelKey: 'home_bondIndex', descKey: 'home_bondIndexDesc', type: 'BOND_INDEX' },
    { labelKey: 'home_equityIndex', descKey: 'home_equityIndexDesc', type: 'EQUITY_INDEX' },
  ];

  return (
    <PageLayout>
      <div className="flex items-center justify-between px-4 py-3 border-b border-si-border">
        <div className="flex items-center gap-2">
          <svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect width="32" height="32" rx="8" fill="url(#logoGrad)"/>
            {/* Bar chart bars */}
            <rect x="6" y="18" width="4" height="8" rx="1.5" fill="white" fillOpacity="0.6"/>
            <rect x="12" y="13" width="4" height="13" rx="1.5" fill="white" fillOpacity="0.8"/>
            <rect x="18" y="9" width="4" height="17" rx="1.5" fill="white"/>
            {/* Upward trend arrow */}
            <polyline points="6,17 12,12 18,8 26,5" stroke="white" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" fillOpacity="0"/>
            <polyline points="22,5 26,5 26,9" stroke="white" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" fillOpacity="0"/>
            <defs>
              <linearGradient id="logoGrad" x1="0" y1="0" x2="32" y2="32" gradientUnits="userSpaceOnUse">
                <stop offset="0%" stopColor="#E8341A"/>
                <stop offset="100%" stopColor="#FF7043"/>
              </linearGradient>
            </defs>
          </svg>
          <span className="font-bold text-si-dark text-sm">Smart Invest</span>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={toggleLang}
            className="text-xs font-bold px-3 py-1 rounded-full bg-gradient-to-r from-si-red to-orange-400 text-white shadow hover:opacity-90 transition-opacity"
          >
            {i18n.language === 'en' ? '中文' : 'EN'}
          </button>
          <button onClick={logout} className="text-xs text-si-gray">{t('signOut')}</button>
        </div>
      </div>

      <div className="px-4 py-5 bg-si-light border-b border-si-border">
        <p className="text-xs text-si-gray">{t('home_totalMarketValue')}</p>
        <p className="text-2xl font-bold text-si-dark mt-1">
          {summary?.totalMarketValue?.toFixed(2) ?? '—'}
        </p>
        <button onClick={() => navigate('/holdings')}
          className="mt-2 text-xs text-si-red font-medium">{t('home_myHoldings')}</button>
      </div>

      <div className="px-4 pt-5">
        <h2 className="text-sm font-semibold text-si-dark mb-3">{t('home_investFunds')}</h2>
        {fundCategories.map(cat => (
          <button key={cat.type}
            onClick={() => navigate(`/funds?type=${cat.type}`)}
            className="w-full flex items-center justify-between px-4 py-3 mb-2 rounded-xl border border-si-border bg-white">
            <div className="text-left">
              <p className="text-sm font-medium text-si-dark">{t(cat.labelKey)}</p>
              <p className="text-xs text-si-gray mt-0.5">{t(cat.descKey)}</p>
            </div>
            <span className="text-si-gray text-lg">›</span>
          </button>
        ))}
      </div>

      <div className="px-4 pt-4">
        <h2 className="text-sm font-semibold text-si-dark mb-3">{t('home_investPortfolios')}</h2>
        <button onClick={() => navigate('/multi-asset')}
          className="w-full flex items-center justify-between px-4 py-3 mb-2 rounded-xl border border-si-border bg-white">
          <div className="text-left">
            <p className="text-sm font-medium text-si-dark">{t('home_multiAsset')}</p>
            <p className="text-xs text-si-gray mt-0.5">{t('home_multiAssetDesc')}</p>
          </div>
          <span className="text-si-gray text-lg">›</span>
        </button>
        <button onClick={() => navigate('/build-portfolio')}
          className="w-full flex items-center justify-between px-4 py-3 mb-2 rounded-xl border border-si-border bg-white">
          <div className="text-left">
            <p className="text-sm font-medium text-si-dark">{t('home_buildPortfolio')}</p>
            <p className="text-xs text-si-gray mt-0.5">{t('home_buildPortfolioDesc')}</p>
          </div>
          <span className="text-si-gray text-lg">›</span>
        </button>
      </div>
    </PageLayout>
  );
}
