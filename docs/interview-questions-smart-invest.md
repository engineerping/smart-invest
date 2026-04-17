# Smart-Invest 架构 & 金融项目 面试题库

> 基于 [smart-invest-aws-plan-d-architecture.drawio](smart-invest-aws-plan-d-architecture.drawio) 与 [2026-04-08-aws-deployment-plan-d.md](superpowers/specs/2026-04-08-aws-deployment-plan-d.md)，针对 HSBC FlexInvest 类公募基金投资平台的面试准备。
> 覆盖 Solutions Architect Professional、Senior Backend、SRE/Platform、金融行业领域等视角。

---

## 一、项目概览与业务理解（破冰题，必问）

1. 请用 3–5 分钟介绍 smart-invest 这个项目：它解决什么业务问题？核心用户是谁？你在其中承担了什么角色？
2. FlexInvest 类的公募基金投资平台，与证券交易系统（如股票）相比，在技术上有什么本质差异？（答题方向：T+1 净值结算、份额/金额双模式、QDII 跨时区、定投、FoF）
3. 为什么选择微服务架构？拆分成 user / fund / order / portfolio / plan 这 5 个服务的依据是什么？（是按业务边界 DDD 拆还是按技术拆？）
4. 如果让你重新拆分，你会如何划分？Bounded Context 的边界在哪里？
5. 项目中最具挑战的技术点是什么？你是如何解决的？
6. 项目上线后，日活用户、QPS、数据量量级预期是多少？你的架构为这个量级做了哪些针对性设计？
7. 从原型到 production version（plan D），你做了哪些关键升级？为什么不一次到位？

---

## 二、架构设计与权衡（Solutions Architect Professional 核心）

1. 请对照架构图讲讲整个系统的请求链路：一个用户点击"买入基金"按钮，从 DNS 到数据库落盘的完整流程。
2. 你的架构有哪几层？每一层解决什么问题？为什么这样分层？
3. 如果让你砍掉一半组件来降本 50%，你会砍哪些？为什么？（考察真实理解 vs 堆砌）
4. 这个架构过度设计（over-engineering）了吗？对一个初创期产品，哪些部分是"先不要上"的？
5. CAP 三选二，你这套架构偏向哪个方向？在哪些地方做了 CP 选择？哪些地方做了 AP 选择？
6. 你的设计里哪些是"必须这么做的"（硬约束），哪些是"我选择这么做的"（设计偏好）？
7. 如果明天监管要求所有数据不得出境且必须私有化部署，你的架构需要做哪些改动？
8. 用户规模从 10w 增长到 1000w，你的架构哪里会先瓶颈？
9. 为什么不用 Serverless（Lambda + DynamoDB + API Gateway）？在什么场景下你会改用 Serverless？
10. 为什么不选 ECS Fargate 而选 EKS？EKS on EC2 vs EKS Fargate 的选择依据？

---

## 三、AWS 服务与多账号治理

1. 你设计了 5 个 AWS 账户（Management / Security / Log Archive / Production / Staging），为什么要这样拆？一个账户不行吗？
2. AWS Organizations + SCP 能防住什么？防不住什么？（答题方向：SCP 是权限"天花板"，不授权；IAM 才授权）
3. 你列了 4 个 SCP（DenyLeavingOrg / RequireMFA / DenyRegionsNotApproved / DenyS3Public），实际业务上遇到过什么坑？例如 DenyRegionsNotApproved 会误伤哪些全局服务？
4. Log Archive 账户里的日志如何防止被 Root 管理员删除？（答题方向：S3 Object Lock WORM + Vault Lock + 跨账户权限）
5. Control Tower、Organizations、Landing Zone 的关系是什么？你用了哪一个？
6. 管理员日常如何安全地跨账户操作？（IAM Identity Center / AWS SSO / AssumeRole + MFA）
7. 如何做账户级别的成本拆分和预算告警？（Cost Allocation Tags / AWS Budgets / Cost Anomaly Detection）
8. Service Quota 和 Service Limit 如何监控？你的架构里哪些 Quota 是高危的？（如 EKS 每集群 Node 上限、ENI 上限、NAT Gateway 并发连接）

---

