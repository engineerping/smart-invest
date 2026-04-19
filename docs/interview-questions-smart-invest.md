# Smart-Invest 架构 & 金融项目 面试题库（含答案）

> 基于 [smart-invest-aws-plan-d-architecture.drawio](smart-invest-aws-plan-d-architecture.drawio) 与 [2026-04-08-aws-deployment-plan-d.md](superpowers/specs/2026-04-08-aws-deployment-plan-d.md)，针对 HSBC FlexInvest 类公募基金投资平台的面试准备。
> 覆盖 Solutions Architect Professional、Senior Backend、SRE/Platform、金融行业领域等视角。
> **答案说明：假设读者是有一定 Java/Spring Boot 开发经验，但对分布式系统、云计算、金融业务处于学习阶段的开发者。答案中穿插了大量生活化比喻，帮助理解抽象概念。**

---

## 一、项目概览与业务理解（破冰题，必问）

### 1. 请用 3–5 分钟介绍 smart-invest 这个项目：它解决什么业务问题？核心用户是谁？你在其中承担了什么角色？

**答案：**

smart-invest 是一个公募基金投资平台，类似于支付宝的"蚂蚁基金"或汇丰的 FlexInvest。它的核心价值是：**让普通人能像在网上买东西一样简单地买基金**。

**打个比方：**
> 你去菜市场买菜，摊位上标明了每种菜的"今日价格"（基金净值），但这个价格是今天早上定的，你今天买的菜要等明天才知道真正扣了多少钱——这就是 T+1 的意思。smart-invest 就是帮用户在手机上完成选基金、买基金、查持仓、看收益的整个流程。

**业务要解决的核心问题：**
- 普通人买基金门槛高：不知道买哪个、不知道怎么买、不敢买
- 基金公司接口不统一：每家有自己的规则，smart-invest 做一个统一接入层
- 合规要求复杂：需要 KYC（实名）、风测（评估你适合买什么风险等级的基金）、AML（反洗钱）

**核心用户：** 25–55 岁的城市白领，有理财需求但不是专业投资者。

**我的角色：** （根据实际情况回答）如果是原型阶段，可能是全栈开发；如果是 plan D，可能是负责某个领域（如 EKS 部署、订单服务设计、CI/CD 流水线）。

---

### 2. FlexInvest 类的公募基金投资平台，与证券交易系统（如股票）相比，在技术上有什么本质差异？

**答案：**

| 维度 | 股票交易系统 | 公募基金平台（smart-invest） |
|------|------------|--------------------------|
| 价格确定方式 | 实时竞价，价格在毫秒级变化 | T+1，基金净值每天收盘后计算一次 |
| 成交方式 | 买卖双方撮合，可能买不到/卖不出 | 按"未知价"下单，按收盘价成交 |
| 份额 vs 金额 | 股票按"股"买，100股起 | 可按"金额"买（投1000元）或"份额"买 |
| 结算周期 | T+0 ~ T+1 | T+1 ~ T+2 |
| 跨境 | A股只买A股 | QDII基金可买美股/港股，涉及汇率和跨时区 |

**用餐厅来比喻：**
> 股票交易就像你去海底捞实时点菜，每道菜价格随时在变，点完立即知道总价。公募基金就像你去自助餐厅，今天的菜品价格表要到晚上餐厅打烊后才更新，你中午买的时候只知道大概会花多少钱。

**T+1 的技术影响：** 股票系统需要高性能撮合引擎，基金系统需要处理"预估金额"和"确认金额"的差异，以及复杂的日终清算流程。

---

### 3. 为什么选择微服务架构？拆分成 user / fund / order / portfolio / plan 这 5 个服务的依据是什么？

**答案：**

**用"大型商场 vs 小超市"来比喻：**
> 小超市（单体）所有东西都在一个店里，结账、进货、盘点都是同一套人马。好处是简单，坏处是——如果酒水区着火了，整个超市都得关门。
>
> 大型商场（微服务）是分区的：服装区、美食区、电影院。每个区有自己的员工、独立收银台。美食区着火了，服装区继续营业不受影响。

**5 个服务的划分依据（DDD - 领域驱动设计）：**

- **user-service（用户服务）**：管"谁"——注册、登录、实名认证、KYC。每个用户的行为独立，不需要和其他服务强耦合。
- **fund-service（基金服务）**：管"产品"——基金的信息、净值、分红公告。基金本身是稳定的，变化频率低。
- **order-service（订单服务）**：管"交易"——买基金、卖基金的核心逻辑。这是最复杂、最核心的，必须独立，因为它最容易出问题和变更。
- **portfolio-service（持仓服务）**：管"结果"——用户买了之后持有多少。这需要和 order-service 联动，但技术上是独立的存储。
- **plan-service（计划服务）**：管"定投"——定期自动买基金。这是一个独立的产品功能，有自己的调度逻辑。

**为什么不拆更细/更粗？**
- 拆太细（如每张表一个服务）→ 管理成本爆炸，服务间调用链路复杂
- 拆太粗（把所有功能放一个服务）→ 一个 bug 导致全站宕机，团队协作困难

---

### 4. 如果让你重新拆分，你会如何划分？Bounded Context 的边界在哪里？

**答案：**

**Bounded Context（限界上下文）** 是 DDD 的核心概念，可以理解为一个"国界线"——每个国家内部有自己的法律（业务规则），跨国的规则就不一样了。

**我会这样划分：**

```
用户域（User Context）     → user-service
  └── 注册、登录、身份认证、KYC

产品域（Product Context）  → fund-service
  └── 基金信息、净值、基金公司接口

交易域（Transaction Context）→ order-service
  └── 下单、撤单、订单状态机、清结算

持仓域（Position Context）  → portfolio-service
  └── 实时持仓、累计收益、份额确认

计划域（Plan Context）     → plan-service
  └── 定投计划、转换计划、基金组合

共享域（Shared Context）   → 独立出去作为公共库
  └── 通用DTO、异常定义、工具类
```

**边界划分原则：** 如果改一个业务规则，需要同时改两个服务，那就说明边界划错了——应该合并。**如果两个服务的核心概念对对方"不感兴趣"，那就应该分开。** 比如 order-service 不需要知道用户的头像是什么，portfolio-service 不需要知道用户用什么邮箱注册。

---

### 5. 项目中最具挑战的技术点是什么？你是如何解决的？

**答案：** （根据实际情况选择 1-2 个真实经历，以下是参考）

**常见挑战及解法：**

**挑战 1：分布式事务**
> 你在电商买了一个商品，订单系统说"扣钱了"，库存系统说"没减库存"——钱扣了东西没到手，用户肯定炸了。

解法：用 **Saga 模式**（补偿事务）。每个步骤都有"撤销动作"。下订单 → 扣款 → 份额入账，每一步失败就执行前一步的补偿操作（退钱、撤销入账）。不是传统的数据库事务（ACID），而是最终一致性。

**挑战 2：T+1 净值导致的价格不确定性**
> 用户下单时不知道最终成交价是多少。

解法：前端展示"上一个交易日净值"作为参考，下单记录预估金额，日终清算后更新实际金额并通知用户。

**挑战 3：多基金公司接口不一致**
> 每家基金公司的 API 格式、限流规则、错误码都不一样。

解法：封装一层"基金适配器"，统一内部接口，对外屏蔽差异。

---

### 6. 项目上线后，日活用户、QPS、数据量量级预期是多少？你的架构为这个量级做了哪些针对性设计？

**答案：**

**量级预估（初创期 → 成长期）：**

| 指标 | 初创期 | 成长期（1-3年） |
|------|--------|--------------|
| 日活用户 | 1,000–10,000 | 100,000–1,000,000 |
| 峰值 QPS（下单） | 10–50 | 500–2,000 |
| 日订单量 | 1,000–10,000 | 100,000–1,000,000 |
| 持仓数据 | 10,000–100,000 | 1,000,000–10,000,000 |

**针对性设计：**

- **高并发下单**：Redis 缓存 + 异步队列削峰。不是每来一个请求就直接写 DB，而是先写 Redis 队列，后台慢慢处理，防止 DB 被冲垮。
- **读多写少**：基金净值查询 QPS 远高于下单。用 Redis 缓存热门基金净值，99% 的查询不需要打数据库。
- **HPA 自动扩容**：交易时间（开盘/收盘）流量是平时的 5–10 倍，K8s 根据 CPU/内存自动扩缩 Pod。
- **数据库选型**：Aurora PostgreSQL 自动扩展存储，最大 128TB，不用担心表太大。

---

### 7. 从原型到 production version（plan D），你做了哪些关键升级？为什么不一次到位？

**答案：**

**关键升级对比：**

| 维度 | 原型 | Plan D |
|------|------|--------|
| 部署 | 单机 Docker | EKS 多 AZ |
| 数据库 | 单机 PostgreSQL | Aurora Global |
| 配置 | application.yml 明文 | AWS Secrets Manager |
| 网络 | 无加密 | 全 VPC 私有网络 + VPC Endpoint |
| 监控 | 无 | Prometheus + Grafana 全套 |
| 部署 | 手动 | ArgoCD GitOps |
| 灾备 | 无 | 两地三中心 DR |

**为什么不一次到位？**
- **成本**：生产级架构月成本可能是原型的 20–50 倍。创业初期没必要。
- **认知**：很多架构决策只有在业务跑起来后才能知道对不对。先跑 MVP，验证商业模式，再投重兵。
- **团队**：GitOps、K8s、IRSA 这套东西需要团队有经验，硬上只会出事故。
- **类比**：你开一家小饭馆，先买几张桌子营业，发现天天排队，再租大场地、上 POS 系统、优化后厨——而不是第一天就建中央厨房。

---

## 二、架构设计与权衡（Solutions Architect Professional 核心）

### 1. 请对照架构图讲讲整个系统的请求链路

**答案：**

**完整链路（以"买入基金"为例）：**

```
用户点击"买入"按钮
    ↓
① DNS 解析（用户的手机 → Route 53）
    ↓
② CDN 缓存检查（CloudFront）
    如果是静态资源（图片/CSS/JS）→ 直接返回，不进后端
    如果是 API 请求 → 继续往下
    ↓
③ WAF 安全检查（AWS WAF）
    检查请求是否恶意（SQL注入、XSS、CC攻击）
    有问题的直接拦截返回 403，正常请求继续
    ↓
④ DDoS 防护（AWS Shield）
    抵御大流量攻击，正常流量放行
    ↓
⑤ ALB（应用负载均衡器）
    根据 URL 路径 /api/orders → 路由到 order-service 的 Pod
    ALB 选择一个健康的 Pod（跳过不健康的）
    ↓
⑥ EKS Node 上的 Pod 接收请求
    Pod 用 IRSA 角色从 Secrets Manager 拿数据库密码（不在代码里）
    ↓
⑦ Spring Boot 处理业务逻辑
    1. 查 Redis：用户今日下单次数是否超限
    2. 查 fund-service：基金当前净值（也可能从 Redis 缓存拿）
    3. 计算份额：投入金额 / 净值
    4. 写 order-service 的 PostgreSQL（Aurora）：插入订单记录
    5. 发消息到 Redis Stream/ SNS：异步通知 portfolio-service 更新持仓
    ↓
⑧ 返回响应给用户
    成功：显示"下单成功，预计 T+1 确认"
    失败：显示具体错误信息
```

**用去医院看病比喻整个链路：**
> 你走进医院（用户发起请求）。保安在门口检查你带没带武器（WAF）。安检门检测体温过高的人（DDoS防护）。护士分诊台根据你的症状分配科室（ALB路由）。医生（Pod）在诊室里看病开药（业务逻辑），药房的库存系统（Redis）和病历库（数据库）配合工作。最后你拿到处方离开（返回响应）。

---

### 2. 你的架构有哪几层？每一层解决什么问题？

**答案：**

**七层架构：**

```
┌─────────────────────────────────┐
│  第7层：用户层（User Layer）     │  浏览器 / App / 小程序
├─────────────────────────────────┤
│  第6层：CDN / 边缘层             │  CloudFront 静态加速、安全防护
├─────────────────────────────────┤
│  第5层：网关层（Gateway Layer）   │  ALB + WAF + Shield 统一入口
├─────────────────────────────────┤
│  第4层：微服务层                 │  Spring Boot 业务逻辑
│      (user/fund/order/portfolio) │
├─────────────────────────────────┤
│  第3层：数据访问层               │  RDS Proxy（连接池）+ Redis（缓存）
├─────────────────────────────────┤
│  第2层：数据层                   │  Aurora PostgreSQL / S3
├─────────────────────────────────┤
│  第1层：基础设施层               │  AWS VPC / EKS / IAM / KMS
└─────────────────────────────────┘
```

**为什么分层？**
> 就像一栋大楼：地基（基础设施）→ 楼层（数据层）→ 房间（服务）→ 门窗（网关）→ 安保（CDN/WAF）。每层各司其职，出了问题好定位。

---

### 3. 如果让你砍掉一半组件来降本 50%，你会砍哪些？

**答案：**

**砍法（按优先级）：**

