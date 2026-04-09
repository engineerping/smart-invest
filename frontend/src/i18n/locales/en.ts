const en = {
  // Common
  loading: 'Loading…',
  nav: 'NAV',
  riskLevel: 'Risk Level',
  hkd: 'HKD',
  signOut: 'Sign out',
  back: '‹',

  // Auth - Login
  login_subtitle: 'Sign in to your account',
  login_email: 'Email',
  login_password: 'Password',
  login_error: 'Invalid email or password.',
  login_submit: 'Sign In',
  login_noAccount: 'No account?',
  login_register: 'Register',

  // Auth - Register
  register_title: 'Create Account',
  register_fullName: 'Full Name',
  register_email: 'Email',
  register_password: 'Password',
  register_errorPassword: 'Password must be at least 8 characters.',
  register_errorEmail: 'Registration failed. Email may already be in use.',
  register_submit: 'Register',
  register_hasAccount: 'Have an account?',
  register_signIn: 'Sign in',

  // Home
  home_totalMarketValue: 'Total market value (HKD)',
  home_myHoldings: 'My Holdings ›',
  home_investFunds: 'Invest in individual funds',
  home_moneyMarket: 'Money Market',
  home_moneyMarketDesc: 'Stable, low-risk HKD funds',
  home_bondIndex: 'Bond Index',
  home_bondIndexDesc: 'Global investment-grade bonds',
  home_equityIndex: 'Equity Index',
  home_equityIndexDesc: 'Global equity index funds',
  home_investPortfolios: 'Invest in portfolios',
  home_multiAsset: 'Multi-asset portfolios',
  home_multiAssetDesc: '5 risk levels · World Selection 1–5',
  home_buildPortfolio: 'Build your own portfolio',
  home_buildPortfolioDesc: 'Risk level 4–5 only',

  // Fund List
  fundList_title: 'Funds',

  // Fund Detail
  fundDetail_currentNav: 'Current NAV (HKD)',
  fundDetail_tabOverview: 'Overview',
  fundDetail_tabHoldings: 'Holdings',
  fundDetail_tabRisk: 'Risk',
  fundDetail_chartLabel: 'Cumulative return (%)',
  fundDetail_mgmtFee: 'Management fee',
  fundDetail_minInvestment: 'Min. investment',
  fundDetail_benchmark: 'Benchmark',
  fundDetail_noHoldings: 'No holdings data available',
  fundDetail_investNow: 'Invest now',
  fundDetail_pa: '% p.a.',

  // Order Setup
  order_title: 'Investment Details',
  order_oneTime: 'One-time',
  order_monthly: 'Monthly plan',
  order_amountLabel: 'Investment amount (HKD)',
  order_amountPlaceholder: 'Min. HKD 100',
  order_mgmtFee: 'Management fee',
  order_continue: 'Continue',

  // Order Review
  orderReview_title: 'Review',
  orderReview_fund: 'Fund',
  orderReview_orderType: 'Order type',
  orderReview_amount: 'Amount',
  orderReview_settlement: 'Settlement',
  orderReview_settlementValue: 'T+2 business days',
  orderReview_disclaimer: 'By proceeding, you confirm you have read and agree to the Terms and Conditions governing this investment.',
  orderReview_readTerms: 'Read Terms & Conditions',

  // Order Terms
  orderTerms_title: 'Terms & Conditions',
  orderTerms_p1: 'This investment involves risk. Past performance is not indicative of future results.',
  orderTerms_p2: 'By confirming, you acknowledge that you have read and understood the fund prospectus and key facts statement.',
  orderTerms_p3: 'Investment returns are not guaranteed. The value of investments and any income from them can fall as well as rise.',
  orderTerms_p4: 'Smart Invest is a demonstration platform for portfolio purposes only.',
  orderTerms_confirm: 'Confirm & Buy',
  orderTerms_error: 'Order placement failed. Please try again.',

  // Order Success
  orderSuccess_title: 'Order Submitted',
  orderSuccess_subtitle: 'Your order has been received and is being processed.',
  orderSuccess_refNumber: 'Reference number',
  orderSuccess_amount: 'Amount',
  orderSuccess_status: 'Status',
  orderSuccess_pending: 'Pending',
  orderSuccess_backHome: 'Back to Home',

  // Holdings
  holdings_title: 'My Holdings',
  holdings_totalMarketValue: 'Total market value (HKD)',
  holdings_myTransactions: 'My transactions',
  holdings_myPlans: 'My investment plans',
  holdings_none: 'No holdings yet',
  holdings_units: 'Units:',
  holdings_marketValue: 'Market Value: HKD',
  holdings_unknownFund: 'Unknown Fund',

  // Transactions
  transactions_title: 'My Transactions',
  transactions_none: 'No transactions',

  // Multi-Asset
  multiAsset_title: 'Multi-Asset Portfolios',
  multiAsset_subtitle: '5 risk levels · World Selection 1–5',
  riskLabel_1: 'Conservative',
  riskLabel_2: 'Moderately Conservative',
  riskLabel_3: 'Balanced',
  riskLabel_4: 'Adventurous',
  riskLabel_5: 'Speculative',

  // Build Portfolio
  buildPortfolio_title: 'Build Your Own Portfolio',
  buildPortfolio_hint: 'Select funds to create your custom portfolio (Risk Level 4–5)',
  buildPortfolio_restricted: 'Your risk level ({{level}}) does not allow building a custom portfolio.',
  buildPortfolio_restrictedSub: 'This feature requires Risk Level 4 or 5.',

  // Plans
  plans_title: 'My Investment Plans',
  plans_none: 'No investment plans yet',
  plans_explore: 'Explore funds to start a plan ›',
  plans_monthly: 'Monthly: HKD',
  plans_nextContribution: 'Next contribution:',
  plans_invested: 'Invested: HKD',
  plans_orders: 'orders',
  plans_fund: 'Fund',
} as const;

export default en;
