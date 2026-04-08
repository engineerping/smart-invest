import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';
import { useAuthStore } from '../../store/authStore';
import type { Fund } from '../../types';

const RISK_COLORS: Record<number, string> = { 4:'bg-yellow-500', 5:'bg-red-500' };

export default function BuildPortfolioPage() {
  const navigate = useNavigate();
  const userRiskLevel = useAuthStore(s => s.user?.riskLevel);

  const { data: funds = [], isLoading } = useQuery<Fund[]>({
    queryKey: ['funds', 'EQUITY_INDEX'],
    queryFn: () => apiClient.get<Fund[]>('/api/funds', { params: { type: 'EQUITY_INDEX' } }).then(r => r.data),
  });

  const canBuild = userRiskLevel === 4 || userRiskLevel === 5;

  return (
    <PageLayout title="Build Your Own Portfolio" showBack>
      <div className="px-4 py-3 bg-si-light border-b border-si-border">
        {canBuild ? (
          <p className="text-xs text-si-gray">Select funds to create your custom portfolio (Risk Level 4–5)</p>
        ) : (
          <div className="text-center py-2">
            <p className="text-xs text-amber-600 font-medium">Your risk level ({userRiskLevel ?? '--'}) does not allow building a custom portfolio.</p>
            <p className="text-xs text-si-gray mt-1">This feature requires Risk Level 4 or 5.</p>
          </div>
        )}
      </div>

      {isLoading ? (
        <div className="flex justify-center py-10 text-si-gray text-sm">Loading…</div>
      ) : (
        <div className="divide-y divide-si-border">
          {funds.map(fund => (
            <button key={fund.id} onClick={() => navigate(`/funds/${fund.id}`)}
              className="w-full text-left px-4 py-4 hover:bg-si-light">
              <div className="flex justify-between items-start">
                <div className="flex-1 pr-4">
                  <p className="text-sm font-medium text-si-dark leading-snug">{fund.name}</p>
                  <p className="text-xs text-si-gray mt-1">{fund.marketFocus}</p>
                  <p className="text-xs text-si-gray">Risk Level {fund.riskLevel}</p>
                </div>
                <div className="text-right shrink-0">
                  <p className="text-sm font-semibold text-si-dark">{fund.currentNav?.toFixed(4) ?? '--'}</p>
                  <p className="text-xs text-si-gray">NAV</p>
                  <span className={`inline-block w-3 h-3 rounded-full mt-1 ${RISK_COLORS[fund.riskLevel] ?? 'bg-gray-300'}`} />
                </div>
              </div>
            </button>
          ))}
        </div>
      )}
    </PageLayout>
  );
}
