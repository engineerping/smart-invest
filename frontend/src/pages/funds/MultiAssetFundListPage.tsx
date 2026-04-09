import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';
import type { Fund } from '../../types';

const RISK_COLORS: Record<number, string> = { 1:'bg-gray-400', 2:'bg-blue-900', 3:'bg-blue-500', 4:'bg-yellow-500', 5:'bg-red-500' };

export default function MultiAssetFundListPage() {
  const navigate = useNavigate();
  const { t } = useTranslation();

  const RISK_LABELS: Record<number, string> = {
    1: t('riskLabel_1'),
    2: t('riskLabel_2'),
    3: t('riskLabel_3'),
    4: t('riskLabel_4'),
    5: t('riskLabel_5'),
  };

  const { data: funds = [], isLoading } = useQuery({
    queryKey: ['funds', 'multi-asset'],
    queryFn: () => apiClient.get<Fund[]>('/api/funds/multi-asset').then(r => r.data),
  });

  return (
    <PageLayout title={t('multiAsset_title')} showBack>
      <div className="px-4 py-3 bg-si-light border-b border-si-border">
        <p className="text-xs text-si-gray">{t('multiAsset_subtitle')}</p>
      </div>
      {isLoading ? (
        <div className="flex justify-center py-10 text-si-gray text-sm">{t('loading')}</div>
      ) : (
        <div className="divide-y divide-si-border">
          {funds.map(fund => (
            <button key={fund.id} onClick={() => navigate(`/funds/${fund.id}`)}
              className="w-full text-left px-4 py-4 hover:bg-si-light">
              <div className="flex justify-between items-start">
                <div className="flex-1 pr-4">
                  <p className="text-sm font-medium text-si-dark leading-snug">{fund.name}</p>
                  <p className="text-xs text-si-gray mt-1">
                    {t('riskLevel')} {fund.riskLevel} · {RISK_LABELS[fund.riskLevel] ?? ''}
                  </p>
                </div>
                <div className="text-right shrink-0">
                  <p className="text-sm font-semibold text-si-dark">{fund.currentNav?.toFixed(4) ?? '--'}</p>
                  <p className="text-xs text-si-gray">{t('nav')}</p>
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