**第一刀（省 20%）：降级到非生产级**
- Aurora Global → 单 AZ Aurora（数据安全性降低，但省钱）
- 多账号 → 合并成 2–3 个账户
- Dev 环境夜间自动关停（kube-green）

**第二刀（省 15%）：去掉"锦上添花"的**
- Spot 实例替代 on-demand（省 60% 计算费）
- Graviton ARM 实例替代 x86（省 10–20%）
- CloudWatch Logs → 减少日志级别（INFO 以下不打印）
- 删除 GPU Node Group（如果目前没用到）

**第三刀（省 10%）：精简可观测性**
- 不上 Managed Grafana，用社区版自己搭（省 Grafana Cloud 费用）
- 减少 Prometheus 采集频率（15s → 60s）

**不能砍的（砍了业务就跑不下去）：**
- EKS 集群本身
- 核心数据库
- WAF（合规要求）
- Secrets Manager（或换成开源替代但不能没有）

**用购物比喻：**
> 月薪 2 万的时候，你需要租 1 万的房子（核心基础设施），买 3000 的代步车（数据库），吃 2000 的饭（计算资源）。剩下的 5000 是"保险"——健身房、偶尔打车、紧急备用金。降本 50% 意味着你要把租房砍到 5000（影响通勤）、车改成共享单车（降低可用性）——不是简单砍掉，而是**在满足核心需求的前提下做取舍**。

---

### 4. 这个架构过度设计了吗？初创期哪些先不要上？

**答案：**

**是，有过度设计的部分。** 初创期建议先不上的：

| 组件 | 理由 | 等什么时候上 |
|------|------|------------|
| 两地三中心 DR | 月成本增加 30–50%，等用户量级稳定再上 | 月活 > 10 万 |
| 多账号治理 | Management/Security/Log Archive 三分离，适合大企业 | 团队 > 20 人 |
| GitOps (ArgoCD) | 手动部署更直观，等 CI/CD 流程稳定再自动化 | 每日发布 > 1 次 |
| Service Mesh (Istio) | 引入巨大的运维复杂度 | 服务数 > 20 |
| 混沌工程 (AWS FIS) | 玩坏了真会炸 | 有专职 SRE |
| 多 Region Active-Active | 成本翻倍，管理复杂度爆炸 | 监管强制要求或月活 > 100 万 |

**MVP 阶段建议的最小架构：**
> 单机 Docker + 单机 PostgreSQL + Redis + 简单 CI/CD（GitHub Actions 直接 `kubectl apply`）——这就是 plan A/B/C 的阶段。等业务验证了，再一步步升级到 plan D。

---

### 5. CAP 三选二，你的架构偏向哪个方向？

**答案：**

**CAP 定理是什么？**

> 你在一个图书馆（分布式系统）里借书。CAP 定理说：你只能同时满足两个，不可能三个都要。
> - **C（Consistency，一致性）**：你借的书，图书馆系统里立刻显示"已借出"，任何人查都是这个状态。
> - **A（Availability，可用性）**：图书馆永远开门，任何时候都能查书。
> - **P（Partition Tolerance，分区容忍）**：图书馆断网了，但还要继续工作。
>
> 现实是：断网（Partition）是必然发生的，所以 P 必须保证。你只能在 C 和 A 之间选。

**你的架构选择：**

| 组件 | 偏向 | 原因 |
|------|------|------|
| Aurora（主库） | **CP（强一致）** | 金融交易不能丢数据，优先保证一致性 |
| Redis（缓存） | **AP（高可用）** | Redis 挂了不影响交易，缓存命中率低只是慢 |
| 订单服务 | **CP** | 下单必须保证扣款和份额一致 |
| 基金净值查询 | **AP** | 净值查不到时返回"暂无数据"，不影响下单 |

**关键洞察：** 现代分布式系统不是全局选 CAP，而是在**不同组件/不同场景下做不同的选择**。就像你家的不同房间：保险柜要安全（CP），冰箱要随时能开（AP）。

---

### 6. CAP、必须这么做 vs 设计偏好

**答案：**

**必须这么做的（硬约束）：**
1. 用户资金数据必须一致（C）——这是监管要求，不是偏好
2. Secrets 不能明文存代码里——合规审计要求
3. 日志必须保留 7 年——金融监管强制
4. WAF + DDoS 防护必须上——金融行业合规
5. 两地三中心——如果是持牌机构，监管可能强制要求

**我选择这么做的（设计偏好）：**
1. 用 EKS 而不是 ECS Fargate → 我偏好 Kubernetes 生态和迁移便利性
2. 用 Karpenter 而不是 Cluster Autoscaler → 我觉得 Karpenter 响应更快
3. 用 ArgoCD 而不是 Jenkins → 我偏好 GitOps 的声明式管理
4. 用 Aurora PostgreSQL 而不是自建 PG → 我选择托管以减少运维负担
5. 用 Prometheus 而不是 CloudWatch Metrics → 我偏好开源可移植性

**回答技巧：** 面试时说清楚哪些是"我根据公司约束选的"，哪些是"我的技术偏好"，展示你有判断力而不是盲目追新。

---

### 7. 如果监管要求所有数据不得出境且必须私有化部署，你的架构需要做哪些改动？

**答案：**

**改动清单：**

| 改动项 | AWS 原方案 | 私有化替代 |
|--------|----------|-----------|
| 计算 | EKS | 自建 Kubernetes 或 OpenShift |
| 数据库 | Aurora（云托管） | 自建 PostgreSQL + 主从复制，或 TiDB / CockroachDB |
| 缓存 | ElastiCache（云托管） | 自建 Redis Sentinel 或 Cluster |
| 存储 | S3 | MinIO（兼容 S3 协议）或 Ceph |
| 镜像仓库 | ECR | Harbor（开源镜像仓库） |
| DNS | Route 53 | 自建 CoreDNS + 内部域名服务 |
| IAM | AWS IAM | 自建 Keycloak（OAuth/OIDC）或 OpenLDAP |
| 密钥 | AWS KMS | HashiCorp Vault |
| 监控 | AMP + AMG | Prometheus + Grafana 自建 |
| 日志 | CloudWatch Logs | ELK（Elasticsearch + Logstash + Kibana）或 Loki |
| CI/CD | GitHub Actions + ECR | GitLab CI + Harbor |
| 备份 | AWS Backup | Velero（K8s备份）+ pg_dump |

**关键洞察：** plan D 架构用的是**Kubernetes + 标准协议**（S3 API、Prometheus、OpenTelemetry），这些都可以在私有化环境中找到开源替代。云原生的核心价值是**架构模式，不是云厂商绑定**。所以改动虽然多，但**微服务拆分、GitOps、可观测性**这些模式不需要变。

---

### 8. 用户规模从 10w 增长到 1000w，哪里先瓶颈？

**答案：**

**按瓶颈出现顺序：**

**第一波（10w → 50w）：数据库**
> 想象一家小饭馆，开始人多了，厨房（DB）最先进不去。SQL 慢查询、没有索引的表、连接池耗尽——这些问题会首先爆发。
- Aurora 的自动扩展（最高 128TB）和 RDS Proxy（连接池）能扛一阵
- 但要开始优化慢查询、加索引、做读写分离

**第二波（50w → 200w）：网络带宽**
> NAT Gateway 的流量费开始飙升。CloudFront 如果没做好缓存，回源带宽也是问题。
- VPC Endpoint 大规模使用可以减少 NAT 流量

**第三波（200w → 500w）：微服务间调用**
> 5 个服务之间的调用量指数级增长。一个订单要查用户、查基金、查持仓——这些串行调用加起来，P99 延迟爆炸。
- 这时要考虑：并行调用（CompletableFuture）、服务间缓存、热点数据本地缓存

**第四波（500w → 1000w）：EKS 节点数上限**
> EKS 每个节点（EC2）的 Pod 数量有限制（约 30–110 个）。节点多了，EKS Control Plane 的 API 请求量也会成为瓶颈。
- Karpenter 自动扩容 + 节点分组优化

---

### 9. 为什么不选 Serverless（Lambda）？什么场景会改用？

**答案：**

**不选 Lambda 的原因：**

1. **冷启动延迟**：Java Lambda 冷启动 3–10 秒。基金下单这种高频操作等不起。
2. **长时间运行有瓶颈**：Lambda 最长 15 分钟。日终批量对账可能要跑 30 分钟。
3. **调试困难**：分布式追踪在 Lambda 里比在 Pod 里复杂。
4. **成本曲线不同**：Lambda 按请求计费，在高 QPS（> 1000 req/s）场景下比 EKS 贵。

**用快递比喻：**
> Lambda 就像即时快递（闪送），你叫一单来送一份文件很快很便宜。但如果你每天要送 10000 份文件，自己养一个快递员（EKS Pod）反而更便宜。

**会改用 Serverless 的场景：**
- **文件处理**（PDF 生成、图片压缩）：Lambda + S3 trigger，成本低，无需长期运行
- **Webhook 接收**（基金公司的回调通知）：Lambda 处理偶发性、不频繁的事件
- **定时任务**（日终对账的轻量部分）：EventBridge + Lambda，不需要常驻机器
- **突发流量**（营销活动引流）：Lambda 自动扩缩，不需要提前准备容量

---

### 10. 为什么不选 ECS Fargate 而选 EKS？

**答案：**

**核心差异：用"公寓"比喻**

> **ECS Fargate** = 精装公寓。你租一个房间，物业（AWS）负责所有公共设施（水电、安保、电梯）。你只管住。但房间的布局是固定的，不能随便砸墙装修。
>
> **EKS** = 毛坯房自己装修。你有完全的装修自由度（K8s 完全控制），但你要自己负责更多的维护工作。

**选 EKS 的原因：**
1. **团队有 K8s 经验**：Kubernetes 是行业标准，人才多，文档多，社区活跃
2. **多租户隔离**：smart-invest 以后可能接入不同机构，需要 NetworkPolicy、RBAC 精细隔离
3. **迁移便利**：EKS 在任何云（AWS、Azure、阿里云）都有，不用担心厂商锁定
4. **成本**：Fargate 按 vCPU/内存-秒计费，高利用率下比 EKS EC2 贵 30–50%

**选 Fargate 的场景：**
- 团队没有 K8s 经验，想快速上线
- 工作负载波动剧烈，不想管节点
- 纯 stateless 的轻量服务，不需要长期运行

---

## 三、AWS 服务与多账号治理

### 1. 为什么要拆 5 个 AWS 账户？一个账户不行吗？

**答案：**

**用一个公司来比喻：**

> 一个大公司如果所有部门（财务、HR、技术、销售）都在同一个大办公室里：
> - 财务的保险柜密码大家都知道，销售不小心改了就完了
> - 一个人犯了错（安全事件），整个公司都受影响
> - 成本不分摊，每个部门都说"我的预算很紧张"
>
> 所以大公司会分楼层、分部门，每个部门有自己的门禁卡（隔离）。

**5 个账户的分工：**

| 账户 | 作用 | 隔离目的 |
|------|------|--------|
| Management | AWS 根账户的核心管理 | 不能用于日常操作，只能做组织级操作 |
| Security | 安全工具（GuardDuty、Security Hub、IAM Access Analyzer） | 安全团队有独立权限，不影响生产 |
| Log Archive | 集中存储所有账户的 CloudTrail 和日志 | 日志一旦写入，任何账户（包括 Root）都不能删除 |
| Production | 真实生产环境 | 开发人员默认没有写权限，需要审批 |
| Staging | 测试环境 | 和生产配置一致，但不能碰真实数据 |

**用一个账户的灾难：** 2020 年某公司实习生在生产账户误执行 `rm -rf`，删掉了整个生产数据库。**多账户意味着即使一个账户的权限被滥用，损失也有限。**

---

### 2. AWS Organizations + SCP 能防住什么？防不住什么？

**答案：**

**SCP = 公司总部的"安全制度"，贴在每个部门门口，所有人都必须遵守。**

**能防住的：**
- ✅ 防员工把账户从组织里移出（DenyLeavingOrg）
- ✅ 防不使用 MFA 就操作高危 API（RequireMFA）
- ✅ 防在未批准区域创建资源（监管合规）
- ✅ 防把 S3 桶设为公开（数据泄露防护）

**防不住的：**
- ❌ **SCP 不授权，只"限制"**。如果 IAM 没有给权限，SCP 开了也没用
- ❌ 不能限制 Root 账户的所有操作（除了组织级别）
- ❌ 不能限制同一账户内的"跨服务"调用（比如 Lambda 读写 S3，两边权限都满足就放行）
- ❌ 不能检测"权限逐渐扩大"（privilege creep）——你需要 IAM Access Analyzer

**关键比喻：**
> SCP 像是机场的安检（扫描行李，不让危险品上飞机）。但如果你有登机牌（IAM权限），安检拦不住你。所以 SCP + IAM 才能真正安全。

---

### 3. DenyRegionsNotApproved 会误伤哪些全局服务？

**答案：**

**误伤案例：**

