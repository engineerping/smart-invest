import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../api/client';
import PageLayout from '../../components/PageLayout';

const STATUS_STYLES: Record<string, string> = {
  PENDING: 'text-amber-600',
  COMPLETED: 'text-green-600',
  CANCELLED: 'text-gray-400',
};

export default function MyTransactionsPage() {
  const { data: ordersPage } = useQuery({
    queryKey: ['orders'],
    queryFn: () => apiClient.get('/api/orders').then(r => r.data),
  });
  const orders = ordersPage?.content ?? [];

  return (
    <PageLayout title="My Transactions" showBack>
      <div className="divide-y divide-si-border">
        {orders.map((order: any) => (
          <div key={order.id} className="px-4 py-4">
            <div className="flex justify-between text-sm">
              <span className="font-medium text-si-dark">{order.referenceNumber}</span>
              <span className={`font-medium ${STATUS_STYLES[order.status] ?? 'text-si-gray'}`}>
                {order.status?.charAt(0) + order.status?.slice(1).toLowerCase()}
              </span>
            </div>
            <div className="flex justify-between mt-1 text-xs text-si-gray">
              <span>{order.orderDate}</span>
              <span>HKD {order.amount?.toLocaleString()}</span>
            </div>
          </div>
        ))}
        {orders.length === 0 && (
          <p className="text-sm text-si-gray text-center py-8">No transactions</p>
        )}
      </div>
    </PageLayout>
  );
}
