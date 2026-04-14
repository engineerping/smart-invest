const zh = {
  // Common
  loading: '加载中…',
  nav: '资产净值',
  riskLevel: '风险等级',
  hkd: '港元',
  signOut: '登出',
  back: '‹',

  // Auth - Login
  login_subtitle: '登录您的账户',
  login_platform: '公募基金投资平台',
  login_tagline: '麻雀虽小 五脏俱全\n原型产品 完整体验',
  login_madeBy: '作者：georgecuiwill@gmail.com',
  login_email: '电子邮箱',
  login_password: '密码',
  login_error: '邮箱或密码错误。',
  login_submit: '登录',
  login_noAccount: '没有账户？',
  login_register: '注册',

  // Auth - Register
  register_title: '创建账户',
  register_fullName: '姓名',
  register_email: '电子邮箱',
  register_password: '密码',
  register_errorPassword: '密码长度不得少于8位。',
  register_errorEmail: '注册失败，该邮箱可能已被使用。',
  register_submit: '注册',
  register_hasAccount: '已有账户？',
  register_signIn: '立即登录',

  // Home
  home_totalMarketValue: '总市值（港元）',
  home_myHoldings: '我的持仓 ›',
  home_investFunds: '投资单只基金',
  home_moneyMarket: '货币市场',
  home_moneyMarketDesc: '稳健低风险港元基金',
  home_bondIndex: '债券指数',
  home_bondIndexDesc: '全球投资级债券',
  home_equityIndex: '股票指数',
  home_equityIndexDesc: '全球股票指数基金',
  home_investPortfolios: '投资组合',
  home_multiAsset: '多资产组合',
  home_multiAssetDesc: '5个风险等级 · 环球精选1–5',
  home_buildPortfolio: '自建投资组合',
  home_buildPortfolioDesc: '仅限风险等级4–5',

  // Fund List
  fundList_title: '基金列表',

  // Fund Detail
  fundDetail_currentNav: '当前资产净值（港元）',
  fundDetail_tabOverview: '概览',
  fundDetail_tabHoldings: '持仓',
  fundDetail_tabRisk: '风险',
  fundDetail_chartLabel: '累计回报率（%）',
  fundDetail_mgmtFee: '管理费',
  fundDetail_minInvestment: '最低投资额',
  fundDetail_benchmark: '基准指数',
  fundDetail_noHoldings: '暂无持仓数据',
  fundDetail_investNow: '立即投资',
  fundDetail_pa: '% 每年',

  // Order Setup
  order_title: '投资详情',
  order_oneTime: '单次投资',
  order_monthly: '月供计划',
  order_amountLabel: '投资金额（港元）',
  order_amountPlaceholder: '最低港元100',
  order_mgmtFee: '管理费',
  order_continue: '继续',

  // Order Review
  orderReview_title: '确认订单',
  orderReview_fund: '基金',
  orderReview_orderType: '订单类型',
  orderReview_amount: '金额',
  orderReview_settlement: '结算',
  orderReview_settlementValue: 'T+2个工作日',
  orderReview_disclaimer: '继续操作，即表示您已阅读并同意本次投资的条款及条件。',
  orderReview_readTerms: '阅读条款及条件',

  // Order Terms
  orderTerms_title: '条款及条件',
  orderTerms_p1: '本投资涉及风险，过往表现并不代表未来回报。',
  orderTerms_p2: '确认即表示您已阅读并理解基金招募说明书及产品资料概要。',
  orderTerms_p3: '投资回报无法保证，投资价值及其收益可升亦可跌。',
  orderTerms_p4: 'Smart Invest 仅为演示平台，仅供展示用途。',
  orderTerms_confirm: '确认购买',
  orderTerms_error: '下单失败，请重试。',

  // Order Success
  orderSuccess_title: '订单已提交',
  orderSuccess_subtitle: '您的订单已收到，正在处理中。',
  orderSuccess_refNumber: '参考编号',
  orderSuccess_amount: '金额',
  orderSuccess_status: '状态',
  orderSuccess_pending: '处理中',
  orderSuccess_backHome: '返回首页',

  // Holdings
  holdings_title: '我的持仓',
  holdings_totalMarketValue: '总市值（港元）',
  holdings_myTransactions: '我的交易记录',
  holdings_myPlans: '我的投资计划',
  holdings_none: '暂无持仓',
  holdings_units: '单位数：',
  holdings_marketValue: '市值：港元',
  holdings_unknownFund: '未知基金',

  // Transactions
  transactions_title: '我的交易记录',
  transactions_none: '暂无交易记录',

  // Multi-Asset
  multiAsset_title: '多资产组合',
  multiAsset_subtitle: '5个风险等级 · 环球精选1–5',
  riskLabel_1: '保守型',
  riskLabel_2: '较保守型',
  riskLabel_3: '均衡型',
  riskLabel_4: '进取型',
  riskLabel_5: '投机型',

  // Build Portfolio
  buildPortfolio_title: '自建投资组合',
  buildPortfolio_hint: '选择基金以创建您的专属组合（风险等级4–5）',
  buildPortfolio_restricted: '您的风险等级（{{level}}）不符合自建组合要求。',
  buildPortfolio_restrictedSub: '此功能需要风险等级4或5。',

  // Plans
  plans_title: '我的投资计划',
  plans_none: '暂无投资计划',
  plans_explore: '探索基金，开启投资计划 ›',
  plans_monthly: '月供：港元',
  plans_nextContribution: '下次供款日：',
  plans_invested: '已投资：港元',
  plans_orders: '笔订单',
  plans_fund: '基金',
} as const;

export default zh;
