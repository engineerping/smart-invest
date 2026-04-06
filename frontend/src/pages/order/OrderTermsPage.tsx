import { useNavigate, useLocation } from 'react-router-dom';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';

export default function OrderTermsPage() {
  const { state } = useLocation();
  const navigate = useNavigate();

  const handleConfirm = async () => {
    try {
      const res = await apiClient.post('/api/orders', state);
      navigate('/order/success', { state: { order: res.data } });
    } catch {
      alert('Order placement failed. Please try again.');
    }
  };

  return (
    <PageLayout title="Terms & Conditions" showBack>
      <div className="px-4 py-4 text-xs text-si-gray space-y-3 leading-relaxed">
        <p>This investment involves risk. Past performance is not indicative of future results.</p>
        <p>By confirming, you acknowledge that you have read and understood the fund prospectus and key facts statement.</p>
        <p>Investment returns are not guaranteed. The value of investments and any income from them can fall as well as rise.</p>
        <p>Smart Invest is a demonstration platform for portfolio purposes only.</p>
      </div>

      <div className="px-4 pt-2">
        <button onClick={handleConfirm}
          className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm">
          Confirm &amp; Buy
        </button>
      </div>
    </PageLayout>
  );
}