## 四、网络架构（VPC / 子网 / Security Group / VPC Endpoint）

1. VPC CIDR 你是怎么规划的？为什么是 10.0.0.0/16？多 region 互联怎么避免冲突？
2. 三层子网（Public / Private App / Private Data）的设计原因？如果把数据库放在 Private App 子网会有什么问题？
3. NAT Gateway 为什么每个 AZ 一个，不是共用一个？成本 vs 可用性怎么权衡？
4. NAT Gateway 的带宽上限是多少？如果 EKS Pod 并发拉镜像打满 NAT 怎么办？（答题方向：VPC Endpoint for ECR、镜像缓存）
5. 你列了十几个 VPC Endpoint，为什么要上这么多？不上有什么风险？（答题方向：避免流量出 VPC 走 NAT，降本 + 降延迟 + 数据不出 AWS 网络）
6. Gateway Endpoint（S3/DynamoDB）和 Interface Endpoint 的区别？计费方式？
7. Security Group vs NACL，你什么时候用哪个？为什么架构里没有画 NACL？
8. 你的 Security Group 是怎么组织的（alb-sg / eks-node-sg / aurora-sg / redis-sg / vpce-sg）？这种"SG 引用 SG"比"IP CIDR"好在哪？
9. Kubernetes Network Policy（Calico）和 AWS Security Group 有什么区别？为什么两者都要？
10. 跨 region 的私网互联你用什么？（VPC Peering / Transit Gateway / PrivateLink / Cloud WAN）他们的区别？
11. ALB、NLB、CLB、API Gateway 你会怎么选？你架构里为什么选 ALB？
12. AWS Load Balancer Controller 的 target-type 为什么选 ip 不选 instance？（答题方向：跳过 kube-proxy，直连 Pod，延迟更低，支持 Fargate）
13. CloudFront + ALB 的链路里，如何确保 ALB 只接受 CloudFront 来的流量？（答题方向：AWS-managed prefix list for CloudFront + Custom Header 校验）
14. DDoS 防护：WAF、Shield Standard、Shield Advanced 的区别？什么时候需要上 Shield Advanced？
15. DNSSEC 的作用是什么？没开会有什么风险？

---

## 五、EKS 与 Kubernetes 深度

1. EKS Control Plane 是 AWS 托管的，你还关心它什么？（答题方向：私有 API endpoint、etcd KMS 加密、OIDC Provider、审计日志开启）
2. EKS 版本升级策略是什么？你怎么保证升级零停机？（答题方向：Surge upgrade、PDB、Blue-Green 节点组、升级前先升 CRD）
3. Node Group 分了 system / app-ondemand / app-spot / gpu，怎么确保关键 Pod 不被调度到 Spot？（答题方向：nodeSelector / taints+tolerations / PriorityClass）
4. Karpenter vs Cluster Autoscaler，你为什么选 Karpenter？各自的弱点？
5. Spot 中断（2min 警告）你如何优雅处理？（答题方向：AWS Node Termination Handler、PDB、preStop hook、连接排空）
6. HPA 的指标从哪里来？基于 CPU 够用吗？你用自定义指标吗？（答题方向：KEDA、queue depth、RPS）
7. VPA 和 HPA 能一起用吗？会有什么冲突？
8. Pod Security Admission 用的是哪个 profile？baseline / restricted 各自什么限制？
9. 为什么要 `runAsNonRoot + readOnlyRootFilesystem + drop ALL capabilities`？Spring Boot 怎么适配只读根文件系统？（答题方向：emptyDir 挂 /tmp、logback 配到 /app/logs）
10. `topologySpreadConstraints` 和 `podAntiAffinity` 的区别？什么时候用哪个？
11. PDB 的 minAvailable / maxUnavailable 怎么设？和 HPA minReplicas 什么关系？
12. IRSA 的完整认证链能画出来吗？OIDC Provider、ServiceAccount annotation、projected volume 各自起什么作用？
13. IRSA 和 EKS Pod Identity 的区别？你会迁到 Pod Identity 吗？
14. Secrets Store CSI Driver 相比直接用 K8s Secret 好在哪？它如何同步更新？
15. Fluent Bit、Prometheus Operator、ArgoCD、cert-manager 这些"平台组件"你怎么管理生命周期？（Helm / Addon / GitOps）
16. 如果 etcd 损坏你怎么恢复？（AWS 托管不用你管，但要答出理解：etcd 由 AWS 备份 + 快照恢复）
17. Service Mesh（Istio / Linkerd / AWS App Mesh）你上了吗？为什么上/为什么不上？
18. kubectl 用户怎么认证到 EKS？aws-auth ConfigMap 和 Access Entry 的区别？

