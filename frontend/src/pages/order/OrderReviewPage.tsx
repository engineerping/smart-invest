import { useNavigate, useLocation } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';

export default function OrderReviewPage() {
  const { state } = useLocation();
  const { fundId, orderType, amount } = state as { fundId: string; orderType: string; amount: number };
  const navigate = useNavigate();

  const { data: fund } = useQuery({
    queryKey: ['fund', fundId],
    queryFn: () => apiClient.get(`/api/funds/${fundId}`).then(r => r.data),
  });

  return (
    <PageLayout title="Review" showBack>
      <div className="px-4 py-4 space-y-3 text-sm">
        <div className="flex justify-between py-2 border-b border-si-border">
          <span className="text-si-gray">Fund</span>
          <span className="font-medium text-right max-w-[55%]">{fund?.name}</span>
        </div>
        <div className="flex justify-between py-2 border-b border-si-border">
          <span className="text-si-gray">Order type</span>
          <span className="font-medium">{orderType === 'ONE_TIME' ? 'One-time' : 'Monthly plan'}</span>
        </div>
        <div className="flex justify-between py-2 border-b border-si-border">
          <span className="text-si-gray">Amount</span>
          <span className="font-medium">HKD {amount.toLocaleString()}</span>
        </div>
        <div className="flex justify-between py-2 border-b border-si-border">
          <span className="text-si-gray">Settlement</span>
          <span className="font-medium">T+2 business days</span>
        </div>
      </div>

      <div className="px-4 pt-4">
        <p className="text-xs text-si-gray mb-4">
          By proceeding, you confirm you have read and agree to the Terms and Conditions governing this investment.
        </p>
        <button onClick={() => navigate('/order/terms', { state })}
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm">
          Read Terms & Conditions
        </button>
      </div>
    </PageLayout>
  );
}