| 被误伤的服务 | 原因 |
|------------|------|
| S3（全局服务） | S3 的控制面操作（如 `ListBuckets`）在 us-east-1 发起，不在 region |
| IAM（全局服务） | IAM 角色创建默认 global，如果限制 region，IAM 就废了 |
| CloudFront（边缘服务） | CloudFront 在全球 600+ PoP，不属于任何 region |
| Route 53 | DNS 是全球服务 |
| SES（Simple Email Service） | 某些 region 没有，需要跨 region 引用 |

**正确做法：** 在 SCP 里对 S3、IAM、CloudFront、Route 53 这些**全局服务**单独开白名单：
```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "aws:RequestedRegion": ["us-east-1", "us-west-2"]
    },
    "ArnNotLike": {
      "aws:PrincipalARN": [
        "arn:aws:iam::*:role/*"  // IAM 操作全球有效，白名单
      ]
    }
  }
}
```

---

### 4. Log Archive 账户里的日志如何防止被 Root 管理员删除？

**答案：**

**三层防护：**

**第一层：S3 Object Lock（WORM）**
> 就像银行金库的门，写进去的文件 7 年内谁也删不了。这不是权限问题，是物理上删不掉。
```bash
aws s3api put-object-lock-configuration \
  --bucket log-archive-bucket \
  --object-lock-configuration '{"Rule":[{"DefaultRetention":{"Mode":"COMPLIANCE","Years":7}}]}'
```

**第二层：Vault Lock**
> S3 Glacier 的 Vault Lock 就像"刻在石头上"，一旦锁定，AWS 自己也没有能力删除。

**第三层：跨账户权限**
```
生产账户 → 写入 Log Archive 账户的 S3
Log Archive 账户 → 只有写入权限，没有删除权限
Management 账户 → 可以管理 Vault Lock，但操作被 CloudTrail 记录
```

**类比：** 就像你把重要的文件放进银行的保险箱（Log Archive），钥匙在你手里（Write 权限），但保险箱的锁（Object Lock）是银行的规矩，规定必须保留 7 年，连银行经理都打不开。

---

### 5. Control Tower、Organizations、Landing Zone 的关系？

**答案：**

**三者的关系——城市比喻：**

| 概念 | 比喻 | 说明 |
|------|------|------|
| AWS Organizations | 城市规划局 | 管理所有"城区"（账户），制定总规 |
| AWS Landing Zone | 城市基础设施标准 | 水电气管网、公交系统、道路标准，新城区必须按这个标准建 |
| AWS Control Tower | 城市建设的"标准装修公司" | 自动帮你按 Landing Zone 标准创建账户、配置 SCP、设置审计 |

**简单说：**
- Organizations = 定义"有什么账户"
- Landing Zone = 定义"账户里应该有什么"
- Control Tower = 帮你**自动化落地** Landing Zone 标准

**我们用了哪个？**
plan D 文档里提到的是 Organizations + 手动配置 SCP，所以应该是**没用 Control Tower**，而是手动搭建 Landing Zone。这样更灵活，但需要更多人工维护。

---

### 6. 管理员如何安全地跨账户操作？

**答案：**

**方法：用临时通行证代替长期钥匙**

**类比：**
> 你去政府办事大厅，工作人员不能用自己的身份证进各个窗口，而是刷一张临时工作卡（AssumeRole），这张卡 1 小时后自动失效，需要重新刷。而且刷的时候要输 PIN 码（MFA）。

**具体流程：**
1. 管理员在 IAM Identity Center（AWS SSO）登录（通常用公司 SSO）
2. 选择目标账户和角色（如 `Production-AdminRole`）
3. 如果是高危操作（如删除资源），触发 MFA 验证
4. AWS 返回临时凭证（AccessKey + SecretKey + Token），有效期 1 小时
5. 用临时凭证操作目标账户
6. 1 小时后凭证自动失效，无法继续操作

**好处：**
- 管理员不需要在每个账户存储长期 AccessKey（长期密钥丢了就完了）
- 操作被完整记录在 CloudTrail 里（谁、什么时间、以什么身份、做了什么）
- MFA 确保即使密码泄露，没有手机也拿不到临时凭证

---

## 四、网络架构（VPC / 子网 / Security Group / VPC Endpoint）

### 1. VPC CIDR 为什么是 10.0.0.0/16？多 region 怎么规划？

**答案：**

**CIDR 是什么？**

> 可以理解为一个小区里门牌号的编址规则。`10.0.0.0/16` 表示：从 10.0.0.0 到 10.0.255.255，一共有 65,536 个门牌号（IP 地址）。

**为什么选 10.0.0.0/16？**
- 192.168.x.x 是家庭网络常用的，不能和公司 VPN 冲突
- 172.16–172.31 是 Docker/K8s 内部网络常用，可能冲突
- 10.x.x.x 是 RFC1918 保留的大企业内网段，和大多数内部网络兼容性好

**多 region 避免冲突：**
| Region | CIDR | 说明 |
|--------|------|------|
| us-east-1 | 10.0.0.0/16 | 65536 个 IP |
| us-west-2 | 10.1.0.0/16 | 用 10.1 而不是 10.0，避免重叠 |

**类比：** 每个小区用不同的楼号段。北京小区从 1 号楼开始，杭州小区从 101 号楼开始。这样两地的快递员（网络流量）永远不会把信送到对方小区。

---

### 2. 三层子网的设计原因？数据库放 Private App 会怎样？

**答案：**

**三层子网结构：**

```
┌─────────────────────────────────────────────────────┐
│  Public Subnet（公网子网）                           │
│  NAT Gateway（出公网） + ALB 的 ENI（接收公网流量）   │
├─────────────────────────────────────────────────────┤
│  Private App Subnet（私有应用子网）                   │
│  EKS Worker Node（运行业务 Pod）                     │
│  Redis（需要被 App 访问，但不需要直接暴露公网）        │
├─────────────────────────────────────────────────────┤
│  Private Data Subnet（私有数据子网）                  │
│  Aurora（RDS）——最核心的数据，最小暴露面              │
│  RDS Proxy——连接池，介于 App 和 DB 之间              │
└─────────────────────────────────────────────────────┘
```

**为什么这样分？**

> 就像一栋银行大楼：
> - 临街门面（Public Subnet）：客户从 ATM 机取钱（ALB）
> - 营业大厅（Private App Subnet）：柜员处理业务（EKS Pod）
> - 金库（Private Data Subnet）：数据库在里面（DB），普通柜员都进不去

**数据库放 Private App 会怎样？**
- **风险增加**：EKS Node 和 Aurora 之间没有分离。如果某个 Pod 被攻破，攻击者在内网可以直接扫描到 DB 的 IP。
- **合规风险**：金融行业要求核心数据（DB）必须在最内层子网，和应用层有网络隔离。
- **但实际上**：Aurora 本身有 Security Group 保护，放在 Private Data Subnet 和 Private App Subnet 的**网络延迟差异可以忽略**（都在同一个 VPC 内），所以放更内层只有好处没有坏处。

---

### 3. NAT Gateway 为什么每个 AZ 一个，不是共用一个？

**答案：**

**高可用原则：每个 AZ 独立，AZ 挂了不影响其他 AZ。**

**共用一个 NAT GW 的灾难场景：**
> 你家和邻居共用一个电表箱，某天电表箱坏了（AZ 故障），你家和邻居都停电了。

**每个 AZ 一个 NAT GW：**
> 你家和邻居各自有自己的电表箱。邻居家的电表箱坏了（AZ-a 故障），只有邻居停电，你家继续正常用电。

**架构设计：**
```
us-east-1a 的 Private Subnet → NAT GW-a → 公网
us-east-1b 的 Private Subnet → NAT GW-b → 公网
us-east-1c 的 Private Subnet → NAT GW-c → 公网
```

**成本考量：** 3 个 NAT GW 比 1 个贵 3 倍，但**可用性提高了 3 倍**。对于金融系统，这个成本是值得的。如果降到 1 个 NAT GW，每个 AZ 的 Pod 都要跨 AZ 走 NAT（跨 AZ 流量也要钱），而且一个 AZ 挂了所有 Pod 都断网。

---

### 4. NAT Gateway 带宽上限是多少？并发拉镜像打满怎么办？

**答案：**

**NAT Gateway 的限制：**
- **带宽**：NAT Gateway 本身没有硬性带宽上限，但受到 EC2 实例类型和网络带宽限制（最大 100Gbps）
- **并发连接数**：每个 NAT Gateway 最大 **55,000 个并发 TCP 连接**（源端口限制）
- **新建连接速率**：每秒最多 **85,000 个新连接**

**Pod 并发拉镜像打满 NAT 的问题：**

> 想象一个大商场开门，所有顾客同时涌进来（Pod 同时拉取镜像），门口的闸机（NAT Gateway）就被挤爆了。

**解法：VPC Endpoint for ECR**
```
不用：Pod → NAT GW → 公网 → ECR（慢、贵、被限流）
用 VPC Endpoint：Pod → ECR API/DKR Endpoint（直接走 AWS 内部网络，快、免费）
```
- VPC Endpoint 是 AWS 内部网络互联，**不经过公网，不占用 NAT Gateway 带宽**
- ECR 拉镜像走 VPC Endpoint 后，NAT Gateway 的压力大幅降低

---

### 5. 十几个 VPC Endpoint 是为了什么？

**答案：**

**VPC Endpoint 的核心价值：流量不出 AWS 网络**

**不用 VPC Endpoint 时：**
> 你在网上买东西，快递要先送到你家门口，再绕到你邻居家，再绕回快递柜，再送回你家——绕了一大圈（走了公网 NAT），既费钱又费时，还可能被"快递员"（公网黑客）截获。

**用 VPC Endpoint 时：**
> 你在网上买东西，快递从仓库直接送到你家小区的快递柜（AWS 内部网络），中间不经过公网。

**每个 VPC Endpoint 的作用：**

| Endpoint | 服务 | 为什么需要 |
|----------|------|-----------|
| S3 Gateway | 存储 | 日志、备份、静态文件 |
| ECR API | 镜像仓库 | Pod 拉取镜像 |
| ECR DKR | Docker | Pod 运行容器 |
| Secrets Manager | 密钥 | IRSA 拿密钥、Pod 启动 |
| SSM | 系统管理 | kubectl 运维命令 |
| CloudWatch Logs | 日志 | Fluent Bit 推送日志 |
| STS | 身份 | IRSA 认证 |
| KMS | 加密 | 数据库加密、密钥操作 |
| EKS | API | 集群 API Server |
| X-Ray | 追踪 | 分布式追踪数据 |
| SNS | 消息 | 异步通知 |
| SES | 邮件 | 发送邮件验证码 |

**成本影响：** VPC Endpoint 是免费的（Interface Endpoint 按小时+流量计费，但远低于 NAT Gateway 的出口流量费）。

---

### 6. Gateway Endpoint vs Interface Endpoint 的区别？

**答案：**

| 特性 | Gateway Endpoint | Interface Endpoint |
|------|-----------------|-------------------|
| 服务 | S3、DynamoDB | 其他服务（ECR、Secrets Manager等） |
| 原理 | 在路由表里加一条路由，走 AWS 内部网络 | 给你分配一个私有 IP（ENI），走这个 IP 访问 |
| 计费 | 免费 | 按小时 + 按流量 |
| HA | 自动（AWS 托管） | 每个 AZ 一个，AZ 挂了那个 IP 不通 |
| 性能 | 极高（直连） | 有一定延迟（多了 ENI 层） |

**用邮局比喻：**
> **Gateway Endpoint** = 同一个城市内的邮筒，信不用出城，直接在城市内部网络里走。免费、快速。（S3、DynamoDB）
>
> **Interface Endpoint** = 城市里有一个收发室（ENI），你的信先送到收发室，收发室再帮你转寄。收发室要收费，但更安全可控。

---

### 7. Security Group vs NACL，为什么架构里没画 NACL？

**答案：**

**NACL = 大楼门口的安保（子网级别），Security Group = 房间的门禁卡（实例级别）**

| 维度 | NACL（子网级别） | Security Group（实例级别） |
|------|---------------|----------------------|
| 作用层级 | 整个子网 | 单个 EC2/ENI/Pod |
| 规则类型 | Allow + Deny（白名单/黑名单）| 仅 Allow（默认拒绝）|
| 有状态吗 | 无状态（往返都要单独放行）| 有状态（自动放行返回流量）|
| 评估顺序 | 按规则号顺序 | 所有规则同时评估 |

**为什么架构里没重点画 NACL？**

> 因为 NACL 的"无状态"特性很容易搞混：如果放行入站 80 端口，**出站 80 端口的返回流量并不会自动放行**（需要单独配置）。这让规则维护变得复杂。

**实际最佳实践：** 在 AWS 上，**Security Group 就够了**（它是双向有状态的）。NACL 只在极少数场景需要：
1. 显式阻断某个 IP 段（如已知恶意 IP 黑名单）
2. 子网级别的审计流量

**用小区管理比喻：**
> NACL = 小区大门保安，查所有进出的人。无状态意味着：你进去了，不一定代表你能出来。
> Security Group = 房间门禁卡。有状态意味着：你进了门，出门自动刷卡，不用再验证。

---

