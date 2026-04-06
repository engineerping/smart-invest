import { useNavigate, useLocation } from 'react-router-dom';

export default function OrderSuccessPage() {
  const { state } = useLocation();
  const order = (state as { order: { referenceNumber: string; amount: number; status: string } }).order;
  const navigate = useNavigate();

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 bg-white">
      <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mb-4">
        <span className="text-green-600 text-3xl">✓</span>
      </div>
      <h1 className="text-lg font-bold text-si-dark mb-2">Order Submitted</h1>
      <p className="text-sm text-si-gray text-center mb-6">Your order has been received and is being processed.</p>
      <div className="w-full bg-si-light rounded-xl px-4 py-4 mb-6">
        <div className="flex justify-between text-sm py-1">
          <span className="text-si-gray">Reference number</span>
          <span className="font-semibold text-si-dark">{order.referenceNumber}</span>
        </div>
        <div className="flex justify-between text-sm py-1">
          <span className="text-si-gray">Amount</span>
          <span className="font-medium">HKD {order.amount?.toLocaleString()}</span>
        </div>
        <div className="flex justify-between text-sm py-1">
          <span className="text-si-gray">Status</span>
          <span className="font-medium text-amber-600">Pending</span>
        </div>
      </div>
      <button onClick={() => navigate('/')}
        className="w-full bg-si-red text-white rounded-lg py-3 font-semibold text-sm">
        Back to Home
      </button>
    </div>
  );
}
