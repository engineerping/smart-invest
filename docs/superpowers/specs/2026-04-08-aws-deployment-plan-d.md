# AWS Deployment Plan D — Enterprise EKS (Financial-Grade, Interview Showcase)

**Audience**: Solutions Architect Professional 企业级金融产品生产参考  
**Goal**: 金融级安全、弹性伸缩、合规可审计、零停机部署  
**Cost**: 不考虑成本（约 $2,000-5,000/月，视规模）  
**Certification alignment**: AWS Certified Solutions Architect – Professional (SAP-C02)

---

## Executive Summary

本方案以"金融级"为核心设计原则，覆盖以下五个维度：

1. **Security** — 纵深防御（Defense in Depth），满足 SOC2 / PCI-DSS 合规要求
2. **Reliability** — Multi-AZ 高可用，RTO < 1 分钟，RPO < 5 分钟
3. **Scalability** — Kubernetes HPA + Cluster Autoscaler，按需弹性
4. **Observability** — 全链路追踪、结构化日志、实时告警
5. **Auditability** — 完整操作审计，满足金融监管要求

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AWS Account Structure                               │
│                                                                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │  Management Acct  │  │   Shared Services │  │   Production Account      │  │
│  │  (AWS Organizations│  │   (Security,Logs) │  │   (Workloads)            │  │
│  │   CloudTrail Org  │  │   Security Hub    │  │                          │  │
│  │   SCPs            │  │   GuardDuty       │  │   EKS Cluster            │  │
│  └──────────────────┘  └──────────────────┘  │   Aurora PostgreSQL       │  │
│                                               │   ElastiCache Redis       │  │
│                                               └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘

Internet
  └── Route 53 (smartinvest.com, DNSSEC enabled)
        └── app.smartinvest.com
              └── CloudFront (WAF + Shield Standard)
                    ├── /* (GET/HEAD/OPTIONS) → S3 OAC (React SPA)
                    └── /api/* → ALB (HTTPS only, SSL termination)
                                  └── EKS Ingress (AWS Load Balancer Controller)
                                        ├── /api/v1/users/*    → user-service Pod
                                        ├── /api/v1/funds/*    → fund-service Pod
                                        ├── /api/v1/orders/*   → order-service Pod
                                        ├── /api/v1/portfolio/*→ portfolio-service Pod
                                        └── /api/v1/plans/*    → plan-service Pod

VPC Architecture (3 Tier):
┌─────────────────────────────────────────────────────┐
│  VPC 10.0.0.0/16                                    │
│                                                     │
│  Public Subnets (3 AZs, /24 each)                   │
│  ├── NAT Gateway × 3 (one per AZ)                   │
│  └── ALB                                            │
│                                                     │
│  Private Subnets — App Tier (3 AZs, /22 each)       │
│  └── EKS Worker Nodes (Node Groups)                 │
│      ├── system-ng: On-Demand t3.medium (core)      │
│      ├── app-ng: On-Demand m5.large (stateless app) │
│      └── spot-ng: Spot m5.large/c5.large (batch)    │
│                                                     │
│  Private Subnets — Data Tier (3 AZs, /24 each)      │
│  ├── Aurora PostgreSQL Cluster (Multi-AZ)           │
│  ├── Aurora Read Replicas × 2                       │
│  └── ElastiCache Redis (Multi-AZ, session cache)    │
│                                                     │
│  VPC Endpoints (no traffic leaves AWS network)      │
│  ├── S3 Gateway Endpoint                            │
│  ├── ECR API / ECR DKR Interface Endpoints          │
│  ├── Secrets Manager Interface Endpoint             │
│  ├── SSM Interface Endpoint                         │
│  └── CloudWatch Logs Interface Endpoint             │
└─────────────────────────────────────────────────────┘
```

---

## 1. Security Architecture（纵深防御）

### 1.1 账号与身份（Identity & Access Management）

**AWS Organizations + Service Control Policies (SCPs)**

```
Root
└── Production OU
    └── smart-invest-prod (Account)
        SCP: DenyLeavingOrganization
        SCP: RequireMFAForConsole
        SCP: DenyRegionsExceptApprovedList
        SCP: DenyS3PublicAccess
```

**IAM 最小权限原则**

- 所有操作使用 IAM Roles，禁止 IAM User 长期凭证
- EKS Pod 使用 **IRSA (IAM Roles for Service Accounts)**，每个 Service 独立 Role，不共享
- 禁止 `*` 通配符 Action（使用 IAM Access Analyzer 检测）
- 定期自动轮换 IAM Roles Session（通过 IRSA 机制实现）

**示例：portfolio-service 的 IRSA**

```yaml
# Kubernetes ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: portfolio-service
  namespace: smart-invest
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/smart-invest-portfolio-sa-role
---
# IAM Role Policy（只允许读取特定 Secret）
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue"],
  "Resource": "arn:aws:secretsmanager:us-east-1:123456789:secret:smart-invest/prod/*"
}
```

### 1.2 网络安全（Network Security）

**多层隔离**：

```
CloudFront WAF Rules:
  ├── AWS Managed Rules: CommonRuleSet, KnownBadInputsRuleSet, SQLiRuleSet
  ├── Rate limiting: 1000 req/5min per IP
  ├── Geo restriction: 按需配置
  └── Bot Control: CAPTCHA for suspicious traffic

Security Groups (Whitelist only, no broad CIDR):
  ├── alb-sg:     Inbound 443 from CloudFront managed prefix list
  ├── eks-node-sg: Inbound from alb-sg only (port range per service)
  ├── aurora-sg:  Inbound 5432 from eks-node-sg only
  └── redis-sg:   Inbound 6379 from eks-node-sg only

Network Policy (Kubernetes, via Calico or AWS VPC CNI):
  ├── Default Deny All (ingress + egress)
  └── Explicit allow per service pair
```

**TLS Everywhere**:

- CloudFront → ALB: TLS 1.2+（ACM 证书）
- ALB → EKS Pod: TLS（cert-manager 签发集群内证书）
- Pod → Aurora: SSL required（`sslmode=verify-full`）
- Pod → Redis: TLS in-transit

### 1.3 密钥管理（Secrets Management）

```
AWS KMS (Customer Managed Keys):
  ├── KMS Key: smart-invest/aurora     → Aurora 静态加密
  ├── KMS Key: smart-invest/s3         → S3 对象加密
  ├── KMS Key: smart-invest/logs       → CloudWatch Logs 加密
  └── KMS Key: smart-invest/secrets    → Secrets Manager 加密

Secrets Manager（不允许硬编码任何密钥）:
  ├── smart-invest/prod/db-password    (每 30 天自动轮换)
  ├── smart-invest/prod/jwt-secret     (每 90 天手动轮换)
  ├── smart-invest/prod/ses-config     (SES SMTP credentials)
  └── smart-invest/prod/redis-auth     (Redis AUTH token)
```

**Pod 内密钥注入方式**（不用 K8s Secret 明文存储）：

```yaml
# 使用 Secrets Store CSI Driver
volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: smart-invest-secrets
```

### 1.4 合规与审计（Compliance & Audit）

```
CloudTrail:
  ├── Organization Trail（所有账号、所有区域）
  ├── S3 bucket with Object Lock (WORM, 7年保留)
  ├── CloudTrail Insights（异常 API 调用检测）
  └── 加密: KMS CMK

AWS Config:
  ├── 启用所有资源记录
  ├── Conformance Pack: AWS-FinancialServicesBestPractices
  └── Remediation Rules:
      ├── ec2-security-group-attached-to-eni (无孤立 SG)
      ├── s3-bucket-ssl-requests-only
      ├── rds-storage-encrypted
      └── eks-secrets-encrypted

GuardDuty + Security Hub:
  ├── GuardDuty: 威胁检测（EC2, S3, IAM, EKS Runtime）
  ├── Security Hub: 聚合 GuardDuty + Config + Inspector 发现
  └── EventBridge → SNS → PagerDuty（高危告警即时通知）

Amazon Inspector:
  └── 持续扫描 ECR 镜像中的 CVE（镜像 push 后自动扫描）
```

---

## 2. EKS Cluster Architecture

### 2.1 Cluster 配置

```yaml
# eksctl cluster config
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: smart-invest-prod
  region: us-east-1
  version: "1.30"

# 私有 API Server（不对公网暴露）
privateCluster:
  enabled: true

# 控制平面日志全部开启
cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator", "controllerManager", "scheduler"]

# 加密 etcd（存储所有 K8s secrets）
secretsEncryption:
  keyARN: arn:aws:kms:us-east-1:123456789:key/xxx

managedNodeGroups:
  - name: system
    instanceType: t3.medium
    minSize: 2
    maxSize: 4
    desiredCapacity: 2
    labels: {role: system}
    taints:
      - key: CriticalAddonsOnly
        value: "true"
        effect: NoSchedule

  - name: app-ondemand
    instanceType: m5.large
    minSize: 2
    maxSize: 10
    desiredCapacity: 2
    labels: {role: app, capacity-type: on-demand}

  - name: app-spot
    instanceTypes: ["m5.large", "m5.xlarge", "c5.large", "c5.xlarge"]
    spot: true
    minSize: 0
    maxSize: 20
    labels: {role: app, capacity-type: spot}
    taints:
      - key: spot
        value: "true"
        effect: NoSchedule
```

### 2.2 Core Add-ons

| Add-on                       | 用途                                       |
| ---------------------------- | ---------------------------------------- |
| AWS Load Balancer Controller | 将 Ingress 转换为 ALB                        |
| Cluster Autoscaler           | Node 自动扩缩                                |
| Karpenter（可替代 CA）            | 更快的 Node 供给，成本优化                         |
| CoreDNS                      | 集群内 DNS                                  |
| AWS VPC CNI                  | Pod 直接使用 VPC IP                          |
| cert-manager                 | 集群内 TLS 证书管理                             |
| Secrets Store CSI Driver     | 挂载 AWS Secrets Manager                   |
| Metrics Server               | HPA 依赖                                   |
| Prometheus + Grafana         | 监控（via kube-prometheus-stack Helm chart） |
| Fluent Bit                   | 日志采集，发往 CloudWatch Logs                  |
| AWS X-Ray Daemon             | 分布式追踪                                    |
| Calico                       | Network Policy 实施                        |

### 2.3 GitOps with ArgoCD

```
Git Repository (infra/k8s/)
  └── ArgoCD Application (自动同步)
        ├── Namespace: smart-invest
        ├── RBAC: 最小权限
        └── Sync Policy: automated + prune + selfHeal

CD Pipeline:
  GitHub Actions (build + push ECR)
      → 更新 infra/k8s/overlays/prod/kustomization.yaml 中的 image tag
      → Git commit + push
      → ArgoCD 检测到变更，自动 apply
      → EKS 滚动更新（零停机）
```

---

## 3. Application Deployment（Kubernetes Manifests）

### 3.1 Deployment（以 portfolio-service 为例）

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio-service
  namespace: smart-invest
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0        # 零停机部署
  selector:
    matchLabels:
      app: portfolio-service
  template:
    metadata:
      labels:
        app: portfolio-service
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      serviceAccountName: portfolio-service
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule    # 跨 AZ 均匀分布
      containers:
        - name: app
          image: 123456789.dkr.ecr.us-east-1.amazonaws.com/smart-invest:abc123
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: 500m
              memory: 1Gi
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 15
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: secrets-store
              mountPath: "/mnt/secrets"
              readOnly: true
            - name: tmp
              mountPath: /tmp                 # readOnlyRootFilesystem 需要 tmp 可写
      volumes:
        - name: secrets-store
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: smart-invest-secrets
        - name: tmp
          emptyDir: {}
```

### 3.2 HPA（水平自动扩缩）

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: portfolio-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: portfolio-service
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300    # 缩容延迟，避免抖动
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
```

### 3.3 PodDisruptionBudget（维护时保障可用性）

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: portfolio-service-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: portfolio-service
```

---

## 4. Database Architecture（金融级数据安全）

### 4.1 Aurora PostgreSQL Global Database

```
Primary Region (us-east-1):
  Aurora PostgreSQL Cluster
    ├── Writer Instance (db.r6g.large)
    └── Reader Instances × 2 (db.r6g.large, Multi-AZ)

Secondary Region (us-west-2) [DR]:
  Aurora Global Cluster Secondary
    └── Reader × 1 (可在 RTO < 1分钟内提升为 Primary)

配置:
  ├── Storage: Aurora 自动扩展（最大 128 TB）
  ├── 静态加密: KMS CMK
  ├── 传输加密: SSL 强制
  ├── 备份: 连续备份 35 天，跨区域备份 (PITR)
  ├── 审计日志: pgaudit 扩展（记录所有 DDL/DML）
  ├── IAM Database Authentication: 替代密码认证
  └── Deletion Protection: 开启
```

### 4.2 Aurora 参数调优（金融场景）

```
synchronous_commit = on           # 不牺牲持久性换性能
wal_level = logical               # 支持逻辑复制
log_connections = on              # 记录所有连接
log_disconnections = on
log_duration = on
pgaudit.log = 'write, ddl'       # 审计写操作和DDL
```

### 4.3 RDS Proxy（连接池）

```
RDS Proxy:
  ├── 最大连接数: 1000（Aurora 单实例上限约 5000）
  ├── 连接复用: 减少 Spring Boot 每次重建连接的开销
  ├── Secrets Manager 集成: 自动轮换密码无需重启应用
  └── Failover 加速: Proxy 感知 Aurora failover，应用透明切换
```

### 4.4 AWS Backup（合规备份）

```
Backup Plan: SmartInvestFinancialBackup
  ├── Daily backup: 保留 35 天
  ├── Weekly backup: 保留 1 年
  ├── Monthly backup: 保留 7 年（金融监管要求）
  ├── Cross-region copy: us-west-2
  └── Vault Lock (WORM): 防止备份被删除（合规要求）
```

---

## 5. Observability（全链路可观测性）

### 5.1 Metrics（指标）

```
Prometheus (kube-prometheus-stack Helm chart)
  ├── 集群指标: node-exporter, kube-state-metrics
  ├── 应用指标: Spring Boot Actuator /actuator/prometheus
  └── 自定义指标: 业务 KPI（每日交易量、API 成功率）

Grafana Dashboards:
  ├── Cluster Overview
  ├── Application RED Metrics (Rate / Error / Duration)
  ├── JVM Metrics (Heap, GC, Threads)
  └── Business Metrics Dashboard

Amazon Managed Prometheus + Managed Grafana (可选，无需自运维)
```

### 5.2 Logs（日志）

```
Fluent Bit DaemonSet
  └── 采集所有 Pod 日志
        ├── CloudWatch Logs（/aws/eks/smart-invest/application）
        └── (可选) Amazon OpenSearch Service（高级日志分析）

日志格式: JSON 结构化（Spring Boot 已配置）
日志保留:
  ├── CloudWatch: 90 天热存储
  └── S3 + Glacier: 7 年归档（合规）

CloudWatch Log Insights 查询示例:
  fields @timestamp, level, message, traceId
  | filter level = "ERROR"
  | sort @timestamp desc
  | limit 100
```

### 5.3 Traces（分布式追踪）

```
AWS X-Ray:
  ├── Spring Boot 集成 X-Ray SDK（或 OpenTelemetry）
  ├── 追踪: HTTP 请求 → Service → RDS → Redis
  └── Service Map: 可视化依赖关系

OpenTelemetry Collector（推荐）:
  └── 统一收集 Metrics + Logs + Traces，发往 AWS 原生服务
```

### 5.4 Alerting（告警）

```
告警层次:
  P1 (Critical, PagerDuty 即时): 
    ├── API 错误率 > 5%（5分钟）
    ├── 数据库连接池耗尽
    └── Pod CrashLoopBackOff

  P2 (Warning, Slack/Email):
    ├── CPU > 80% 持续 10 分钟
    ├── 内存 > 85% 持续 10 分钟
    └── 慢查询 > 1 秒

AWS CloudWatch Alarms → SNS → Lambda → PagerDuty/Slack
```

---

## 6. CI/CD Pipeline（GitOps）

```
┌─────────────────────────────────────────────────────────────┐
│                     CI Pipeline (GitHub Actions)            │
│                                                             │
│  PR Opened                                                  │
│    ├── Unit Tests (mvn test)                                │
│    ├── Integration Tests (testcontainers)                   │
│    ├── SAST: SonarQube / Checkmarx                          │
│    ├── Dependency Scan: OWASP Dependency-Check              │
│    └── Container Scan: Amazon Inspector (ECR)               │
│                                                             │
│  Merge to main                                              │
│    ├── Build JAR                                            │
│    ├── Build Docker Image                                   │
│    ├── Push to ECR                                          │
│    ├── Sign Image (AWS Signer / cosign)                     │
│    └── Update infra/k8s image tag → git commit             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  CD Pipeline (ArgoCD GitOps)                │
│                                                             │
│  infra repo change detected                                 │
│    ├── Deploy to staging (auto)                             │
│    ├── Run smoke tests                                      │
│    ├── Deploy to prod (manual approval gate)                │
│    └── ArgoCD Rollout: Canary 10% → 50% → 100%             │
│         └── Argo Rollouts 分析: error rate < 1% 才继续      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Image Signing（镜像签名验证）**：

```bash
# 只允许运行已签名镜像（防止供应链攻击）
# OPA Gatekeeper Policy
# 或 Kyverno Policy
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  rules:
    - name: verify-signature
      match:
        resources:
          kinds: [Pod]
      verifyImages:
        - imageReferences: ["123456789.dkr.ecr.us-east-1.amazonaws.com/*"]
          attestors:
            - entries:
                - keyless:
                    issuer: "https://token.actions.githubusercontent.com"
```

---

## 7. Disaster Recovery Strategy

### 7.1 RTO / RPO 目标

| 故障类型      | RTO    | RPO   | 实现方式                              |
| --------- | ------ | ----- | --------------------------------- |
| Pod 故障    | < 30秒  | 0     | K8s 自动重调度                         |
| Node 故障   | < 2分钟  | 0     | Cluster Autoscaler 补充节点           |
| AZ 故障     | < 5分钟  | 0     | Multi-AZ Pod 分布 + Aurora Multi-AZ |
| Region 故障 | < 15分钟 | < 5分钟 | Aurora Global + 跨区域 EKS           |
| 数据误删      | < 30分钟 | < 5分钟 | Aurora PITR                       |

### 7.2 Aurora Failover 流程

```
Aurora Writer AZ-a 故障
  → Aurora 自动检测（约 30 秒）
  → Reader (AZ-b) 自动提升为 Writer
  → RDS Proxy 自动感知，应用无需修改连接串
  → 应用短暂重试（Spring Boot HikariCP 重试机制）
  → 服务恢复正常
```

### 7.3 跨区域 DR 演练（每季度）

```bash
# Aurora Global Database 区域切换演练
aws rds failover-global-cluster \
  --global-cluster-identifier smart-invest-global \
  --target-db-cluster-identifier arn:aws:rds:us-west-2:...:cluster:smart-invest-dr
```

---

## 8. Cost Optimization（成本治理）

虽然不考虑成本，但专业架构师必须展示成本意识：

```
Compute:
  ├── Spot Instances: 非关键 Pod 使用 Spot（节省 60-80%）
  ├── Graviton3 (ARM): 切换 m6g/c6g 实例（性价比更高）
  └── Karpenter: 精准供给（避免 Node 浪费）

Storage:
  ├── S3 Intelligent-Tiering: 自动分层
  ├── EBS gp3 替代 gp2: 同性能更低成本
  └── CloudWatch Logs: 设置合理保留期

Governance:
  ├── AWS Cost Explorer: 标签策略，按服务/环境分摊
  ├── Savings Plans: 承诺使用折扣（可节省 40%）
  └── AWS Budgets: 多层预算告警
```

---

## 9. Infrastructure as Code

**全部基础设施使用 IaC 管理，禁止手动操作**：

```
工具选型:
  ├── Terraform: 所有 AWS 资源（VPC, EKS, RDS, CloudFront, WAF 等）
  ├── Helm: EKS Add-ons（Prometheus, Cert-manager, ArgoCD 等）
  ├── Kustomize: 应用 K8s Manifests（区分 dev/staging/prod）
  └── ArgoCD: GitOps CD 控制器

目录结构:
  infra/
  ├── terraform/
  │   ├── modules/
  │   │   ├── vpc/
  │   │   ├── eks/
  │   │   ├── aurora/
  │   │   └── cloudfront/
  │   └── environments/
  │       ├── prod/
  │       └── staging/
  ├── helm/
  │   └── values/
  │       ├── prometheus.yaml
  │       └── argocd.yaml
  └── k8s/
      ├── base/
      └── overlays/
          ├── staging/
          └── prod/

State Management:
  ├── Terraform state: S3 + DynamoDB locking
  └── State encryption: KMS CMK
```

---

## 10. Architecture Diagram Summary（面试白板版）

```
                          ┌─────────────────────────────────────────┐
                          │           Security Perimeter             │
      Internet            │                                         │
Users ──────► Route 53    │   CloudFront                           │
             (DNSSEC)     │   ├── WAF (SQL injection, XSS, Rate)   │
                │         │   ├── Shield Standard (DDoS)           │
                ▼         │   ├── /* → S3 (React SPA, OAC)         │
          CloudFront ─────┤   └── /api/* → ALB                     │
                          │                   │                     │
                          │            EKS Cluster                  │
                          │   ┌────────────────────────────────┐   │
                          │   │  Namespace: smart-invest        │   │
                          │   │                                │   │
                          │   │  [user-svc] [fund-svc]         │   │
                          │   │  [order-svc] [portfolio-svc]   │   │
                          │   │  [plan-svc]                    │   │
                          │   │                                │   │
                          │   │  IRSA ──► Secrets Manager      │   │
                          │   │  X-Ray, Fluent Bit sidecar     │   │
                          │   └────────────────────────────────┘   │
                          │                   │                     │
                          │   Data Tier (Private Subnet)            │
                          │   ├── Aurora PostgreSQL (Multi-AZ)      │
                          │   │   ├── Writer (AZ-a)                 │
                          │   │   └── Reader × 2 (AZ-b, AZ-c)      │
                          │   └── ElastiCache Redis (Multi-AZ)      │
                          │                                         │
                          │   Security: CloudTrail, GuardDuty,      │
                          │   Security Hub, Config, Inspector        │
                          └─────────────────────────────────────────┘

Cross-cutting:
  ├── AWS Organizations + SCPs
  ├── All traffic encrypted (TLS 1.2+, KMS at rest)
  ├── GitOps: GitHub Actions → ECR → ArgoCD → EKS
  ├── Observability: Prometheus + Grafana + X-Ray + CloudWatch
  └── DR: Aurora Global Database (us-west-2 secondary)
```

---

## Key Design Decisions（面试要点）

| 决策          | 选择                                      | 原因                                                  |
| ----------- | --------------------------------------- | --------------------------------------------------- |
| 容器编排        | EKS（而非 ECS Fargate）                     | 更细粒度控制，Network Policy，PDB，支持 Service Mesh           |
| 数据库         | Aurora PostgreSQL（而非 RDS）               | 更快的 Failover（<30s vs ~1min），存储自动扩展，Global Database  |
| 密钥注入        | Secrets Store CSI Driver（而非 K8s Secret） | K8s Secret 默认 base64 非加密，CSI 直接从 Secrets Manager 挂载 |
| 镜像管理        | ECR + Image Signing                     | 供应链安全，只允许已签名镜像运行                                    |
| GitOps CD   | ArgoCD（而非 kubectl apply）                | 自动漂移检测，审计追踪，声明式状态                                   |
| 负载均衡        | AWS LBC（ALB Ingress）                    | 原生 ALB，支持 target-type:ip，比 NodePort 更高效             |
| Autoscaling | HPA + Cluster Autoscaler/Karpenter      | Pod 级 + Node 级双层弹性                                  |
| 跨 AZ 分布     | topologySpreadConstraints               | 强制 Pod 跨 AZ 均匀分布，避免 AZ 单点                           |
| 数据库连接       | RDS Proxy                               | 连接池复用，密码自动轮换，Failover 加速                            |

---

## Reference Standards

- **AWS Well-Architected Framework**: 五大支柱全覆盖
- **CIS Amazon EKS Benchmark**: Kubernetes 安全基线
- **PCI-DSS v4.0**: 金融支付数据保护
- **SOC 2 Type II**: 数据安全和可用性
- **NIST Cybersecurity Framework**: 安全治理框架
