import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';
import type { InvestmentPlan } from '../../types';

const STATUS_STYLES: Record<string, string> = {
  ACTIVE: 'bg-green-100 text-green-700',
  TERMINATED: 'bg-gray-100 text-gray-400',
};

export default function InvestmentPlansPage() {
  const navigate = useNavigate();
  const { t } = useTranslation();

  const { data: plans = [], isLoading } = useQuery<InvestmentPlan[]>({
    queryKey: ['plans'],
    queryFn: () => apiClient.get('/api/plans').then(r => r.data),
  });

  return (
    <PageLayout title={t('plans_title')} showBack>
      {isLoading ? (
        <div className="flex justify-center py-10 text-si-gray text-sm">{t('loading')}</div>
      ) : plans.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-sm text-si-gray mb-4">{t('plans_none')}</p>
          <button onClick={() => navigate('/')}
            className="text-sm text-si-red font-medium">{t('plans_explore')}</button>
        </div>
      ) : (
        <div className="divide-y divide-si-border">
          {plans.map(plan => (
            <div key={plan.id} className="px-4 py-4">
              <div className="flex justify-between items-start">
                <div className="flex-1">
                  <p className="text-sm font-medium text-si-dark">{plan.referenceNumber}</p>
                  <p className="text-xs text-si-gray mt-0.5">{plan.fundName ?? t('plans_fund')}</p>
                  <p className="text-xs text-si-gray">{t('plans_monthly')} {plan.monthlyAmount?.toLocaleString()}</p>
                  <p className="text-xs text-si-gray">{t('plans_nextContribution')} {plan.nextContributionDate}</p>
                </div>
                <div className="text-right">
                  <span className={`inline-block text-xs px-2 py-0.5 rounded-full ${STATUS_STYLES[plan.status] ?? 'bg-gray-100 text-gray-600'}`}>
                    {plan.status}
                  </span>
                  <p className="text-xs text-si-gray mt-1">{t('plans_invested')} {plan.totalInvested?.toLocaleString()}</p>
                  <p className="text-xs text-si-gray">{plan.completedOrders} {t('plans_orders')}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </PageLayout>
  );
}
