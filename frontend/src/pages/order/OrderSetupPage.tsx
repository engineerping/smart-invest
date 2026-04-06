import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';

export default function OrderSetupPage() {
  const [params] = useSearchParams();
  const fundId = params.get('fundId')!;
  const navigate = useNavigate();
  const [orderType, setOrderType] = useState<'ONE_TIME' | 'MONTHLY_PLAN'>('ONE_TIME');
  const [amount, setAmount] = useState('');

  const { data: fund } = useQuery({
    queryKey: ['fund', fundId],
    queryFn: () => apiClient.get(`/api/funds/${fundId}`).then(r => r.data),
  });

  const handleContinue = () => {
    const amt = parseFloat(amount);
    if (isNaN(amt) || amt < 100) return;
    navigate('/order/review', { state: { fundId, orderType, amount: amt } });
  };

  return (
    <PageLayout title="Investment Details" showBack>
      <div className="px-4 py-4">
        <p className="text-sm font-medium text-si-dark mb-4">{fund?.name}</p>

        <div className="flex rounded-lg border border-si-border overflow-hidden mb-5">
          {(['ONE_TIME', 'MONTHLY_PLAN'] as const).map(type => (
            <button key={type} onClick={() => setOrderType(type)}
              className={`flex-1 py-2 text-sm font-medium transition-colors ${orderType === type ? 'bg-si-dark text-white' : 'bg-white text-si-gray'}`}>
              {type === 'ONE_TIME' ? 'One-time' : 'Monthly plan'}
            </button>
          ))}
        </div>

        <div className="mb-4">
          <label className="block text-sm font-medium text-si-dark mb-1">Investment amount (HKD)</label>
          <input type="number" min={100} value={amount}
            onChange={e => setAmount(e.target.value)}
            placeholder="Min. HKD 100"
            className="w-full border border-si-border rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-si-red" />
        </div>

        <div className="flex justify-between text-xs text-si-gray mb-6">
          <span>Management fee</span>
          <span>{fund ? `${(fund.annualMgmtFee * 100).toFixed(2)}% p.a.` : '--'}</span>
        </div>

        <button onClick={handleContinue}
          disabled={!amount || parseFloat(amount) < 100}
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm disabled:bg-gray-200 disabled:text-gray-400">
          Continue
        </button>
      </div>
    </PageLayout>
  );
}