---

## 六、微服务与 Spring Boot

1. 5 个服务的通信模式是什么？同步 REST、异步消息、还是混用？边界是怎么定的？
2. 服务间调用为什么不用 Feign/Dubbo/gRPC？你选了什么？理由？
3. 服务发现怎么做？K8s Service DNS 足够吗？（答题方向：Headless Service / Service Discovery / Mesh）
4. 熔断、限流、重试、超时分别在哪一层做？为什么？（答题方向：客户端 Resilience4j、网关层 WAF rate limit、K8s 层 NetworkPolicy）
5. 分布式事务你怎么处理？订单扣款+份额入账+持仓更新是跨服务的。（答题方向：Saga、TCC、Outbox Pattern、最终一致性）
6. Spring Boot 启动慢（10–60s），HPA 扩容滞后怎么办？（答题方向：CDS、AppCDS、GraalVM Native Image、预热流量、startupProbe）
7. Spring Boot Actuator 的 `/health`、`/readiness`、`/liveness` 差别？K8s 的 liveness 和 readiness 各自触发什么？
8. Actuator 暴露在哪个端口？怎么防止 `/env`、`/heapdump` 被外部访问到？
9. 配置管理用的是什么？Spring Cloud Config、Consul、K8s ConfigMap、AWS AppConfig？为什么？
10. 数据库连接池用什么？池大小怎么算？和 RDS Proxy 关系？（答题方向：HikariCP、pool_size = ((core_count * 2) + effective_spindle_count)、RDS Proxy 做"池的池"）
11. JVM 调优：堆内存、GC、容器感知（`-XX:+UseContainerSupport`）你做了什么？
12. Java 版本选什么？为什么不是 Java 8？（答题方向：Java 17/21 LTS、virtual threads、performance、support lifecycle）
13. Order 服务的幂等性怎么保证？（答题方向：幂等 key、DB unique constraint、状态机）
14. 定投计划（Plan 服务）的调度怎么做？单机 cron？分布式调度？（答题方向：ShedLock、XXL-Job、EventBridge Scheduler、K8s CronJob + Leader Election）

---

## 七、数据层（Aurora Global / RDS Proxy / Redis / S3）

1. 为什么选 Aurora PostgreSQL 而不是 RDS PostgreSQL？（答题方向：存算分离、6 副本跨 3 AZ、故障切换 <30s、Global Database）
2. Aurora Global Database 的同步是同步还是异步？典型延迟是多少？对金融一致性有什么影响？（答题方向：物理复制异步，典型 <1s，RPO 通常 <1s 但不为 0）
3. Aurora writer vs reader endpoint 怎么用？写多读少 vs 读多写少场景？
4. RDS Proxy 解决了什么问题？不用会怎样？（答题方向：连接风暴、failover 透明化、IAM 认证、Secrets Manager 集成）
5. 读写分离你是怎么做的？用 Spring 的 `@Transactional(readOnly=true)` 够吗？副本延迟如何兜底？
6. 数据库迁移（migration）你用什么？Flyway / Liquibase？蓝绿部署时 DDL 如何不破坏老版本？（答题方向：expand-contract / backward-compatible migration）
7. 大表分库分表你怎么考虑？Aurora 单实例能撑多大？（答题方向：Aurora 最大 128TB；垂直/水平拆分；用 Citus/TiDB 的决策点）
8. 订单表索引设计：按 user_id、fund_code、status、created_at 常见查询，你会建哪些索引？
9. Redis 用在哪些场景？缓存策略（Cache-Aside、Write-Through、Write-Behind）选哪个？
10. 缓存穿透 / 击穿 / 雪崩 你怎么防？
11. Redis Cluster vs Sentinel vs ElastiCache Replication Group，你的选型？
12. Redis Multi-AZ 故障切换延迟多少？切换期间写请求怎么办？
13. 金融数据保留策略（7 年审计）怎么实现？（答题方向：S3 + Object Lock + Glacier 分层 + 账本表 Ledger / QLDB）
14. 对账数据量大，你会放 Aurora 还是放 Redshift / Athena？（答题方向：OLTP vs OLAP 拆分）
15. 交易流水是否考虑 event sourcing？
16. 你的备份策略：全量 + 增量？RPO 目标？如何验证备份可恢复？（答题方向：AWS Backup + Vault Lock + 定期 restore drill）

