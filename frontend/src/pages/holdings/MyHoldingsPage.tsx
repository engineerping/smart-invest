import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';

export default function MyHoldingsPage() {
  const navigate = useNavigate();
  const { data: holdings = [] } = useQuery({
    queryKey: ['holdings'],
    queryFn: () => apiClient.get('/api/portfolio/me/holdings').then(r => r.data),
  });
  const { data: ordersPage } = useQuery({
    queryKey: ['orders'],
    queryFn: () => apiClient.get('/api/orders').then(r => r.data),
  });
  const pendingCount = ordersPage?.content?.filter((o: any) => o.status === 'PENDING').length ?? 0;

  return (
    <PageLayout title="My Holdings">
      <div className="px-4 py-4 bg-si-light border-b border-si-border">
        <p className="text-xs text-si-gray">Total market value (HKD)</p>
        <p className="text-2xl font-bold text-si-dark mt-1">--</p>
      </div>

      <div className="divide-y divide-si-border">
        <button onClick={() => navigate('/transactions')}
          className="w-full flex items-center justify-between px-4 py-4">
          <span className="text-sm text-si-dark">My transactions</span>
          <div className="flex items-center gap-2">
            {pendingCount > 0 && <span className="bg-amber-500 text-white text-xs px-2 py-0.5 rounded-full">{pendingCount}</span>}
            <span className="text-si-gray">›</span>
          </div>
        </button>
        <button onClick={() => navigate('/plans')}
          className="w-full flex items-center justify-between px-4 py-4">
          <span className="text-sm text-si-dark">My investment plans</span>
          <span className="text-si-gray">›</span>
        </button>
      </div>

      <div className="px-4 py-4">
        {holdings.length === 0 ? (
          <p className="text-sm text-si-gray text-center py-8">No holdings yet</p>
        ) : (
          <div className="space-y-3">
            {holdings.map((h: any) => (
              <div key={h.id} className="border border-si-border rounded-xl p-4">
                <p className="text-sm font-medium text-si-dark">{h.fundId}</p>
                <div className="flex justify-between mt-2 text-xs text-si-gray">
                  <span>Units: {h.totalUnits}</span>
                  <span>Invested: HKD {h.totalInvested}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </PageLayout>
  );
}
