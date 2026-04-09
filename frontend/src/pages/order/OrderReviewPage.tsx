import { useNavigate, useLocation } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';

export default function OrderReviewPage() {
  const { state } = useLocation();
  const { fundId, orderType, amount } = state as { fundId: string; orderType: string; amount: number };
  const navigate = useNavigate();
  const { t } = useTranslation();

  const { data: fund } = useQuery({
    queryKey: ['fund', fundId],
    queryFn: () => apiClient.get(`/api/funds/${fundId}`).then(r => r.data),
  });

  return (
    <PageLayout title={t('orderReview_title')} showBack>
      <div className="px-4 py-4 space-y-3 text-sm">
        <div className="flex justify-between py-2 border-b border-si-border">
          <span className="text-si-gray">{t('orderReview_fund')}</span>
          <span className="font-medium text-right max-w-[55%]">{fund?.name}</span>
        </div>
        <div className="flex justify-between py-2 border-b border-si-border">
          <span className="text-si-gray">{t('orderReview_orderType')}</span>
          <span className="font-medium">{orderType === 'ONE_TIME' ? t('order_oneTime') : t('order_monthly')}</span>
        </div>
        <div className="flex justify-between py-2 border-b border-si-border">
          <span className="text-si-gray">{t('orderReview_amount')}</span>
          <span className="font-medium">HKD {amount.toLocaleString()}</span>
        </div>
        <div className="flex justify-between py-2 border-b border-si-border">
          <span className="text-si-gray">{t('orderReview_settlement')}</span>
          <span className="font-medium">{t('orderReview_settlementValue')}</span>
        </div>
      </div>

      <div className="px-4 pt-4">
        <p className="text-xs text-si-gray mb-4">{t('orderReview_disclaimer')}</p>
        <button onClick={() => navigate('/order/terms', { state })}
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm">
          {t('orderReview_readTerms')}
        </button>
      </div>
    </PageLayout>
  );
}