### 8. Security Group 怎么组织的？为什么"SG 引用 SG"比 IP 好？

**答案：**

**架构里的 SG 组织：**
```
alb-sg        → 允许来自 CloudFront/WAF 的流量（0.0.0.0/0 或 prefix list）
eks-node-sg   → 允许来自 alb-sg 的流量
aurora-sg     → 允许来自 eks-node-sg 的流量
redis-sg      → 允许来自 eks-node-sg 的流量
vpce-sg       → 允许来自 eks-node-sg 的流量
```

**"SG 引用 SG"的好处：**

**类比1 - 门牌号 vs 员工卡：**
> 告诉保安"3号楼的5层的人可以进来"（IP CIDR）= 你告诉保安"穿蓝色衣服的人可以进来"（SG 引用）。当楼层重新装修（IP 变了），穿蓝色衣服的人（SG）不变，保安规则不用改。

**类比2 - 手机号 vs 姓名：**
> 用 IP 白名单 = 记别人的手机号（数字太多容易记错）用 SG 引用 = 记别人的名字（简单清晰）。手机号换了（EC2 换了 IP），人还是同一个人（SG 不变），规则继续有效。

**技术优势：**
- 扩容/缩容时 Pod/Node IP 变了，规则不变
- SG 在 AWS 内部解析，不用记具体 IP
- 审计时"哪个服务能访问哪个"一目了然

---

### 9. K8s Network Policy 和 AWS SG 有什么区别？为什么两者都要？

**答案：**

**用"城市交通规则"比喻：**

| 层级 | 比喻 | 作用范围 |
|------|------|---------|
| AWS SG | 城市边界检查站 | 整个 AWS 账户范围内的网络入口 |
| K8s Network Policy | 建筑物内的楼层门禁 | Pod 与 Pod 之间的访问控制 |

**例子：**

```
AWS SG 说：
"eks-node-sg 里的机器可以访问 aurora-sg 的数据库"（企业→金库）

K8s Network Policy 说：
"order-service 的 Pod 可以访问 portfolio-service 的 Pod，但 fund-service 的 Pod 不行"
（企业→企业：销售部可以和财务部通信，但市场部不行）
```

**为什么两者都要？**

- **AWS SG**：第一道防线，挡住外部入侵（相当于城市边界墙）
- **K8s Network Policy**：第二道防线，挡住内部横向移动（相当于楼层门禁）
- 金融合规要求"最小权限"：不仅外部不能打进来，内部 Pod 之间也不能随便互通

**类比：** 就像你去医院：门口保安检查你能不能进大楼（AWS SG），护士站检查你能不能进某个科室（K8s Network Policy）。两层都通过才算数。

---

## 五、EKS 与 Kubernetes 深度

### 1. EKS Control Plane 是 AWS 托管的，你还关心什么？

**答案：**

**把 EKS Control Plane 想象成出租车的自动驾驶系统：**

> 你坐出租车（EKS），车是滴滴平台提供的（AWS），方向盘、发动机、导航系统都是平台在管（Control Plane = API Server + etcd + Scheduler）。但你还要关心：
> - 车有没有定期保养（版本升级）
> - 平台有没有把车租给坏人（OIDC Provider 安全配置）
> - 紧急刹车有没有开启（审计日志）
> - 发动机有没有加密（AES-256 加密的 etcd）

**你需要关心的 5 件事：**

1. **私有 API Endpoint**（不要开公有端点！）
   > 想象你的公司大门，不需要把内部会议室的门牌号公开给所有人

2. **etcd KMS 加密**
   > 存放在 etcd 里的数据（Pod 配置、Secret 引用等）默认是加密的，防止 AWS 员工偷看你的数据

3. **OIDC Provider（认证入口）**
   > AWS 和 EKS 之间的"信任协议"，没有它 IRSA 不工作

4. **审计日志（CloudWatch Logs）**
   > 谁在什么时间通过 kubectl 做了什么操作，必须记录

5. **版本升级（你决定节奏）**
   > AWS 负责升级 Control Plane，但你要选择什么时候升级（通常等 minor version 稳定后再升）

---

### 2. EKS 版本升级策略？怎么保证零停机？

**答案：**

**升级策略：汽车换轮胎比喻**

> 想象你有一辆大巴（EKS 集群），上面坐满了乘客（Pod）。轮胎（Node Group）磨损了需要换。你不能把车停下来换（服务中断），而是：
> 1. 先在旁边停一辆新车（新 Node Group，装着新轮胎）
> 2. 慢慢把乘客从旧车迁移到新车（Cordon + Drain 旧节点）
> 3. 确认新车运行正常后，旧车离开（Deletion of old Node Group）

**具体步骤：**

```
1. 升级 CRD（如 cert-manager、argo-rollouts 的 CRD）
   （先升级配件，再升级发动机）

2. 升级 Managed Node Group（一个 AZ 一个节点组依次升级）
   - 创建新节点组（新版 K8s）
   - Cordon 旧节点（"不要再分配新任务了"）
   - Drain 旧节点（"正在运行的任务优雅停止，迁移到新车"）
   - 删除旧节点

3. 升级 Control Plane（AWS 自动化做，约 30 分钟）
   - 零手动干预，零停机

4. 升级 kube-proxy、CNI 等系统组件
```

**保证零停机的关键机制：**

| 机制 | 作用 |
|------|------|
| **PDB (Pod Disruption Budget)** | 确保每个 deployment 至少有 N% 的 Pod 在运行 |
| **Surge upgrade** | 允许同时存在比 desired 更多的新 Pod，实现无缝滚动 |
| **HPA** | 扩容 Pod 以接收迁移流量 |
| **readinessProbe** | Pod 真正ready才接收流量 |

---

### 3. Node Group 分了 4 类，怎么确保关键 Pod 不被调度到 Spot？

**答案：**

**用"医院分诊"比喻：**

| Node Group | 病床类型 | 病人 |
|-----------|---------|------|
| system-ng（t3.medium）| VIP 单人病房 | kube-system 的 Pod（系统组件） |
| app-ondemand-ng（m5.large）| 普通病床 | 关键业务 Pod（order-service） |
| app-spot-ng | 临时加床 | 非关键 Pod（后台批处理） |
| gpu-ng（g4dn）| ICU | AI 模型训练 Pod |

**保证关键 Pod 不上 Spot 的方法：**

**方法 1：nodeSelector + taint/toleration（显式声明）**
```yaml
# order-service 显式说"我不要睡临时加床"
nodeSelector:
  node.kubernetes.io/lifecycle: ondemand

# app-spot-ng 给节点打上标签
kubectl label node <spot-node> node.kubernetes.io/lifecycle=spot

# 或者用 taint（污点）
kubectl taint node <spot-node> dedicated=spot:NoSchedule
# order-service 显式说"我能忍受污点吗？" → 不能，默认不调度
```

**方法 2：PriorityClass（优先级调度）**
> 急诊病人（高 PriorityClass）优先占用普通病床（ondemand），临时床位（spot）留给普通病人（低 PriorityClass）。
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 100000
globalDefault: false
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  template:
    spec:
      priorityClassName: high-priority  # 优先级高，抢占 spot
```

---

### 4. Karpenter vs Cluster Autoscaler，你为什么选 Karpenter？

**答案：**

**用"餐厅厨师配置"来比喻：**

| 工具 | 做法 |
|------|------|
| Cluster Autoscaler | 老板每天固定配 10 个厨师（固定节点数），活多了就提前说"明天多配 2 个"，活少了就减 |
| Karpenter | 老板不管厨师数量，餐厅里没位置了自动叫新厨师，活少了自动让厨师下班，更灵活 |

**Karpenter 的优势：**

1. **更快**：Cluster Autoscaler 每 30 秒检测一次，Karpenter 基于事件（Pod unschedulable）立刻响应
2. **更灵活**：Cluster Autoscaler 只能按 Node Group 扩容，Karpenter 直接按 Pod 需求选择最优 EC2 实例类型
3. **成本更低**：不用提前规划实例类型，Pod 需要 4 核 16G，Karpenter 自动找最便宜的 spot 实例
4. **配置更少**：不需要预设 Node Group，减少了 YAML 配置量

**Karpenter 的弱点：**
- 社区相对新（2021 年才稳定），文档不如 Cluster Autoscaler 丰富
- 如果你的 Pod 调度策略非常复杂，Cluster Autoscaler 的 Node Group 模式反而更容易理解

---

### 5. Spot 中断 2 分钟警告，如何优雅处理？

**答案：**

**AWS 给的 2 分钟警告 = "这辆车 2 分钟后要报废了，请下车"**

**优雅处理流程：**

```
AWS 发送 Spot Interruption Warning（2分钟前）
    ↓
AWS Node Termination Handler（自动监听）
    ↓
① 标记节点为即将终止（Cordon）
    → 新 Pod 不再调度到这台机器
    ↓
② 优雅终止 Pod（Graceful shutdown）
    → Pod 收到 SIGTERM，等待 terminationGracePeriodSeconds（默认 30 秒）
    → Pod 完成当前请求，停止接收新请求
    → 如果有 preStop hook，执行清理逻辑
    ↓
③ PDB 检查
    → 确保最小可用 Pod 数，不影响业务
    ↓
④ Pod 被驱逐，重新调度
    → Karpenter 自动创建新节点
    → Pod 在新节点重新启动
```

**业务保护措施：**
- **Redis 缓存当前请求状态**：即使 Pod 挂了，请求结果已写入 Redis，新 Pod 可以继续处理
- **幂等设计**：同一订单 ID 的请求无论执行几次，结果都是一样的
- **前端兜底**：用户看到"正在处理"而不是"失败"，由前端轮询确认最终状态

---

### 6. HPA 的指标从哪里来？基于 CPU 够用吗？

**答案：**

**用"餐厅排队叫号"比喻：**

> 餐厅（Service）里厨师（Pod）的数量应该根据**排队人数（Queue Length）**来决定，而不是根据厨房的温度（CPU）。
> - 厨房很热（CPU 高）但没人排队 → 不需要加厨师
> - 没人排队（Queue 低）但厨师很累（CPU 高）→ 可能需要减厨师

**标准指标够用的情况（简单判断）：**
```
CPU 使用率 > 70% → 扩容
CPU 使用率 < 30% → 缩容
```
这个规则适合：Web 服务、API 服务（CPU 和 QPS 线性相关）

**自定义指标更精准的情况：**

| 场景 | 推荐指标 | 原因 |
|------|---------|------|
| 下单接口 | `orders_in_flight`（飞行中订单数）| CPU 高不代表在处理下单，可能在 GC |
| 异步处理 | Kafka Consumer Lag | 队列堆积比 CPU 更准确反映负载 |
| AI 推理 | GPU 利用率 | CPU 和 GPU 利用率可能完全无关 |
| 缓存服务 | 命中率 / 内存使用率 | 内存满了比 CPU 更危险 |

**实现方式：Prometheus Adapter**
```
Prometheus（采集 metrics）
    ↓
Prometheus Adapter（转换为 K8s HPA 格式）
    ↓
HPA Controller（读取自定义 metrics）
    ↓
扩/缩 Pod
```

---

### 7. Pod Security Admission 的 baseline vs restricted profile？

**答案：**

| 限制项 | baseline（宽松） | restricted（严格） |
|--------|---------------|----------------|
| runAsNonRoot | 不强制 | **强制**（必须以非 root 运行）|
| readOnlyRootFilesystem | 不强制 | **强制**（根文件系统只读）|
| capabilities.drop | 建议 drop ALL | **强制 drop ALL** |
| seccompProfile | 不强制 | **强制 RuntimeDefault** |
| 特权 Pod | 允许 | **禁止** |

**我们的架构要求 `runAsNonRoot + readOnlyRootFilesystem + drop ALL capabilities`，接近 restricted 级别。**

**Spring Boot 适配只读根文件系统：**

```yaml
# Pod 层面配置
securityContext:
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000

# 挂载可写目录（用 emptyDir，临时存储）
volumeMounts:
  - name: tmp-storage
    mountPath: /tmp
  - name: app-logs
    mountPath: /app/logs

# Spring Boot 层面配置（application.yml）
logging:
  file:
    name: /app/logs/application.log  # 写到可写目录
```

---

### 8. IRSA 的完整认证链能画出来吗？

**答案：**

**IRSA = "员工用公司工卡刷门禁，门禁系统帮他开对应的储物柜"**

**完整流程（8步）：**

```
① Pod 启动时，K8s 读到 ServiceAccount 的 annotation
   annotation 告诉 K8s："这个 Pod 需要一个 AWS IAM 角色"

② K8s 为 Pod 挂载一个 "projected volume"（特殊目录）
   这个目录包含：OIDC token（临时身份证）

③ Pod 里的应用（如 Spring Boot）访问 AWS 服务
   SDK（如 AWS SDK for Java）自动检测到这个 token

④ AWS SDK 调用 STS（Security Token Service）
   请求："我用这个 OIDC token，能给我对应的 IAM 角色权限吗？"

⑤ STS 验证 OIDC token 的签名
   → 问 EKS OIDC Provider："这个 token 是真的还是伪造的？"

