import { useNavigate, useSearchParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';
import type { Fund } from '../../types';

const RISK_COLORS: Record<number, string> = { 1:'bg-gray-400', 2:'bg-blue-900', 3:'bg-blue-500', 4:'bg-yellow-500', 5:'bg-red-500' };

export default function FundListPage() {
  const [params] = useSearchParams();
  const type = params.get('type') ?? undefined;
  const navigate = useNavigate();

  const { data: funds = [], isLoading } = useQuery({
    queryKey: ['funds', type],
    queryFn: () => apiClient.get<Fund[]>('/api/funds', { params: { type } }).then(r => r.data),
  });

  return (
    <PageLayout title="Funds" showBack>
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
