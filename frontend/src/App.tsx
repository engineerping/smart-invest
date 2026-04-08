import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useAuthStore } from './store/authStore';
import LoginPage from './pages/auth/LoginPage';
import RegisterPage from './pages/auth/RegisterPage';
import SmartInvestHomePage from './pages/home/SmartInvestHomePage';
import FundListPage from './pages/funds/FundListPage';
import FundDetailPage from './pages/funds/FundDetailPage';
import MultiAssetFundListPage from './pages/funds/MultiAssetFundListPage';
import OrderSetupPage from './pages/order/OrderSetupPage';
import OrderReviewPage from './pages/order/OrderReviewPage';
import OrderTermsPage from './pages/order/OrderTermsPage';
import OrderSuccessPage from './pages/order/OrderSuccessPage';
import MyHoldingsPage from './pages/holdings/MyHoldingsPage';
import MyTransactionsPage from './pages/holdings/MyTransactionsPage';
import InvestmentPlansPage from './pages/plans/InvestmentPlansPage';
import BuildPortfolioPage from './pages/portfolio/BuildPortfolioPage';

const queryClient = new QueryClient();

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const token = useAuthStore(s => s.token);
  return token ? <>{children}</> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route path="/login"    element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/"         element={<PrivateRoute><SmartInvestHomePage /></PrivateRoute>} />
          <Route path="/funds"      element={<PrivateRoute><FundListPage /></PrivateRoute>} />
          <Route path="/funds/:id"  element={<PrivateRoute><FundDetailPage /></PrivateRoute>} />
          <Route path="/order"      element={<PrivateRoute><OrderSetupPage /></PrivateRoute>} />
          <Route path="/order/review"  element={<PrivateRoute><OrderReviewPage /></PrivateRoute>} />
          <Route path="/order/terms"   element={<PrivateRoute><OrderTermsPage /></PrivateRoute>} />
          <Route path="/order/success" element={<PrivateRoute><OrderSuccessPage /></PrivateRoute>} />
          <Route path="/holdings"   element={<PrivateRoute><MyHoldingsPage /></PrivateRoute>} />
          <Route path="/transactions" element={<PrivateRoute><MyTransactionsPage /></PrivateRoute>} />
          <Route path="/multi-asset"    element={<PrivateRoute><MultiAssetFundListPage /></PrivateRoute>} />
          <Route path="/plans"          element={<PrivateRoute><InvestmentPlansPage /></PrivateRoute>} />
          <Route path="/build-portfolio" element={<PrivateRoute><BuildPortfolioPage /></PrivateRoute>} />
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
