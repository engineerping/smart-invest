interface Props { productRiskLevel: number; userRiskLevel: number; }
const SEGMENT_COLORS = ['#9CA3AF','#1E3A5F','#3B82F6','#EAB308','#F97316','#EF4444'];

export default function RiskGauge({ productRiskLevel, userRiskLevel }: Props) {
  const safe = productRiskLevel <= userRiskLevel;
  return (
    <div className="w-full px-4 py-3">
      <div className="flex gap-0.5 relative mb-6">
        {SEGMENT_COLORS.map((color, i) => (
          <div key={i} className="flex-1 h-4 rounded-sm relative" style={{ backgroundColor: color }}>
            {i === productRiskLevel && <span className="absolute -top-5 left-1/2 -translate-x-1/2 text-xs">▼</span>}
            {i === userRiskLevel && <span className="absolute -bottom-5 left-1/2 -translate-x-1/2 text-xs text-green-600">▲</span>}
          </div>
        ))}
      </div>
      <div className="flex justify-between text-xs text-si-gray mt-4">
        <span>Product risk level</span>
        <span>Your risk tolerance</span>
      </div>
      <p className={`text-xs mt-2 ${safe ? 'text-green-600' : 'text-amber-600'}`}>
        {safe ? '✓ This fund is within your risk tolerance level.' : '⚠ This fund exceeds your risk tolerance level.'}
      </p>
    </div>
  );
}
