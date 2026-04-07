import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import PageLayout from '../../components/PageLayout';

export default function SmartInvestHomePage() {
  const logout = useAuthStore(s => s.logout);
  const navigate = useNavigate();

  return (
    <PageLayout>
      <div className="flex items-center justify-between px-4 py-3 border-b border-si-border">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-si-red rounded" />
          <span className="font-bold text-si-dark text-sm">Smart Invest</span>
        </div>
        <button onClick={logout} className="text-xs text-si-gray">Sign out</button>
      </div>

      <div className="px-4 py-5 bg-si-light border-b border-si-border">
        <p className="text-xs text-si-gray">Total market value (HKD)</p>
        <p className="text-2xl font-bold text-si-dark mt-1">1000</p>
        <button onClick={() => navigate('/holdings')}
          className="mt-2 text-xs text-si-red font-medium">My Holdings ›</button>
      </div>

      <div className="px-4 pt-5">
        <h2 className="text-sm font-semibold text-si-dark mb-3">Invest in individual funds</h2>
        {[
          { label: 'Money Market', desc: 'Stable, low-risk HKD funds', type: 'MONEY_MARKET' },
          { label: 'Bond Index', desc: 'Global investment-grade bonds', type: 'BOND_INDEX' },
          { label: 'Equity Index', desc: 'Global equity index funds', type: 'EQUITY_INDEX' },
        ].map(cat => (
          <button key={cat.type}
            onClick={() => navigate(`/funds?type=${cat.type}`)}
            className="w-full flex items-center justify-between px-4 py-3 mb-2 rounded-xl border border-si-border bg-white">
            <div className="text-left">
              <p className="text-sm font-medium text-si-dark">{cat.label}</p>
              <p className="text-xs text-si-gray mt-0.5">{cat.desc}</p>
            </div>
            <span className="text-si-gray text-lg">›</span>
          </button>
        ))}
      </div>

      <div className="px-4 pt-4">
        <h2 className="text-sm font-semibold text-si-dark mb-3">Invest in portfolios</h2>
        <button onClick={() => navigate('/multi-asset')}
          className="w-full flex items-center justify-between px-4 py-3 mb-2 rounded-xl border border-si-border bg-white">
          <div className="text-left">
            <p className="text-sm font-medium text-si-dark">Multi-asset portfolios</p>
            <p className="text-xs text-si-gray mt-0.5">5 risk levels · World Selection 1–5</p>
          </div>
          <span className="text-si-gray text-lg">›</span>
        </button>
        <button onClick={() => navigate('/build-portfolio')}
          className="w-full flex items-center justify-between px-4 py-3 mb-2 rounded-xl border border-si-border bg-white">
          <div className="text-left">
            <p className="text-sm font-medium text-si-dark">Build your own portfolio</p>
            <p className="text-xs text-si-gray mt-0.5">Risk level 4–5 only</p>
          </div>
          <span className="text-si-gray text-lg">›</span>
        </button>
      </div>
    </PageLayout>
  );
}