⑥ EKS OIDC Provider 验证后返回："是真的，可以信任"

⑦ STS 返回给 Pod
   → 临时 AccessKey + SecretKey + Token（有效期最长 12 小时）

⑧ Pod 用这个临时凭证访问 AWS 资源
   → 比如从 Secrets Manager 拿数据库密码
```

**类比（酒店入住）：**
> ① 你（Pod）在前台说"我要用健身房"（annotation）
> ② 前台给你一张房卡（projected volume）
> ③ 你刷房卡去健身房（应用请求 AWS）
> ④–⑥ 健身房门禁系统打电话给前台确认"这个房卡是有效的"（STS 验证 OIDC）
> ⑦ 门禁开了，给你临时手环（临时凭证）
> ⑧ 你戴着手环健身（用凭证访问 AWS 资源）

---

### 9. IRSA 和 EKS Pod Identity 的区别？

**答案：**

| 维度 | IRSA | EKS Pod Identity |
|------|------|----------------|
| 配置位置 | ServiceAccount annotation | AWS 控制台/CLI |
| OIDC Provider | 需要手动创建 | AWS 托管，不用管 |
| 每个 Pod | 绑定一个 IAM Role | 绑定一个 IAM Role |
| Role 数量上限 | 无特别限制（受 IAM 限制）| 无特别限制 |
| 适合场景 | GitOps（所有配置在代码里）| AWS 控制台管理（更简单）|

**简单说：EKS Pod Identity 是"更简单的 IRSA"** ——不需要你手动创建 OIDC Provider，AWS 帮你托管了。

**会迁移到 Pod Identity 吗？**
- 如果团队没有 GitOps 全流程管理能力，Pod Identity 更简单
- 如果已经稳定使用 IRSA，不值得花时间迁移（功能完全一样）

---

### 10. Secrets Store CSI Driver 和直接用 K8s Secret 有什么区别？

**答案：**

**直接用 K8s Secret 的问题：**
- Secret 存在 etcd 里，etcd 泄漏 → 所有 Secret 泄漏
- Secret 在 Pod 里是 base64 明文（不是加密！）
- Secret 更新需要重启 Pod

**Secrets Store CSI Driver = "外卖柜"比喻：**

| 方式 | 做法 | 问题 |
|------|------|------|
| K8s Secret | 餐厅把密码写在纸条上，塞进门缝里给你 | 纸条可能被人捡到（etcd 明文）|
| CSI Driver | 餐厅把密码放在外卖柜里，你到了用手机验证码取 | 外卖柜（Secrets Manager）是真正的保险箱，K8s 里只有"取货码"没有实际密码 |

**CSI Driver 的优势：**

1. **真正的加密**：密码在 AWS Secrets Manager 里加密（KMS），K8s 里只有引用
2. **动态更新**：Secrets Manager 里改密码，Pod 自动同步（无需重启）
3. **审计**：谁在什么时候取了什么 Secret，CloudTrail 记录得清清楚楚
4. **审计合规**：密码不在 etcd 里，etcd 备份泄漏也不影响

---

## 六、微服务与 Spring Boot

### 1. 5 个服务的通信模式？

**答案：**

**用"快递公司"比喻服务间通信：**

| 模式 | 比喻 | 适用场景 |
|------|------|---------|
| **同步 REST** | 同城闪送，对方必须马上收 | 下单 → 查基金净值、查用户信息 |
| **异步消息** | 普通快递，放快递柜就行 | 下单成功 → 更新持仓、发送通知 |
| **事件驱动** | 广播通知，所有人都收到 | 基金净值更新 → 所有相关方刷新缓存 |

**具体通信设计：**

```
order-service（下单）
    ↓ 同步调用  fund-service（查净值）
    ↓ 同步调用  user-service（查用户风测结果）
    ↓ 异步事件  portfolio-service（更新持仓）→ Redis Stream / SNS
    ↓ 异步事件  notification-service（发通知）→ SNS → Email/SMS
```

**为什么不全部用同步？**
> 同步调用就像打电话：对方不接你就卡住了。异步就像发微信：发了就行，对方有空再看。如果 fund-service 挂了，同步调用会让 order-service 也卡住，所以 fund-service 调用用超时+降级兜底。

---

### 2. 服务间调用选了什么？为什么不用 Feign/Dubbo/gRPC？

**答案：**

**为什么用 RestTemplate / WebClient（同步） + 消息队列（异步）：**

**Feign（Spring Cloud 声明式 HTTP 客户端）的缺点：**
- 增加了 Spring Cloud 依赖，升级复杂
- 对 K8s + IRSA 环境的支持不如原生 AWS SDK
- 适合 Spring Cloud 全家桶，但我们的架构是 K8s 第一

**Dubbo（阿里开源 RPC 框架）的缺点：**
- 需要注册中心（Zookeeper/Nacos），增加了运维复杂度
- 和 AWS 生态集成不深
- 团队没有经验

**gRPC（Google RPC）的缺点：**
- 需要 .proto 文件定义接口，团队学习成本高
- HTTP/2 调试困难（不能用普通 curl）
- 适合强类型+高性能场景（如 AI 推理），不适合 web 业务

**我们的选择（过渡方案）：**
- 同步：Spring 的 `RestTemplate`（简单够用）→ 未来迁移到 `WebClient`（异步非阻塞）
- 异步：`AWS SNS` + `Spring Cloud AWS` 集成
- 未来考虑：`gRPC` 用于对延迟敏感的内部调用

---

### 3. 分布式事务：订单扣款 + 份额入账 + 持仓更新，怎么处理？

**答案：**

**用"餐厅订座"比喻 Saga 模式：**

> 你在网上订餐厅：① 选座（预留位置）② 付定金（扣款）③ 餐厅确认（份额入账）
> 如果③失败，②自动退款（补偿事务）。
> 整个过程不是在一个窗口完成的（不是单体事务），而是通过一系列可撤销的操作完成。

**Saga 的实现（Order 服务主导）：**

```java
// 伪代码
public void placeOrder(OrderRequest request) {
    // Step 1: 预校验（风测、余额）
    userService.validate(request.getUserId());

    // Step 2: 扣款（ Saga 中的 Action）
    paymentService.debit(request.getUserId(), request.getAmount());

    // Step 3: 创建订单
    Order order = orderRepository.save(new Order(PENDING));

    // Step 4: 发消息异步更新持仓（补偿事务通过消息队列实现）
    eventPublisher.publish(new OrderPlacedEvent(order));
    // → portfolio-service 收到后更新持仓
    // → 如果失败，发送 OrderFailedEvent，paymentService 补偿退钱
}
```

**补偿事务（回滚）：**
```java
// 如果份额入账失败了，触发补偿
public void handleOrderFailedEvent(OrderFailedEvent event) {
    // 退钱（补偿操作）
    paymentService.refund(event.getUserId(), event.getAmount());
    // 更新订单状态
    orderRepository.updateStatus(event.getOrderId(), FAILED);
}
```

**Saga vs 两阶段提交（2PC）：**
- 2PC = 全公司统一决定（数据库锁住），要么全成功要么全回滚。**但在高并发下，锁住资源是灾难性的。**
- Saga = 各部门各自决定，通过协调员（Order Service）统一。如果某个部门反悔，其他部门执行补偿操作。**更灵活，但可能出现短暂不一致。**

---

### 4. Spring Boot 启动慢（10–60s），HPA 扩容滞后怎么办？

**答案：**

**用"餐厅预热厨房"比喻：**

> 餐厅早上开门，要先开烤箱、预热炒锅、解冻食材。客人 9:00 到了，厨房 9:10 才准备好，前 10 分钟的客人都在等——这就是启动延迟。

**解决方案：**

**方案 1：预热（提前扩好 Pod）**
```yaml
# HPA 配置 minReplicas 最小值，不让它缩到 0
spec:
  minReplicas: 2   # 保持 2 个 Pod 常驻，冷启动只有突发流量时才发生
  maxReplicas: 20
```

**方案 2：让 Pod 更快启动（减少冷启动时间）**
```bash
# 升级到 Java 17+，使用 AppCDS（Application Class-Data Sharing）
java -XX:SharedArchiveFile=app.jsa -jar app.jar
# 第二次启动快 30–50%（不用重复 JIT 编译）
```

**方案 3：启动探针（startupProbe）——告诉 K8s 什么时候算"准备好了"**
```yaml
startupProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  failureThreshold: 30    # 最多等 30 * 10s = 5 分钟
  periodSeconds: 10
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  failureThreshold: 3
```

**方案 4：前端降级 + 慢启动提示**
> 用户看到"系统繁忙，请稍候"而不是超时错误，前端轮询确认结果。

---

### 5. Spring Boot Actuator 的 /health、/readiness、/liveness 区别？

**答案：**

**用"医院分诊台"比喻：**

| Endpoint | 比喻 | 什么时候用 |
|----------|------|---------|
| `/health`（基础）| 医生看你有没有死 | 基本检查，自己活着就行 |
| `/readiness` | 护士问"你能接诊了吗？" | **对外服务准备好了吗？**（数据库连上、缓存正常、外部服务可用）|
| `/liveness` | 医生问"你是活人吗？" | **核心逻辑能运行吗？**（JVM 没死锁、内存没泄漏）|

**在 K8s 中的行为：**

```yaml
livenessProbe:
  # K8s 问："你还活着吗？" → 如果失败，重启 Pod
  # 用于：检测 JVM 死锁、OOMKilled 后的恢复

readinessProbe:
  # K8s 问："你能接活了吗？" → 如果失败，踢出负载均衡
  # 用于：DB 还没连上？缓存还在加载？ → 先别接流量
```

**如果 `/readiness` 返回 false：**
> 护士说"医生还在准备手术，门口等一下" → ALB 把这个 Pod 从 target group 里踢掉，流量打到其他 Pod。**用户不会看到 5xx，只是响应稍慢。**

**如何保护 `/env`、`/heapdump`：**
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics  # 不暴露 env、heapdump
      base-path: /actuator
  endpoint:
    health:
      show-details: when_authorized  # 只有认证用户能看到详情
```

---

### 6. 数据库连接池（HikariCP）和 RDS Proxy 关系？

**答案：**

**连接池 = "餐厅等候区的椅子"**

> 客人来了（请求），如果餐厅里没椅子（DB 连接），客人只能站在外面等（等待连接）。连接池就是预先放好一定数量的椅子（连接），客人来了就有座。

**HikariCP（应用层连接池）vs RDS Proxy（数据库代理层连接池）：**

```
┌────────────────┐     ┌───────────────┐     ┌────────────┐
│ Spring Boot    │     │  RDS Proxy    │     │ Aurora     │
│ HikariCP Pool  │ ←→  │  连接池（中间层）│ ←→  │ PostgreSQL │
│ (每 Pod 一个)  │     │  共享连接池     │     │            │
│ 常用 10-30 个  │     │  最多 100 个   │     │            │
└────────────────┘     └───────────────┘     └────────────┘
  Pod 1: 10 连接
  Pod 2: 10 连接
  Pod 3: 10 连接
  总共 30 个           合并为 30 个        实际只开 30 个
```

**为什么两者都要？**

- **HikariCP**：每个 Pod 独立管理连接，避免一个 Pod 的慢查询拖垮其他 Pod
- **RDS Proxy**：合并所有 Pod 的连接，解决"连接风暴"（100 个 Pod 瞬间启动，每个建 10 个连接 = 1000 个连接打爆 DB）

**连接数配置公式（阿里数据库大佬的经验）：**
```
HikariCP pool_size = ((CPU cores * 2) + effective spindle count)
```
在云数据库（SSD，无 spindle_count）下：
- 4 核 CPU → pool_size ≈ 8–10
- RDS Proxy 后，这些连接会被复用，实际 DB 连接数远少于 HikariCP 设置

---

### 7. Order 服务的幂等性怎么保证？

**答案：**

**幂等 = "同一句话重复说，效果和说一次一样"**

> 你发微信说"帮我点一份外卖"，发一次和发十次的效果一样（都是点一份）。这就是幂等。

**数据库唯一约束（最可靠）：**
```sql
CREATE UNIQUE INDEX idx_order_idempotency_key ON orders(idempotency_key);
```

```java
@PostMapping("/orders")
public ResponseEntity<OrderResponse> placeOrder(
    @RequestHeader("X-Idempotency-Key") String idempotencyKey,
    @RequestBody PlaceOrderRequest request) {

    // 用幂等 key 查库
    Optional<Order> existing = orderRepository.findByIdempotencyKey(idempotencyKey);
    if (existing.isPresent()) {
        return ResponseEntity.ok(existing.get().toResponse()); // 直接返回，不重复下单
    }

    // 正常下单逻辑
    Order order = orderService.createOrder(request);
    return ResponseEntity.ok(order.toResponse());
}
```

**状态机兜底（如果幂等 key 重复）：**

```
订单状态机（只有成功下单后才能做操作）：
CREATED → CONFIRMING → CONFIRMED → SETTLED
                        ↓
                      FAILED

同一个 idempotencyKey 的请求：
- 如果状态是 CONFIRMED → 返回现有订单（幂等）
- 如果状态是 FAILED → 可以重试
- 如果状态是 CREATED → 幂等返回
```