---

## 八、高可用与容灾（两地三中心 / RTO/RPO / DR）

1. "两地三中心"在中国监管语境下是什么要求？你在 AWS 上如何实现？（答题方向：国内定义：同城 2 + 异地 1；AWS 映射：同 region 3 AZ + 跨 region DR）
2. AZ 级别故障（比如 us-east-1a 整个挂）你的系统会怎么反应？（答题方向：ALB 自动剔除、EKS 重新调度、Aurora 自动切换到其他 AZ 的副本）
3. Region 级别故障呢？AWS 历史上 us-east-1 挂过几次，你怎么做演练？
4. 跨 region 切换：DNS 切（Route53 Failover Routing）vs Global Accelerator vs Active-Active，你怎么选？
5. Aurora Global 的"Managed Failover"和"Unplanned Failover"区别？RTO 分别多少？
6. 业务 RPO = 1min 意味着什么？哪些数据可以容忍丢 1 分钟？订单和持仓能容忍吗？
7. DR 演练怎么做？多久一次？演练标准是什么？
8. "warm standby"和"pilot light"和"active-active"的区别和成本？你选了哪种？为什么？
9. Circuit Breaker 在故障传播中起什么作用？你的配置阈值是怎么定的？
10. 如果主 region 的 Secrets Manager / KMS 不可用，你的应用还能起来吗？（答题方向：跨 region replication、multi-region key）
11. 数据回滚：如果上游发了一批错误订单，你怎么回滚？（答题方向：PITR + 补偿事务 + 幂等冲正）
12. 混沌工程（AWS FIS / Chaos Mesh）你做了什么实验？

---

## 九、安全与合规

1. "金融行业安全合规"你怎么理解？列举你知道的框架。（答题方向：PCI-DSS、SOC 2、ISO 27001、GDPR、个人信息保护法、反洗钱 AML、KYC、中国金融行业等保 2.0、香港 SFC）
2. KMS 的 Customer Managed Key vs AWS Managed Key，你在哪些场景用哪个？
3. 信封加密（Envelope Encryption）是怎么工作的？为什么不直接用 KMS 加密大数据？
4. 密钥轮换策略：自动轮换 vs 手动？业务无感轮换怎么做？
5. 敏感字段（身份证、银行卡号）存储怎么加密？应用层 vs 数据库层？（答题方向：应用层 AES-GCM + KMS DEK、Aurora TDE、字段级 vs 行级）
6. PII 脱敏日志：Fluent Bit / Logback 里怎么实现？
7. 零信任（Zero Trust）在你的架构里体现在哪？（答题方向：IAM 最小权限、IRSA、Network Policy、mTLS、Verified Access）
8. WAF 规则你上了哪些？Managed Rule vs Custom Rule？误伤怎么办？
9. Bot 攻击、薅羊毛、撞库你怎么防？
10. 接口签名防重放怎么做？
11. SQL Injection、XSS、CSRF 在你这个架构里分别在哪一层防？
12. 依赖漏洞（Log4Shell 级）怎么监控和处置？（答题方向：SBOM、Dependabot、Inspector、Snyk）
13. 镜像供应链安全：cosign 签名 + Kyverno 准入，具体怎么配？SLSA 等级你做到哪一级？
14. Root 账户怎么保护？用 root 做过什么？
15. 审计日志保留多久？CloudTrail Object Lock 保留年限怎么设？
16. 员工离职后，他的 AWS / Kubernetes / DB 权限怎么保证第一时间回收？
17. 如果发生数据泄露（data breach），你的应急响应流程是什么？72 小时上报怎么做到？
18. 渗透测试（Pen Test）周期和流程？AWS 上需要申请吗？
19. 客户资金数据的授权访问审计链：谁、何时、查了什么，如何做到全链路可追溯？
20. 跨境数据合规：中国 → 香港 / 香港 → 欧盟 / 欧盟 → 美国，分别有什么要求？

