import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';
import RiskGauge from '../../components/RiskGauge';
import NavChart from '../../components/NavChart';

const TABS = ['Overview', 'Holdings', 'Risk'];

interface TopHolding { holdingName: string; weight: number; }

export default function FundDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [tab, setTab] = useState('Overview');
  const navigate = useNavigate();

  const { data: fund } = useQuery({
    queryKey: ['fund', id],
    queryFn: () => apiClient.get(`/api/funds/${id}`).then(r => r.data),
    enabled: !!id,
  });

  const { data: topHoldings = [] } = useQuery<TopHolding[]>({
    queryKey: ['fund', id, 'top-holdings'],
    queryFn: () => apiClient.get(`/api/funds/${id}/top-holdings`).then(r => r.data),
    enabled: !!id,
  });

  if (!fund) return <div className="flex justify-center py-10 text-sm text-si-gray">Loading…</div>;

  return (
    <PageLayout title={fund.name} showBack>
      <div className="px-4 py-4 border-b border-si-border">
        <p className="text-xs text-si-gray">Current NAV (HKD)</p>
        <p className="text-2xl font-bold text-si-dark">{fund.currentNav?.toFixed(4) ?? '--'}</p>
        <p className="text-xs text-si-gray mt-1">{fund.navDate}</p>
      </div>

      <div className="flex border-b border-si-border">
        {TABS.map(t => (
          <button key={t} onClick={() => setTab(t)}
            className={`flex-1 py-2 text-sm font-medium ${tab === t ? 'border-b-2 border-si-red text-si-red' : 'text-si-gray'}`}>
            {t}
          </button>
        ))}
      </div>

      {tab === 'Overview' && (
        <div>
          <NavChart fundId={fund.id} chartLabel="Cumulative return (%)" />
          <div className="px-4 py-3 space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-si-gray">Management fee</span>
              <span className="font-medium">{(fund.annualMgmtFee * 100).toFixed(2)}% p.a.</span>
            </div>
            <div className="flex justify-between">
              <span className="text-si-gray">Min. investment</span>
              <span className="font-medium">HKD {fund.minInvestment?.toFixed(0)}</span>
            </div>
            {fund.benchmarkIndex && (
              <div className="flex justify-between">
                <span className="text-si-gray">Benchmark</span>
                <span className="font-medium text-right max-w-[55%]">{fund.benchmarkIndex}</span>
              </div>
            )}
          </div>
        </div>
      )}

      {tab === 'Risk' && <RiskGauge productRiskLevel={fund.riskLevel} userRiskLevel={3} />}

      {tab === 'Holdings' && (
        <div className="px-4 py-4">
          {topHoldings.length === 0 ? (
            <p className="text-sm text-si-gray text-center py-8">No holdings data available</p>
          ) : (
            <div className="space-y-2">
              {topHoldings.map((h, i) => (
                <div key={i} className="flex justify-between items-center py-2 border-b border-si-border last:border-0">
                  <span className="text-sm text-si-dark">{h.holdingName}</span>
                  <span className="text-sm font-medium text-si-dark">{h.weight?.toFixed(2)}%</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      <div className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-[430px] p-4 bg-white border-t border-si-border">
        <button onClick={() => navigate(`/order?fundId=${fund.id}`)}
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm active:bg-red-700">
          Invest now
        </button>
      </div>
    </PageLayout>
  );
}