**为什么不用 UUID.randomUUID() 做幂等 key？**
> 因为 UUID 太长（36 字符），用户网络抖动重试时会生成不同的 key。通常用**用户 ID + 订单时间戳 + 业务操作名**作为 key（如 `user123_order_20260418_001`）。

---

### 8. 定投计划的调度怎么做？

**答案：**

**用"闹钟"比喻各种调度方式：**

| 方式 | 比喻 | 优点 | 缺点 |
|------|------|------|------|
| 单机 Cron | 只有一个闹钟在响 | 简单 | 挂了就没了 |
| K8s CronJob | 闹钟 + 集群保障（多台手机备份响）| 集群保障 | 还是单点 |
| ShedLock | 多人轮流响，但只有一个人真正执行 | 分布式安全 | 额外依赖 |
| EventBridge Scheduler | AWS 托管闹钟，不用自己维护硬件 | 零运维 | 依赖 AWS |

**我们架构的推荐方案（EventBridge Scheduler + ShedLock 双保险）：**

```
EventBridge Scheduler（AWS 托管）
  → 每天早上 9:00 触发 /api/plans/execute
  → 确保至少触发了一次

ShedLock（代码层分布式锁）
  → 多实例部署时，只有一个实例真正执行
  → 执行前加锁（Redis 或 DB）
  → 执行完后释放锁
  → 其他实例看到锁被占用，跳过
```

**ShedLock 伪代码：**
```java
@Scheduled(cron = "0 0 9 * * *")
@SchedulerLock(name = "executePlans", lockAtLeastFor = "PT30S", lockAtMostFor = "PT10M")
public void executeScheduledPlans() {
    List<InvestmentPlan> plans = planService.findDuePlans(LocalDate.now());
    for (InvestmentPlan plan : plans) {
        orderService.executePlan(plan);  // 每笔定投独立幂等
    }
}
```

---

## 七、数据层（Aurora Global / Redis）

### 1. 为什么选 Aurora PostgreSQL 而不是 RDS PostgreSQL？

**答案：**

**用"连锁餐厅"比喻：**

| 特性 | RDS PostgreSQL（普通餐厅）| Aurora PostgreSQL（中央厨房式餐厅）|
|------|---------------------|--------------------------------|
| 存储 | 单机磁盘，有容量上限 | 存储计算分离，自动扩展到 128TB |
| 副本 | 1 个主 + 1 个从（读写分离有限）| 6 个副本（3 AZ 各 2 份），任何副本都可读 |
| 故障恢复 | 主从切换约 1–5 分钟 | 自动恢复约 30 秒 |
| 写性能 | 受单机硬件限制 | 分布式写入（读写层分离），峰值更高 |
| Global Database | 不支持 | 支持跨 Region 复制，DR 场景完美 |

**Aurora 的核心创新（存算分离）：**
```
传统 RDS：    应用 → 计算层（EC2） → 存储层（EBS）
              ↑                     ↑
              │                     │
Aurora：      应用 → 计算层（Writer） → 存储层（分布式 6 副本）
                   ↓
              多个 Reader → 共享同一个存储层（不用复制数据）
```

> 中央厨房式：所有分店共享一个中央仓库（存储层），厨师（计算层）读写速度极快。每个分店都有自己的快速厨房，不用等中央仓库送来。

**Aurora Global Database：** 在 us-east-1 写，us-west-2 自动同步。5 分钟内可以在 DR region 提权为主库。

---

### 2. Aurora Global Database 的同步是同步还是异步？

**答案：**

**Aurora Global 的复制是异步的。**

**但 Aurora 同 Region 内（Primary 跨 3 AZ 的副本）是同步的。**

```
Aurora Global Database 架构：
us-east-1（Primary Region）
  ↓ 异步复制（通常 <1 秒延迟）
us-west-2（Secondary Region）
  ↑ 同步（Primary → 3 AZ 副本）
  ↓ 同步
  Aurora Replica in us-west-2
```

**为什么是异步而不是同步？**
> 同步跨 Region 复制会导致：如果跨 Region 网络抖动，美国东部的写入会卡住等西部地区确认。金融交易追求低延迟，不能因为跨 region 网络问题阻塞用户请求。

**RPO 是多少？**
- 同 Region 故障（AZ 挂了）：**RPO ≈ 0**（Aurora 自动 failover，数据零丢失）
- 跨 Region 故障：典型 RPO < 1 秒（异步复制的延迟通常几百毫秒，但不为 0）

**对金融的影响：**
- 订单数据：需要 RPO = 0，不能容忍任何丢失
- 持仓数据：RPO < 1 秒 可接受（异步复制期间，最坏丢 1 秒内的持仓变更）
- 日志数据：RPO = 分钟级可接受

---

### 3. RDS Proxy 解决了什么问题？

**答案：**

**用"医院挂号台"比喻 RDS Proxy：**

> 病人（Pod）直接冲进医生办公室（DB）抢位置 → 医生办公室挤满了人，都干不了活。
> 挂号台（RDS Proxy）→ 病人先在挂号台登记，挂号台根据医生空闲情况分配座位（复用连接）。医生看完一个，挂号台再叫下一个。

**三个核心问题 RDS Proxy 解决：**

**问题 1：连接风暴（Connection Storm）**
```
没有 RDS Proxy：
100 个 Pod 各自创建 10 个连接 = 1000 个连接 → DB 崩溃
有 RDS Proxy：
RDS Proxy 最多建 100 个连接 → DB 稳定
```

**问题 2：Failover 透明化**
```
没有 RDS Proxy：DB 切换了 IP → 应用报错（Connection refused）
有 RDS Proxy：DB 切换了，Proxy 自动重连 → 应用无感知
```

**问题 3：IAM 认证（更安全）**
```
没有 RDS Proxy：密码写在 application.yml → 泄漏风险
有 RDS Proxy：用 IAM Role 认证 → 无长期密码
```

---

### 4. 缓存穿透 / 击穿 / 雪崩怎么防？

**答案：**

**三个问题用一个比喻：**

| 问题 | 比喻 | 解决方案 |
|------|------|---------|
| **缓存穿透** | 黑客拿假身份证（不存在的数据 ID）反复查，绕过缓存直接打 DB | 布隆过滤器 + 空值缓存 |
| **缓存击穿** | 万人迷商品（热点 key）突然过期，所有人同时去 DB 排队 | 互斥锁 / 永不过期 + 异步续期 |
| **缓存雪崩** | 双十一所有缓存同时过期 → DB 被踩踏打死 | 过期时间加随机抖动 + 多级缓存 |

**代码示例：**

```java
// 防缓存击穿：互斥锁
public String getFromCache(String key) {
    String value = redis.get(key);
    if (value == null) {
        // 获取锁（SETNX），只有一个线程去查 DB
        String lockKey = "lock:" + key;
        Boolean acquired = redis.set(lockKey, "1", SetArgs.Builder.nx().ex(10));
        if (Boolean.TRUE.equals(acquired)) {
            try {
                value = db.query(key);  // 只有一个人查 DB
                redis.setex(key, 300 + random.nextInt(100), value); // 永不过期
            } finally {
                redis.del(lockKey);  // 释放锁
            }
        } else {
            Thread.sleep(100);  // 等一下，再试缓存
            return redis.get(key);
        }
    }
    return value;
}
```

---

### 5. 金融数据保留 7 年怎么实现？

**答案：**

**三层策略：**

**第一层：热数据（最近 0–90 天）**
- Aurora PostgreSQL（SSD，高性能）
- 完整 CRUD 操作
- 用于：当日交易查询、实时持仓

**第二层：温数据（90 天—1 年）**
- S3 + Parquet 格式（列式存储，查询快，存储便宜）
- Aurora → S3（通过 AWS DMS 或手动导出）
- 用于：月度报表、对账查询

**第三层：冷数据（1–7 年）**
- S3 Glacier Deep Archive（成本最低，$0.00099/GB/月）
- Object Lock（WORM 模式，不可删除）
- 用于：监管审计、历史追溯

**合规不可删除的保障：**
```bash
# 设置 Object Lock，7 年内任何人（包括 Root）都删不了
aws s3api put-object-lock-configuration \
  --bucket financial-records-archive \
  --object-lock-configuration '{"ObjectLockEnabled":"Enabled","Rule":{"DefaultRetention":{"Mode":"COMPLIANCE","Years":7}}}'
```

**为什么不用账本数据库（QLDB）？**
- QLDB 是"只可追加、不可篡改"的账本，适合交易流水
- 但 QLDB 成本高，适合高频交易场景
- 如果只需要"保留 7 年可查"，S3 Object Lock 更经济

---

## 八、高可用与容灾

### 1. "两地三中心"在中国监管下是什么要求？你在 AWS 上如何实现？

**答案：**

**监管定义（金融行业）：**

> "两地三中心" = 同城两个数据中心 + 异地一个数据中心。
> - 目的：同城抗地震/洪水（物理距离 30–50km），异地抗战争/大范围灾难。

**在 AWS 上的映射：**

| 传统两地三中心 | AWS 映射 | 实现方式 |
|--------------|---------|---------|
| 同城 DC1 | us-east-1a | EKS 节点 + Aurora Replica |
| 同城 DC2 | us-east-1b + 1c | EKS 节点 + Aurora Replica |
| 异地 DC | us-west-2 | Aurora Global Secondary + DR EKS |

**数据同步策略：**

```
us-east-1（主数据中心）
    ↓ 同步复制（0 RPO）
    3 AZ Aurora 副本
    ↓ 异步复制（< 1s RPO）
us-west-2（异地灾备）
    ↓
S3 + Cross-Region Replication（CRR）
    ↓ 日志、备份文件
Glacier Deep Archive
```

**RTO / RPO 承诺：**

| 故障场景 | RTO（恢复时间）| RPO（数据丢失）|
|---------|-------------|--------------|
| 单个 Pod 挂了 | < 30 秒 | 0（请求未完成重试即可）|
| 单个 AZ 挂了 | < 5 分钟 | 0（Aurora 自动 failover）|
| 单个 Region 挂了 | < 15 分钟 | < 1 秒（Aurora Global）|

---

### 2. Circuit Breaker 在故障传播中起什么作用？

**答案：**

**用"保险丝"比喻 Circuit Breaker：**

> 家里电表短路了，如果电流无限涌入，整条街都停电。保险丝先烧断，切断电流，保护整个电网。

**Circuit Breaker 的三个状态：**

```
CLOSED（正常）→ 熔断器合上，电流正常流
    ↓ 失败次数超过阈值
OPEN（熔断）→ 停止调用，直接返回降级响应
    ↓ 等待一段时间
HALF_OPEN（半开）→ 放一个请求试试对方好了没
    ↓
  成功了 → CLOSED（恢复正常）
  失败了 → OPEN（继续熔断）
```

**配置阈值（以 Resilience4j 为例）：**

```java
@CircuitBreaker(name = "fundService", fallbackMethod = "getFundFallback")
public Fund getFund(String fundCode) {
    return fundServiceClient.getFund(fundCode);
}

public Fund getFundFallback(String fundCode, Exception ex) {
    // 返回缓存的基金信息（如果缓存也没有，返回"暂无数据"）
    Fund cached = fundCache.get(fundCode);
    return cached != null ? cached : Fund.UNAVAILABLE;
}
```

**为什么对金融系统重要？**
> 如果 fund-service 挂了（基金净值查不到），order-service 不断重试 → fund-service 压力更大 → fund-service 更慢 → order-service 等待超时 → 用户看到大量超时错误。这就是**故障雪崩**。Circuit Breaker 在第 3 个失败时直接熔断，返回降级结果，保护整个系统。

---

## 九、安全与合规

### 1. 金融行业有哪些主要合规框架？

**答案：**

**用"不同国家的交通规则"比喻合规框架：**

| 框架 | 类比 | 适用范围 |
|------|------|---------|
| **等保 2.0**（中国）| 中国交通规则（靠右行、红灯停）| 在中国大陆运营 |
| **PCI-DSS** | 信用卡刷卡安全规则 | 涉及信用卡支付 |
| **SOC 2** | 第三方安全审计报告 | 面向美国客户的 SaaS 服务 |
| **ISO 27001** | 国际通行信息安全标准 | 国际化客户常要求 |
| **GDPR**（欧盟）| 欧盟数据隐私法 | 处理欧盟公民数据 |
| **香港 SFC** | 香港证监会规则 | 香港持牌资管 |
| **AML/KYC** | 反洗钱 + 实名认证 | 所有金融交易 |

**我们的系统涉及的合规要求：**
- KYC：用户注册必须实名（身份证 + 活体认证）
- AML：大额交易监控、短进短出检测
- 数据保留：交易记录保留 7 年（不可删除）
- 网络安全：WAF + DDoS 防护 + 渗透测试

---

### 2. KMS 的 Customer Managed Key vs AWS Managed Key 区别？

**答案：**

**用"保险柜钥匙"比喻：**