---

## 十、CI/CD 与 GitOps

1. 你的 CI/CD 整个链路：代码 commit 到 production，有哪几个环节？每个环节的质量门（quality gate）是什么？
2. 为什么选 GitHub Actions 而不是 Jenkins / GitLab CI？
3. ArgoCD 的 GitOps 模式 vs push 模式（Jenkins 推）的好处？回滚怎么做？
4. Argo Rollouts Canary 10%/50%/100% 的指标判定是什么？（答题方向：分析模板 AnalysisTemplate、基于 Prometheus 指标、自动回滚）
5. 蓝绿 vs 金丝雀 vs 滚动，金融场景你会怎么选？
6. 数据库 schema 变更和代码发布解耦的具体做法？（答题方向：Expand–Migrate–Contract、feature flag）
7. 生产变更的"双人复核（dual control）"怎么实现？
8. 回滚一个有数据库迁移的版本，怎么安全做？
9. Dev / Staging / Prod / DR 4 套环境的配置管理：同一套代码怎么保证配置不串？
10. Secrets 怎么进入 Pod？明文进 Git 绝对不行，那怎么办？（答题方向：Secrets Manager + CSI、External Secrets Operator、SOPS、Sealed Secrets）
11. Preview Environment（每个 PR 一套环境）值得做吗？成本怎么控？
12. CI 里的单元测试 / 集成测试 / 契约测试 / E2E 测试 分别什么时候跑？在哪里跑？
13. 镜像多大？构建时间多久？你做了哪些构建加速？（答题方向：Jib / Buildpacks、multi-stage Dockerfile、BuildKit cache、ECR pull-through cache、layer caching）
14. 单 region 部署 vs 多 region 同步部署，你怎么做？

---

## 十一、可观测性与告警

1. 可观测性的"三支柱"是什么？你的架构里分别是什么组件？（Metrics/Logs/Traces）
2. 为什么选 Prometheus + AMP 而不是直接用 CloudWatch Metrics？
3. Prometheus 数据长期存储怎么办？（答题方向：AMP、Thanos、Cortex、VictoriaMetrics、Mimir）
4. 日志采集为什么选 Fluent Bit 不选 Fluentd？
5. 日志量级评估：5 服务 * 100 Pod * 平均 10 logs/s * 1KB = 大约多少 GB/天？CloudWatch Logs 成本？
6. 日志采样（sampling）你怎么做？错误日志 100%、正常请求 1%？
7. 分布式追踪：X-Ray vs Jaeger vs Zipkin vs OpenTelemetry，你选什么？为什么？
8. Trace 怎么打通跨服务？Trace ID 怎么在 Spring Boot 里透传？（答题方向：OpenTelemetry Java Agent、W3C Trace Context）
9. 核心业务 SLI / SLO 怎么定义？（答题方向：下单成功率 99.9%、下单 P99 < 500ms、净值查询可用性 99.95%）
10. 错误预算（Error Budget）你怎么使用？什么时候会冻结发布？
11. 告警分级 P1/P2/P3 的通道：PagerDuty / Slack / Email 的差别？
12. 告警风暴（1 个故障触发 50 条告警）怎么抑制？
13. 值班（on-call）流程、MTTR / MTTD 指标你跟踪了吗？
14. RUM 和 Synthetic 区别？金融网站为什么两个都要？
15. APM 工具（NewRelic / Datadog）你会换吗？自建可观测栈的隐性成本？

---

## 十二、成本优化（FinOps）

