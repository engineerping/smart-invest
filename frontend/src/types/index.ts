export interface AuthResponse { accessToken: string; tokenType: string; }

export interface User {
  id: string; email: string; fullName: string; riskLevel: number | null; status: string;
}

export interface Fund {
  id: string; code: string; name: string; fundType: string;
  riskLevel: number; currentNav: number; navDate: string;
  annualMgmtFee: number; minInvestment: number;
  benchmarkIndex?: string; marketFocus?: string; description?: string;
}

export interface NavDataPoint { navDate: string; nav: number; }

export interface Order {
  id: string; referenceNumber: string; fundId: string;
  orderType: string; amount: number; status: string;
  orderDate: string; settlementDate?: string;
}

export interface Holding {
  id: string; fundId: string; totalUnits: number;
  avgCostNav: number; totalInvested: number;
}

export interface InvestmentPlan {
  id: string; referenceNumber: string; fundId: string; fundName?: string;
  monthlyAmount: number; nextContributionDate: string;
  status: string; completedOrders: number; totalInvested: number;
}