| 类型 | 比喻 | 管理权 | 轮换 | 适用场景 |
|------|------|--------|------|---------|
| AWS Managed Key | 保险公司配的锁（不能换锁芯）| AWS 全权管理 | AWS 自动轮换 | 不需要你操心的通用加密 |
| Customer Managed Key (CMK) | 你自己买的保险柜（可以换锁芯）| 你全权管理 | 手动或自动（可选）| 需要你控制的敏感加密 |

**我们架构里用在哪：**

| 场景 | 用哪种 Key | 为什么 |
|------|-----------|-------|
| Aurora 存储加密 | CMK（自定义）| 你需要控制密钥删除策略（意外删除会导致 DB 不可用）|
| S3 备份加密 | CMK | 需要设置 7 年保留，AWS Managed Key 不能设这个 |
| EBS 磁盘加密 | AWS Managed Key | 不需要额外管理，系统盘自动加密 |
| Secrets Manager | CMK | 存的是客户密码，必须自己控制 |

**CMK 的密钥轮换：**
```bash
# 启用自动轮换（每年一次）
aws kms enable-key-rotation --key-id alias/smart-invest-cmk
# 旧数据用旧密钥加密，新数据用新密钥加密
# 读取时自动解密，应用无感知
```

---

### 3. 零信任在架构里体现在哪里？

**答案：**

**零信任 = "不相信任何人，进门就查证件"**

> 传统安全 = 城墙 + 护城河（边界防御）。进去之后大家都信任。
> 零信任 = 进门查证件、每层楼都要门禁、即使你是员工也要每次验证。

**架构里的零信任体现：**

| 零信任原则 | 实现方式 |
|-----------|---------|
| **永不信任，始终验证** | IRSA：每次 Pod 启动都要重新认证 IAM 角色（不用长期 AccessKey）|
| **最小权限** | IAM Policy 精确到 `s3:GetObject`（不能 List/Delete），而不是 `s3:*` |
| **微分段** | K8s NetworkPolicy：order-service 不能直接访问 user-service（默认 deny）|
| **服务身份** | 每个 Spring Boot 服务有独立的 ServiceAccount，有独立的 IAM Role |
| **持续验证** | WAF：每个请求都要验证（不是登录一次就永久信任）|
| **数据加密** | TLS 1.2+ 端到端加密（即使内网流量也要加密）|

---

## 十、CI/CD 与 GitOps

### 1. CI/CD 完整链路

**答案：**

**用"餐厅出餐流程"比喻：**

```
食材采购（代码提交）
    ↓
厨房初加工（单元测试）
    ↓
高级厨师精加工（集成测试、代码扫描）
    ↓
摆盘 + 拍照存档（构建 Docker 镜像 + SBOM + 签名）
    ↓
送检（上传镜像到 ECR + cosign 签名验证）
    ↓
菜单更新（ArgoCD 检测到 Git 变更）
    ↓
服务员上菜（金丝雀发布 10%）
    ↓
客人尝菜（自动分析 P99 错误率）
    ↓
客人满意（全量 100% 推送）
```

**具体链路（GitHub Actions）：**

```yaml
# .github/workflows/deploy.yml
jobs:
  build:
    - Checkout 代码
    - 运行单元测试（mvn test）
    - SonarQube 代码扫描（覆盖率 > 80%）
    - 构建 Docker 镜像（BuildKit 多阶段构建）
    - 生成 SBOM（软件物料清单）
    - cosign 签名镜像（用 KMS 私钥）
    - 推送镜像到 ECR

  security-scan:
    - Trivy 扫描镜像漏洞
    - IAM Access Analyzer 检查 IAM 政策

  deploy-staging:
    - ArgoCD 自动检测 Git 变更
    - 部署到 Staging 环境
    - 运行集成测试

  deploy-prod:
    - Argo Rollouts 金丝雀发布
    - 10% 流量 → 观察 10 分钟 → Prometheus 分析
    - 无异常 → 50% → 100%
    - 有异常 → 自动回滚（Analysis 失败）
```

---

### 2. ArgoCD 的 GitOps 模式 vs Jenkins 推送模式

**答案：**

**用"外卖订单"比喻：**

| 模式 | 做法 | 类比 |
|------|------|------|
| Jenkins 推送 | 厨师做好菜，主动送到你家 | 你不知道什么时候送，可能凉了 |
| ArgoCD GitOps | 你定时刷新外卖 App，App 自动告诉你状态 | 你掌控主动权，状态随时可见 |

**GitOps 的优势：**

1. **幂等性**：`kubectl apply -f manifest.yaml` 无论执行多少次，结果都一样。Git 里的配置是"声明式的"，ArgoCD 确保"实际状态"和"期望状态"一致。
2. **回滚简单**：`git revert` 一个 commit → ArgoCD 自动同步回滚。一个命令搞定，不用手动记得怎么改回去。
3. **审计完整**：谁在什么时间改了什么配置，Git 历史全记录。没有"在服务器上手动改了个参数"导致的差异。
4. **漂移检测**：如果有人在生产环境手动改了配置（Config Drift），ArgoCD 能检测到并告警。

---

### 3. 为什么选 GitHub Actions 而不是 Jenkins？

**答案：**

| 维度 | GitHub Actions | Jenkins |
|------|---------------|---------|
| 托管 | GitHub 云（零维护）| 自建服务器（需要专人维护）|
| 配置 | YAML 文件（代码化）| Groovy 脚本（代码化但 Jenkins 特有）|
| 生态 | GitHub Marketplace（Actions 市场）| Plugin 生态（质量参差不齐）|
| 容器支持 | 原生多容器 + Docker | 需要配置 Docker 插件 |
| 成本 | 开源仓库免费 | 服务器电费 + 维护成本 |
| 与 Git 集成 | 原生集成（commit → trigger）| 需要配置 Webhook |

**为什么 Jenkins 也有优势：**
- 高度可定制（复杂流水线更灵活）
- 不依赖 GitHub（支持 GitLab、BitBucket）
- 团队已熟悉

**我们的选择（根据架构图）：**
> GitHub Actions（CI 构建）→ ECR（镜像存储）→ ArgoCD（GitOps 部署）。分离的好处：CI 只管"能不能构建"，CD 只管"怎么部署"，职责单一。

---

## 十一、可观测性与告警

### 1. 可观测性三支柱是什么？架构里分别是什么组件？

**答案：**

**用"病人体检"比喻：**

| 支柱 | 体检项目 | 架构组件 | 回答什么问题 |
|------|---------|---------|------------|
| **Metrics（指标）** | 验血、量血压 | Prometheus + AMP | "系统现在健康吗？CPU 80%、内存 70%、QPS 1万" |
| **Logs（日志）** | 病历本 | Fluent Bit → CloudWatch Logs / Loki | "刚才发生了什么？Error、Exception 的详细信息" |
| **Traces（追踪）** | 心电图 | X-Ray / OpenTelemetry | "这个请求慢，慢在哪一步？是 order-service 还是 DB？" |

**三者的关系：**

```
Metrics → 告诉你"有问题吗？"（数字高了/低了）
    ↓ 点击告警
Logs → 告诉你"哪里有问题？"（具体错误信息）
    ↓ 点击 trace ID
Traces → 告诉你"为什么慢？"（哪个函数/哪个调用耗时）
```

**为什么三个都要？**
> 去医院看病，医生不会只看你有没有发烧（Metrics），也不会只看你以前看过什么病（Logs），而是综合问诊 + 检查 + 病史。三者缺一，排查问题就像蒙眼修车。

---

### 2. 核心业务 SLI / SLO 怎么定义？

**答案：**

**SLI = 体检指标（实际测量值），SLO = 医生设定的健康标准。**

**Smart-Invest 的核心 SLI/SLO：**

| 业务场景 | SLI（指标）| SLO（目标）| Error Budget（容错空间）|
|---------|-----------|-----------|---------------------|
| 下单接口可用性 | 200 OK 比例 | 99.9%（每月 < 44 分钟不可用）| 每月 43.8 分钟 |
| 下单 P99 延迟 | < 500ms | < 500ms | 每月 0.1% 的请求可以超标 |
| 基金净值查询 | 200 OK 比例 | 99.95% | 每月 < 22 分钟不可用 |
| 用户登录成功率 | > 99.5% | > 99.5% | 每月 < 3.6 小时失败 |

**Error Budget（错误预算）的使用：**

> 医生说每月允许你体重浮动 1 公斤（Error Budget）。如果本月只浮动 0.3 公斤（系统稳定）→ 可以继续发布新功能。如果本月已经浮动 1.2 公斤（故障频发）→ **冻结发布，先修好系统**。

这就是 **Error Budget 策略**：系统稳定时加快迭代，出问题时减少变更以降低风险。

---

### 3. 告警分级 P1/P2/P3 怎么设计？

**答案：**

| 级别 | 名称 | 场景 | 通道 | SLA 响应 |
|------|------|------|------|---------|
| **P1** | 最高级 | 全站宕机、下单全量失败 | PagerDuty（打电话）→ 立即处理 | < 5 分钟 |
| **P2** | 高级 | 某个服务挂了、延迟升高 | Slack #alerts-high | < 15 分钟 |
| **P3** | 中级 | 指标异常、容量 80% | Slack #alerts + Email | < 2 小时 |

**告警风暴抑制（去重）：**
> 一次故障可能触发 50 条告警（每个 Pod 一条）。就像你家着火，烟雾报警器响了 50 个——你不需要看 50 次。
```yaml
# Alertmanager 配置（去重/分组/静默）
route:
  group_by: ['alertname', 'service']
  group_wait: 30s      # 等 30 秒，把同类告警合并成一条
  group_interval: 5m  # 5 分钟内同类告警不重复发
  repeat_interval: 4h # 同一条告警 4 小时才重复
```

---

## 十二、成本优化（FinOps）

### 1. 架构月成本大致分布

**答案：**

**粗略估算（月费用，以 us-east-1 100 DAU 初级版本）：**

| 成本项 | 估算 | 说明 |
|--------|------|------|
| **EKS + EC2** | $800–1500 | 3 节点 * m5.large，Spot 可省 60% |
| **Aurora PostgreSQL** | $500–1200 | 最贵的单项，Aurora Serverless 更划算 |
| **NAT Gateway** | $300–600 | 流量费最容易被低估！ |
| **数据传输出站** | $200–500 | CloudFront + S3 出站，尤其容易被忽视 |
| **CloudFront** | $100–200 | 按流量计费 |
| **Managed Prometheus/Grafana** | $200–400 | 按 metrics 数量计费 |
| **VPC Endpoints (Interface)** | $100–200 | 接口类型按小时 + 流量 |
| **其他（IAM、KMS、Secrets Manager）**| $50–100 | 各项少量 |
| **总计** | **$2250–4700/月** | 约 **1.5–3 万人民币/月** |

**Plan D 降本手段：**

| 手段 | 节省 | 操作 |
|------|------|------|
| Spot 实例（app-spot-ng）| 60% 计算费 | 批处理任务跑 Spot |
| Graviton ARM | 10–20% | 用 m6g 替代 m5 实例 |
| Dev 环境夜间关停 | 50% Dev 成本 | kube-green + EventBridge |
| Aurora Serverless | 根据负载计费 | 适合 DAU 波动大的场景 |
| 减少 Interface VPC Endpoint | 减少费用 | 只保留必须的 |
| CloudWatch Logs 精简 | $50–100/月 | 只保留 ERROR 及以上日志 |

---

### 2. Spot 节省了多少？怎么让团队接受？

**答案：**

**Spot 的折扣有多大？**

| 实例类型 | On-Demand（按需）| Spot（竞价）| 节省 |
|---------|----------------|------------|------|
| m5.large（4核 8G）| $0.096/小时 | ~$0.03/小时 | **68%** |
| r5.xlarge（32G 内存）| $0.252/小时 | ~$0.07/小时 | **72%** |

**典型节省场景：**
> 白天 8 台 On-Demand = $0.096 * 8 * 24h * 30 = **$553/月**
> 白天 8 台 Spot（批处理）= $0.03 * 8 * 24h * 30 = **$173/月**（夜间关停更便宜）

**"不敢用 Spot"的常见顾虑和回答：**

| 顾虑 | 回答 |
|------|------|
| "Spot 会随时终止，我的服务不就挂了？" | 有 2 分钟预警 + PDB + preStop hook + Karpenter 自动补位。**生产上的关键服务跑 On-Demand，批处理跑 Spot**，不用全上 Spot。 |
| "补货不及时，新 Pod 启动慢" | Karpenter 比 Cluster Autoscaler 快得多。配合 Spot 实例预置池，响应时间通常 < 2 分钟。 |
| "管理太复杂" | 只需要在 Node Group 配置里写 `capacityType: SPOT`，K8s 帮你处理分配。 |

---

## 十三、金融业务场景（领域题，差异化加分）

### 1. 基金净值 T+1，架构怎么支撑"预估金额 vs 最终金额"？

**答案：**

**用"订酒店"比喻：**

