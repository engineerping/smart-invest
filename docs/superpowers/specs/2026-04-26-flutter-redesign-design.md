# Flutter 前端重写设计文档

**日期**: 2026-04-26
**项目**: Smart Invest 前端从 React 重写为 Flutter
**状态**: 已批准

---

## 1. 技术选型

| 类别 | 选择 | 说明 |
|------|------|------|
| 目标平台 | iOS + Android + Web | 三平台覆盖 |
| UI 风格 | Material Design 3 | Google 最新设计语言 |
| 状态管理 | Riverpod / Provider | 官方推荐，简单易用 |
| 路由 | go_router | 官方推荐，声明式路由，深度链接支持 |
| HTTP 客户端 | http (官方) | Flutter 官方 package，轻量简单 |
| 架构 | 三层架构 (UI / Business Logic / Data) | 清晰分层 |
| 图表 | fl_chart | 功能全面，社区活跃 |
| 认证 | JWT + flutter_secure_storage | Token 安全存储 |
| 离线支持 | 本地缓存 | 基金信息缓存，5分钟过期 |

---

## 2. 项目结构

```
lib/
├── core/                    # 核心基础设施
│   ├── api/                 # HTTP 客户端、API 错误处理
│   │   ├── api_client.dart
│   │   ├── api_endpoints.dart
│   │   └── api_exception.dart
│   ├── auth/                # JWT 认证、Token 管理
│   │   ├── auth_repository.dart
│   │   └── token_manager.dart
│   ├── storage/             # 安全存储封装
│   │   └── secure_storage.dart
│   ├── router/              # go_router 配置
│   │   └── app_router.dart
│   ├── theme/               # Material Design 3 主题
│   │   └── app_theme.dart
│   └── utils/               # 通用工具
│
├── features/                # 功能模块（按业务划分）
│   ├── auth/                # 登录、注册
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── funds/               # 基金列表、详情
│   ├── portfolio/            # 投资组合、风险评估
│   ├── order/                # 订单流程
│   ├── holdings/             # 持仓、交易记录
│   └── plans/                # 定投计划
│
├── shared/                   # 共享组件
│   ├── widgets/              # 通用 UI 组件
│   │   ├── nav_chart.dart
│   │   ├── risk_gauge.dart
│   │   └── page_layout.dart
│   ├── models/               # 数据模型
│   └── services/             # 跨功能服务
│
├── responsive/               # 响应式布局
│   ├── breakpoints.dart
│   ├── screen_size.dart
│   └── layout_builder.dart
│
└── main.dart
```

---

## 3. 三层架构职责

### Data Layer (数据层)
- `ApiClient`: HTTP 请求封装，统一错误处理
- `Repositories`: 数据来源抽象（API 或本地缓存）
- `LocalCache`: Hive/SharedPreferences 缓存管理

### Business Logic Layer (业务逻辑层)
- `Providers/Notifiers`: 状态管理，处理业务逻辑
- 连接 UI 层和 Data 层

### Presentation Layer (UI层)
- `Screens/Widgets`: 页面和组件
- 响应式布局适配

---

## 4. 核心模块设计

### 4.1 API 层 (`core/api/`)
- 统一错误处理：401 → 跳转登录，500 → 错误提示
- 请求拦截器：自动添加 JWT Token
- 响应拦截器：统一错误码处理

### 4.2 认证层 (`core/auth/`)
- `TokenManager`: flutter_secure_storage 封装，存储/读取/删除 Token
- `AuthRepository`: 登录、注册、Token 刷新逻辑

### 4.3 路由层 (`core/router/`)
- go_router 声明式路由配置
- 路由守卫：未登录自动跳转登录页
- 深度链接支持（scheme: smartinvest://）

### 4.4 主题层 (`core/theme/`)
- Material Design 3 配色：蓝/绿金融风格
- 统一组件样式：Cards, Buttons, InputFields

---

## 5. 响应式布局

| 平台 | 断点 | 布局 |
|------|------|------|
| Mobile | < 600px | 单列，底部导航 |
| Tablet | 600-1024px | 双列，侧边栏可选 |
| Web/Desktop | > 1024px | 多列，侧边导航栏 |

---

## 6. 缓存策略

| 数据类型 | 缓存方式 | 过期时间 |
|----------|----------|----------|
| 基金信息 | SharedPreferences | 5 分钟 |
| 基金详情 | SharedPreferences | 5 分钟 |
| 持仓数据 | 不缓存 | 实时 |
| 订单数据 | 不缓存 | 实时 |
| 用户信息 | SecureStorage | 会话级 |

---

## 7. 功能模块映射

| React 页面 | Flutter 页面 | 路由 |
|------------|-------------|------|
| LoginPage | LoginScreen | /login |
| RegisterPage | RegisterScreen | /register |
| FundListPage | FundListScreen | /funds |
| FundDetailPage | FundDetailScreen | /funds/:id |
| MultiAssetFundListPage | MultiAssetFundListScreen | /funds/multi-asset |
| BuildPortfolioPage | BuildPortfolioScreen | /portfolio/build |
| OrderSetupPage | OrderSetupScreen | /order/setup |
| OrderReviewPage | OrderReviewScreen | /order/review |
| OrderTermsPage | OrderTermsScreen | /order/terms |
| OrderSuccessPage | OrderSuccessScreen | /order/success |
| MyHoldingsPage | MyHoldingsScreen | /holdings |
| MyTransactionsPage | MyTransactionsScreen | /holdings/transactions |
| InvestmentPlansPage | InvestmentPlansScreen | /plans |
| SmartInvestHomePage | HomeScreen | / (默认) |

---

## 8. 实施计划（方案 B：基础设施优先）

### Phase 1: 核心基础设施
1. 项目初始化 (flutter create)
2. 依赖配置 (pubspec.yaml)
3. API 层实现
4. 认证层实现
5. 路由配置
6. 主题配置

### Phase 2: 共享组件
1. PageLayout
2. RiskGauge (fl_chart)
3. NavChart (fl_chart)
4. 响应式布局组件

### Phase 3: 功能模块迁移
1. 认证模块
2. 基金模块
3. 投资组合模块
4. 订单模块
5. 持仓模块
6. 定投模块

---

## 9. 验收标准

- [ ] 三平台 (iOS/Android/Web) 均可构建运行
- [ ] Material Design 3 主题统一
- [ ] go_router 路由正常工作
- [ ] JWT 认证流程完整
- [ ] fl_chart 图表正常渲染
- [ ] 响应式布局适配移动端/平板/桌面
- [ ] 基金信息本地缓存正常工作