1. 整个架构估算月成本大致分布：EKS / Aurora / Data Transfer / CloudFront / Observability 各占比多少？
2. 最大的成本项通常是什么？你怎么压？（答题方向：数据传输费常被忽视、NAT Gateway 流量费、跨 AZ 流量费）
3. Savings Plans vs Reserved Instances vs Spot 你怎么组合？
4. Graviton（ARM）迁移你会做吗？Spring Boot 有什么坑？
5. Spot 节省了多少？不敢用 Spot 的人会给什么理由？你怎么反驳？
6. 日志和监控成本也会很吓人（Datadog / CloudWatch），怎么控？
7. 无效闲置资源（孤儿 EBS、未用 EIP、空 ALB）怎么持续治理？
8. Cost Anomaly Detection 上过吗？触发过什么事件？
9. Dev 环境如何白天开、晚上关？（EventBridge Scheduler / Knative / kube-green）
10. 多租户共用 EKS 集群 vs 每团队独立集群，成本和运维负担权衡？

---

## 十三、金融业务场景（领域题，差异化加分）

1. 基金净值（NAV）是 T+1 披露的，你的架构怎么支撑下单时的"预估金额 vs 最终金额"体验？
2. QDII 基金跨时区，下单 cut-off 时间怎么处理？（UTC vs 本地时区、多基金公司 cut-off 不同）
3. 申购 / 赎回 / 定投 / 转换 四种订单的状态机区别？
4. 份额确认前用户撤单怎么处理？
5. 基金分红（现金分红 / 红利再投）的技术实现？
6. 反洗钱 (AML) 监控：大额交易、可疑交易模式（如短进短出）怎么在系统里做？
7. KYC 身份核验流程：OCR + 活体 + 征信 + 风测问卷，怎么编排？（答题方向：Step Functions、状态机）
8. 适当性管理（风测 C1–C5 匹配 R1–R5 产品），规则引擎怎么做？（答题方向：Drools、Easy Rules、DMN）
9. 持仓实时估值 vs 净值估值 vs 确认份额估值，三套数据口径怎么管理？
10. 分红、拆分、基金合并、基金清盘 这些公司行为（corporate action）怎么在数据模型里表达？
11. 对账：每天和基金公司 / 支付通道 / 托管行 的三方对账怎么做？不平怎么处理？
12. 清结算时间窗（T / T+1 / T+2）你的系统怎么调度？幂等和重试怎么设计？
13. 资金账户余额必须严格正确，零差错。你的设计怎么保证？（答题方向：账户 + 流水双写、Ledger 模式、数据库事务 + 对账机制）
14. 大额交易延迟到达（T+1 才收到支付回调），用户看到的状态怎么体现？
15. 理财产品"业绩比较基准"这类营销展示与"预期收益率"有什么合规差异？你的系统怎么防止越红线？
16. 香港 SFC / 中国证监会 对系统留痕有什么硬性要求？
17. 一个客户 1 年前的某笔交易要求打印回单，你系统能做到吗？
18. 系统熔断（比如基金公司接口挂了）时，用户体验怎么设计？（答题方向：降级只读、页面 banner、已下单可查看）
19. 高并发场景：一只爆款基金秒杀式限额发行，你的架构怎么扛？（答题方向：库存预扣、令牌桶、队列削峰、结果异步通知）
20. 夜间批处理（日终估值、清算、对账）和实时交易的资源隔离？

---

## 十四、故障场景与排障（临场实战题）

> 面试官经常会给一个故障场景，让你现场推演。

1. 用户反馈"下单后没扣钱但显示持仓增加了"，你怎么排查？
2. Grafana 告警：某服务 P99 从 200ms 涨到 3s，从哪里开始查？
3. 一个 Pod 不断 OOMKilled，排查思路？
4. Aurora 写入突然变慢，怎么定位？（答题方向：慢查询日志、Performance Insights、autovacuum、锁等待）
5. Redis 命中率突然从 95% 跌到 30%，可能原因？
6. ECR pull 拉镜像 429 限流，怎么办？
7. CI Pipeline 连续 10 分钟都在 pending，怎么排查？
8. 某个 AZ 的 Pod 突然全部 NotReady，但其他 AZ 正常，查什么？
9. ArgoCD sync 显示 OutOfSync 但看起来配置一致，怎么查？
10. CloudFront 返回 502，ALB 正常，怎么定位？
11. 一个新服务上线后，整个 VPC 出口流量激增，但业务日志显示正常调用量，怎么查？（NAT Gateway 流量异常排查）
12. HPA 配置了但 Pod 不扩容，排查路径？（Metrics Server / 资源 request / HPA events）
13. 用户反馈"有时候登录会失败"，怎么排查偶发问题？
14. 下单接口每天凌晨 2 点必定有一波 5xx，怎么查？（答题方向：定时任务争抢、数据库 auto-vacuum、证书刷新）
15. 生产数据库 CPU 100% 了，立刻的应急动作顺序是什么？