> 你在携程订酒店，显示"今日房价 $100"。但实际结账时可能变成 $110（加了服务费）或 $90（折扣）。你先付了 $100 的押金，最后多退少补。这就是"预估金额 vs 最终金额"。

**技术实现：**

```
用户下单（买入 1000 元基金）
    ↓
前端展示：预估净值 3.4567 元/份 → 预估份额 289 份
    （基于上一个交易日净值 + 预估今日涨跌）
    ↓
后端记录：
  - 订单金额：1000 元
  - 订单状态：PENDING（待确认）
  - 预估份额：289 份
    ↓
日终（基金公司返回当日净值）
    ↓
后端重新计算：
  - 实际净值：3.4678 元/份
  - 实际份额：288.26 份
  - 实际扣款：1000 元（金额不变，但份额精确了）
  ↓
订单状态：CONFIRMED
用户收到通知："您的 289 份 XX 基金已确认"
```

**难点：** 如果实际净值导致零碎份额（如 288.2637 份），按基金公司规则四舍五入或截断。

---

### 2. QDII 跨时区，cut-off 时间怎么处理？

**答案：**

**用"国际航班"比喻：**

> 买QDII基金就像买国际机票：
> - 香港到纽约的航班在香港时间 10:00 起飞（对应纽约时间 22:00）
> - 你在香港时间 09:50 到机场——晚了，航班不等人
> - 每个基金公司有不同的"登机口截止时间"（cut-off time）

**技术实现：**

```java
// 每个基金有自己的 cut-off 时间（基金公司提供）
Fund {
    String fundCode;
    ZoneId cutoffTimezone;        // 基金公司所在时区（如 America/New_York）
    LocalTime cutoffTime;          // 截点时间（如 16:00）
}

// 判断订单是否在截点内
public boolean isWithinCutoff(Fund fund, Instant orderTime) {
    // 把订单时间转换到基金公司的时区
    ZonedDateTime fundLocalTime = orderTime.atZone(fund.getCutoffTimezone());
    LocalTime orderLocalTime = fundLocalTime.toLocalTime();

    // 比较
    return !orderLocalTime.isAfter(fund.getCutoffTime());
}

// 逻辑：
// 16:01 NY 时间截点 -> 订单在 NY 16:01 -> 超时 -> 按下一个工作日处理
// 09:00 HK 时间下单（对应 NY 前一天 21:00）-> 在截点内 -> 当日处理
```

**一个用户买了 3 只 QDII 基金（香港、美国、欧洲各一只）怎么办？**
> 三个基金有不同的截点。Order Service 需要分别对每个基金判断截点，任何一个超时就单独处理该笔订单（不阻塞其他基金的下单）。

---

### 3. 账户余额严格正确，零差错，怎么保证？

**答案：**

**用"银行账本"比喻：**

> 银行系统对余额的处理不是简单的"数字加减"。如果余额计算错误一分钱的利息，长年累月可能是天文数字。所以银行用"双账本"甚至"多账本"机制。

**我们的设计：**

**原则 1：账户余额 + 流水双写（Ledger 模式）**

```
账户表（实时余额）：
  user_id: 123, balance: 10000.00

流水表（每笔明细）：
  user_id: 123, amount: +500.00, balance_after: 10500.00, created_at: ...
  user_id: 123, amount: -200.00, balance_after: 10300.00, created_at: ...

每次操作：balance = balance + amount → 同时插入一条流水
查余额：直接从 balance 字段读（快）
对账：把所有流水加起来 = balance（一致性检查）
```

**原则 2：余额不为负（数据库约束）**

```sql
ALTER TABLE accounts ADD CONSTRAINT chk_balance_non_negative
  CHECK (balance >= 0);

-- 同时在应用层做检查（双保险）
@Transactional
public void debit(Long userId, BigDecimal amount) {
    Account account = accountRepository.findById(userId);
    if (account.getBalance().compareTo(amount) < 0) {
        throw new InsufficientBalanceException("余额不足");
    }
    account.setBalance(account.getBalance().subtract(amount));
    accountRepository.save(account);
    // 同时写流水表（ Saga 中的 Action）
}
```

**原则 3：日终对账（每日一次）**

```
所有流水加总 = 账户余额？ → 如果不等，告警 + 自动停机
系统内部余额 = 银行接口返回余额？ → 如果不等，告警 + 人工处理
```

---

## 十四、故障场景与排障

### 1. 用户反馈"下单后没扣钱但显示持仓增加了"，怎么排查？

**答案：**

**排查思路（从外到内）：**

```
第一步：查 order-service 的日志
  → 找到订单 ID，看下单的完整流程走到了哪一步
  → "ORDER_PLACED" 还是 "PAYMENT_PENDING" 还是 "PAYMENT_FAILED"？

第二步：查 payment-service 的日志
  → 支付请求发出了吗？
  → 支付请求有返回吗？（超时？拒绝？）

第三步：查 portfolio-service 的日志
  → 持仓更新是怎么触发的？（消息队列还是同步调用？）
  → 持仓更新基于什么数据？（如果基于 order_id 而非 payment_confirmed，就有问题）

第四步：最可能的根因
  → Portfolio-service 在 Order-service 还没确认支付时就更新了持仓
  → 或者：支付失败的消息没发出去，Portfolio-service 用的是旧缓存
```

**修复方向：**
> 持仓更新必须基于 **PAYMENT_CONFIRMED 事件**，而不是 ORDER_PLACED 事件。需要在 Saga 的补偿事务里加上：如果支付失败，立即撤销持仓（减少份额）。

---

### 2. Grafana 告警：P99 从 200ms 涨到 3s，从哪里开始查？

**答案：**

**四步排查法：**

```
Step 1: 看是所有接口慢还是某个接口慢
  → 如果所有接口慢 → DB 或中间件的问题
  → 如果只有 /api/orders 慢 → Order 服务的特定逻辑问题

Step 2: 打开 Trace（X-Ray）
  → 3 秒慢在哪里？
  → 是 order-service 自己的逻辑慢（DB 查询慢）？
  → 还是下游服务（fund-service、user-service）响应慢？
  → 还是网络延迟（NAT Gateway、跨 AZ 调用）？

Step 3: 如果是 DB 问题（最常见）
  → 查 Aurora Performance Insights：
    - 哪个 SQL 最慢？（通常是某个查询缺索引）
    - 有没有锁等待？（autovacuum 没跑完？）
    - 连接数是不是满了？

Step 4: 如果是外部依赖问题
  → fund-service 慢？→ 看它自己的 DB 和 GC
  → Redis 慢？→ 看内存使用率、命中率
  → 是不是 NAT Gateway 带宽满了？（某个 Pod 在大量拉镜像？）
```

**常见"突然变慢"的根因：**

| 根因 | 症状 | 快速定位 |
|------|------|---------|
| 缺索引的查询走了全表扫描 | 白天正常，夜间批处理后变慢 | `EXPLAIN ANALYZE` 看执行计划 |
| autovacuum 锁定表 | 写入变慢，读取正常 | Aurora 日志里搜 "autovacuum" |
| 连接池耗尽 | 大量 "Connection timeout" | HikariCP metrics |
| GC（垃圾回收）停顿 | 周期性的延迟尖峰（如每分钟）| JVM GC logs |
| 外部 API 超时 | 偶发性，不稳定 | Trace 里看下游调用的成功率 |

---

## 十五、架构权衡与行为面试

### 1. 你这套架构最大的技术债是什么？

**答案：** （诚实回答，以下是真实常见的债）

**最常见的技术债：**

1. **数据库 schema 设计保守**（过早优化导致过度设计）
   > Order 表如果从一开始就按"分库分表"设计就好了，但当时不知道量级。现在迁移代价很大。

2. **缺乏契约测试（Contract Test）**
   > fund-service 改了返回值格式，order-service 没测到，上线后才发现不兼容。契约测试（Pact）可以早发现。

3. **日志规范不统一**
   > 早期服务用 Log4j，新服务用 Logback，格式不一致。统一用结构化日志（JSON）花了很多人天。

4. **测试覆盖率不够**
   > 集成测试覆盖率低，频繁出现"本地测了没问题，线上出问题"的情况。

**回答技巧：** 承认债 + 说明为什么 + 展示你在还债（如"我在第 X 个月引入了 Pact 契约测试，X% 的接口冲突可以在 CI 阶段发现"）。

---

### 2. Well-Architected Framework 六大支柱是什么？

**答案：**

**AWS Well-Architected Framework = 建筑领域的"建筑规范"，告诉你怎么建"好建筑"。**

| 支柱 | 核心问题 | 我们架构的体现 |
|------|---------|--------------|
| **卓越运营（Operational Excellence）** | 怎么让系统正常运行？ | ArgoCD GitOps、监控告警、日志 |
| **安全（Security）** | 怎么保护系统不被攻击？ | WAF、IAM、IRSA、KMS、NetworkPolicy |
| **可靠性（Reliability）** | 系统挂了能自动恢复吗？ | Aurora Multi-AZ、Spot + PDB、Karpenter |
| **性能效率（Performance Efficiency）** | 怎么让系统跑得又快又省？ | Spot、Graviton、Redis 缓存、ALB ip mode |
| **成本优化（Cost Optimization）** | 怎么不花冤枉钱？ | Savings Plans、Spot、Dev 环境关停 |
| **可持续性（Sustainability）** | 怎么减少碳足迹？ | Spot 实例（减少闲置资源）、Right-sizing |

**面试回答技巧：** 被问到"你的架构怎么体现某个支柱"时，先说这个支柱的定义，再举一个架构里的具体例子。

---

## 附：深水炸弹题详解

### 1. Aurora 的 buffer pool 故障切换后为什么 reader 会有短暂慢？

**答案：**

**Aurora 的 buffer pool（共享存储层）vs RDS 的 buffer pool（per-instance）：**

```
Aurora：
  Writer → 把数据写入共享存储（6 副本，3 AZ）
  Reader → 从共享存储读（不需要 WAL 应用，慢查询直接读存储层，快）
  Failover 时：新的 Writer 需要"重新挂载"共享存储，Reader 也需要重连

RDS：
  Writer 有自己的 buffer pool
  Reader（Replica）有自己的 buffer pool
  Failover 时：Replica 的 buffer pool 完全是空的（冷缓存），前 10 分钟的查询都会打 DB
```

**Aurora Failover 后 Reader 短暂慢的原因：**

1. 新 Writer 要做一次 checkpoint（把脏页刷到共享存储）
2. 所有 Reader 要重新建立连接（connection pool 要重建）
3. 共享存储层的 I/O 在 failover 期间短暂降级

**类比：** 就像银行换了一个柜台经理（Writer failover）。所有取号机（Reader）要重新初始化，顾客（请求）要重新排队。但因为大家共用同一个金库（共享存储），切换比"各用各的金库"快得多。

---

### 2. Java 容器里 `Runtime.availableProcessors()` 返回什么？

**答案：**

**这是一个经典坑！**

```bash
# 在容器里（K8s Pod，CPU limit = 2 核）
$ java -jar app.jar
Runtime.availableProcessors() = 2   # ✅ 正确

# 但如果 CPU limit = 0.5 核（小于 1）
Runtime.availableProcessors() = 1    # ✅ 返回 1

# 如果 limit 和 request 不一样（JVM 默认看 limit）：
# container-cpuset-cpus = "0"（只有 CPU 0）
# 但系统有 8 个物理核
# availableProcessors() = 1（只绑定了一个核）
```

**`-XX:ActiveProcessorCount` 什么时候用？**

> 如果你的应用部署在物理机的容器里，JVM 会看到物理机的核数（比如 64 核），但容器实际只能用 2 核。如果按 64 核去算线程池大小，会创建过多线程，上下文切换开销巨大。

```bash
# 强制告诉 JVM "你就按 2 核来"
java -XX:ActiveProcessorCount=2 -jar app.jar

# 或者用 CPU quota（推荐）
# 在 K8s 里直接用 resources.limits.cpu: "2"
# JVM 9+ 会自动读取 cgroup 的 CPU quota
```

**在 K8s 里，最佳实践是什么？**

> **把 CPU request = CPU limit**（Guaranteed QoS）。这样 JVM 能正确感知 CPU 核数，不会因为 limit < request 而产生不一致。

```yaml
resources:
  requests:
    cpu: "2"
    memory: "2Gi"
  limits:
    cpu: "2"    # request = limit → Guaranteed QoS
    memory: "2Gi"
```

---

## 使用建议

1. **别死记硬背**：面试官大概率会顺着你的答案追问 3 层。每题答到能展开"为什么 / 代价 / 替代方案"，比背答案更重要。
2. **选 3–5 个最熟的亮点**（比如 IRSA 链路、Aurora Global 切换、Canary 分析），准备到能画图、讲故事、报数字的深度。
3. **数字化**：QPS、延迟、成本、RTO/RPO、实例规格都准备具体数字，不要"比较多 / 比较快"。
4. **反向提问**：面试尾声问"贵司如何做 DR 演练 / 多 region / 合规"，把不会的领域转成双向技术交流。
5. **承认不会**：遇到不懂的，诚实说"这块没做过，但基于 XX 原则我会这样起步"远比硬编好。
