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
          <div className="w-8 h-8 bg-si-red rounded" />
          <span className="font-bold text-si-dark text-sm">Smart Invest</span>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={toggleLang}
            className="text-xs px-2 py-1 rounded border border-si-border text-si-gray hover:bg-si-light transition-colors"
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
