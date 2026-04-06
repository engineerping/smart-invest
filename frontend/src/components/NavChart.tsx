import { useState, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../api/client';

const PERIODS = ['3M', '6M', '1Y', '3Y', '5Y'];

interface NavDataPoint { navDate: string; nav: number; }
interface Props { fundId: string; chartLabel?: string; }

export default function NavChart({ fundId, chartLabel }: Props) {
  const [period, setPeriod] = useState('3M');
  const { data = [] } = useQuery({
    queryKey: ['nav-history', fundId, period],
    queryFn: () => apiClient.get<NavDataPoint[]>(`/api/funds/${fundId}/nav-history`, { params: { period } }).then(r => r.data),
  });

  const chartData = useMemo(() => {
    if (!data.length) return [];
    const base = data[0].nav;
    return data.map(d => ({
      date: d.navDate.slice(5),
      pct: +(((d.nav - base) / base) * 100).toFixed(2),
    }));
  }, [data]);

  return (
    <div className="px-4 py-3">
      {chartLabel && <p className="text-xs text-si-gray mb-2">{chartLabel}</p>}
      <div className="flex gap-4 mb-3">
        {PERIODS.map(p => (
          <button key={p} onClick={() => setPeriod(p)}
            className={`text-sm font-medium pb-1 ${period === p ? 'text-si-red border-b-2 border-si-red' : 'text-si-gray'}`}>
            {p}
          </button>
        ))}
      </div>
      <ResponsiveContainer width="100%" height={180}>
        <LineChart data={chartData}>
          <XAxis dataKey="date" tick={{ fontSize: 9 }} tickLine={false} />
          <YAxis tick={{ fontSize: 9 }} tickFormatter={v => `${v}%`} width={40} />
          <Tooltip formatter={(v: number) => [`${v}%`, 'Return']} />
          <Line type="monotone" dataKey="pct" stroke="#3B82F6" dot={false} strokeWidth={1.5} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