---

## 十五、架构权衡与行为面试

1. 你这套架构最大的技术债是什么？
2. 如果从头再来，你会不一样地做什么？
3. 做架构决策时，你怎么处理"老板喜欢新技术，团队不熟"的冲突？
4. 跨团队协作：如何让前端 / 算法 / DBA / 安全团队都接受你的架构？
5. 如何说服管理层投入额外预算做 DR 演练？
6. 架构文档你怎么维护？谁来 review？
7. 新人 onboarding 到这个系统，你会怎么安排？
8. 技术选型争议最激烈的一次是什么？你是怎么推动结论的？
9. 这个项目上你踩过最大的坑？
10. 如果给你 3 个月 + 3 个工程师，你会怎么规划 plan D 的落地路线？
11. 一个不懂技术的产品经理问你"我们的系统安全吗？"，你怎么回答？
12. "架构师"和"高级开发"的核心差别，你怎么理解？
13. 你怎么持续学习 AWS 新服务？（Re:Invent / What's New / Well-Architected Framework）
14. Well-Architected Framework 的六大支柱是什么？你架构里每个支柱体现在哪？
15. 你最推崇的架构原则是什么？为什么？

---

## 附：可能追问的"深水炸弹"题（答好一道就是加分项）

- Aurora 的 buffer pool 是全局共享还是 per-instance？故障切换后为什么 reader 会有短暂慢？
- EKS Pod IP 用的是 VPC CNI，ENI 耗尽了怎么办？（答题方向：prefix delegation、Secondary CIDR、Custom Networking）
- K8s `imagePullPolicy: Always` 在 production 是好还是坏？
- Java 容器里 `Runtime.availableProcessors()` 在 K8s limits 下返回什么？`-XX:ActiveProcessorCount` 什么时候用？
- JIT 编译在短生命周期 Pod（Spot 被回收）里是不是浪费？AOT / Native Image 的权衡？
- Aurora 和 PostgreSQL 行为不一致的坑你踩过吗？（答题方向：fast DDL、logical replication 限制、某些扩展不支持）
- K8s 资源 request 和 limit 不等时，Node 会 overcommit。金融生产你敢 overcommit 吗？
- ALB 的空闲超时、Spring Boot Tomcat 的 `connectionTimeout`、HikariCP 的 `idleTimeout`，三者关系和不一致会导致什么问题？
- 你能画出 TCP 连接从客户端到 Pod 经过了几层 NAT / LB 吗？
- Pod 启动时从 Secrets Manager 拉密钥失败，会怎么样？你怎么让它 graceful fail？
- 数据库连接 leak 排查：生产上 connection count 持续上涨，不释放，怎么定位到代码行？
- 时钟漂移（clock skew）在分布式系统里会造成什么金融事故？NTP / chrony 你怎么保证？
- 如果被问"你这个架构能扛双 11 级流量吗"，你怎么量化回答？

---

## 使用建议

1. **别死记硬背**：面试官大概率会顺着你的答案追问 3 层。每题答到能展开为什么 / 代价 / 替代方案，比背答案更重要。
2. **选 3–5 个最熟的亮点**（比如 IRSA 链路、Aurora Global 切换、Canary 分析），准备到能画图、讲故事、报数字的深度。
3. **数字化**：QPS、延迟、成本、RTO/RPO、实例规格都准备具体数字，不要"比较多 / 比较快"。
4. **反向提问**：面试尾声问"贵司如何做 DR 演练 / 多 region / 合规"，把不会的领域转成双向技术交流。
5. **承认不会**：遇到不懂的，诚实说"这块没做过，但基于 XX 原则我会这样起步"远比硬编好。
