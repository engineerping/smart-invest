import { useNavigate, useLocation } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';

export default function OrderTermsPage() {
  const { state } = useLocation();
  const navigate = useNavigate();
  const { t } = useTranslation();

  const handleConfirm = async () => {
    try {
      const res = await apiClient.post('/api/orders', state);
      navigate('/order/success', { state: { order: res.data } });
    } catch {
      alert(t('orderTerms_error'));
    }
  };

  return (
    <PageLayout title={t('orderTerms_title')} showBack>
      <div className="px-4 py-4 text-xs text-si-gray space-y-3 leading-relaxed">
        <p>{t('orderTerms_p1')}</p>
        <p>{t('orderTerms_p2')}</p>
        <p>{t('orderTerms_p3')}</p>
        <p>{t('orderTerms_p4')}</p>
      </div>

      <div className="px-4 pt-2">
        <button onClick={handleConfirm}
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm">
          {t('orderTerms_confirm')}
        </button>
      </div>
    </PageLayout>
  );
}
