# Smart Invest 部署到 ASUS-Ubuntu K3S —— 部署指南与面试讲解

> 日期：2026-08-03
> 服务器：ASUS-Ubuntu (192.168.31.192, georgeserver, 2核/8GB)
> 分支：`multi-springboot-services-deploy-to-ubuntu-k3s`

---

## 一、当前已部署状态（2026-08-03 凌晨验证通过）

```
$ kubectl -n smart-invest get pods
NAME                          READY   STATUS    RESTARTS
api-gateway-...               1/1     Running   0
frontend-...                  1/1     Running   0
user-service-...              1/1     Running   0
fund-service-...              1/1     Running   0
order-service-...             1/1     Running   0
notification-worker-...       1/1     Running   0
rabbitmq-...                  1/1     Running   0
```

**完整业务闭环已验证**：注册 → 登录 → 浏览基金 → 下单(COMPLETED) → 持仓更新 → 异步通知，全部通过 Traefik Ingress 访问成功。

---

## 二、系统架构（面试讲解版）

```
公网 (内网穿透 frp/nps) → ASUS-Ubuntu:80/443
                                  │
                          ┌───────▼────────┐
                          │ Traefik Ingress │  ← K3S 自带（对应架构图 Kong/NLB）
                          └───────┬────────┘
      ┌──────────────┬───────────┴──────────┬──────────────┐
      ▼              ▼                      ▼              ▼
 frontend        api-gateway           user-service   fund-service
 (nginx:80)   (SpringCloudGateway)   (JWT/认证/用户)  (基金/持仓/组合)
      │              │ 8080                │              │
      │              └───────┬────────────┘              │
      │                      ▼                           │
      │               order-service (下单/结算)           │
      │                      │                           │
      │                      │ ──RabbitMQ──▶ notification-worker
      ▼                      ▼                           ▼
  ┌──────────────────────────────────────────────────────────┐
  │ Postgres 16 (宿主机 Docker, K3S 外)                       │
  └──────────────────────────────────────────────────────────┘
```

### 关键设计点（面试必讲）

| 架构点 | 对应架构图 | 本实现 |
|---|---|---|
| API 网关 | Kong Gateway + NLB | Spring Cloud Gateway，按路径路由 |
| 服务发现 | K8S CoreDNS | K8S Service DNS（`http://order-service:8083`） |
| 异步解耦 | Amazon MQ | RabbitMQ（order → 持仓更新 + 通知） |
| 数据库 | Aurora PostgreSQL | 宿主机 Postgres 16 + Flyway V1-V21 |
| 缓存 | ElastiCache | （演示版省略） |
| 监控 | CloudWatch + Prometheus | Prometheus + Grafana（待部署） |
| 密钥管理 | Secrets Manager | K8S Secret |
| 配置 | AppConfig | ConfigMap |

---

## 三、代码结构

```
backend/
├── pom.xml                  # 父 POM（统一依赖版本）
├── common/                  # 共享库：JWT/安全/异常处理/RabbitMQ 配置
├── user-service/            # 用户与认证（Flyway V1-V21 归它管）
├── fund-service/            # 基金+持仓+组合+定投（4个原模块合并）
├── order-service/           # 下单+结算（REST 调 fund 拿净值 + 发 MQ）
├── notification-worker/     # 消费 MQ 写通知
└── api-gateway/             # Spring Cloud Gateway 统一路由

infrastructure/
├── helm-charts/
│   ├── charts/              # 6 个独立 chart（每服务一个）
│   │   ├── user-service/ fund-service/ order-service/
│   │   ├── notification-worker/ api-gateway/ frontend/
│   │   └── rabbitmq/        # 自定义轻量 chart（官方镜像）
│   └── umbrella/            # 聚合 chart，一条命令部署全家
├── kustomize/               # 多环境 overlay（dev/uat/prd）
├── terraform-k3s/           # 学习版：Terraform 管 K3S
├── monitoring/              # ServiceMonitor
└── scripts/                 # build/deploy/setup 脚本
```

---

## 四、面试演示脚本（按顺序）

### 演示 1：完整业务闭环（3 分钟）

```bash
# 通过公网/内网穿透域名访问前端 → 注册账号 → 登录
# 或者直接 API 演示：
TOKEN=$(curl -s -X POST http://localhost/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@x.com","password":"password123","fullName":"Demo"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# 浏览基金
curl -s http://localhost/api/funds -H "Authorization: Bearer $TOKEN"

# 下单
curl -s -X POST http://localhost/api/orders -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"fundId\":\"<基金ID>\",\"orderType\":\"ONE_TIME\",\"amount\":10000}"

# 查看持仓（fund-service 经 RabbitMQ 异步更新）
curl -s http://localhost/api/holdings/me -H "Authorization: Bearer $TOKEN"

# 查看通知（notification-worker 经 RabbitMQ 异步写入）
curl -s http://localhost/api/notifications -H "Authorization: Bearer $TOKEN"
```

**讲解话术**：下单请求 → api-gateway 路由到 order-service → order-service REST 调用 fund-service 拿最新净值 → 结算 → 发 RabbitMQ 事件 → fund-service 更新持仓 + notification-worker 写通知。**同步调用（REST 服务发现）+ 异步解耦（消息队列）** 并行展示。

### 演示 2：K8S 自愈与弹性（2 分钟）

```bash
# 自愈：删掉一个 pod，K8S 自动重建
kubectl -n smart-invest delete pod user-service-xxxx
kubectl -n smart-invest get pods   # 看到新 pod 自动创建

# 扩容
kubectl -n smart-invest scale deployment/user-service --replicas=3
kubectl -n smart-invest get pods

# 缩容
kubectl -n smart-invest scale deployment/user-service --replicas=1
```

**讲解话术**：Deployment 是声明式控制器，保证"期望状态"始终达成。Pod 挂了自动重建（自愈），改副本数自动扩缩（弹性）。这就是 Kubernetes 的核心价值。

### 演示 3：CI/CD 一键部署（可选，需配置 GitHub Secrets）

```bash
# push 代码到 main → 触发 .github/workflows/cd-k3s.yml
# 自动：mvn build → docker build → push Docker Hub → SSH 连服务器 → helm upgrade
```

### 演示 4：监控指标（可选，需先部署监控栈）

```bash
./scripts/deploy-monitoring.sh   # 部署 Prometheus + Grafana
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
# 浏览器访问 localhost:3000，账号 admin/admin123
```

---

## 五、面试 Q&A 准备

### Q1: 为什么用 monorepo 而不是每个服务一个仓库？
**答**：小型团队 + 单一代码库，monorepo 降低协作成本。但**每个服务仍是独立 Helm chart**，可独立发布/回滚/扩缩容。这是"仓库形态"和"部署单元"的分离——工业界很多公司（如 Google、Shopify）也这么做。

### Q2: Helm 和 Kustomize 的区别？为什么都用？
**答**：Helm 是**模板引擎 + 包管理器**，负责把 chart 渲染成 YAML 并管理 release 生命周期（install/upgrade/rollback）；Kustomize 是**配置叠加器**，不引入模板语法，用 overlay 管理多环境差异。实践中 Helm 管"应用打包发布"，Kustomize 管"环境覆盖"，职责互补。我们以 Helm 为主（工业界标准），Kustomize 展示多环境 overlay 能力。

### Q3: 为什么用 RabbitMQ 而不是同步调用？
**答**：订单结算后，持仓更新和通知是"非关键路径"，用消息队列异步处理：① **解耦**——order-service 不关心谁消费，fund/notification 也不认识 order；② **削峰**——下单高峰时消息排队，worker 慢慢消费，保护数据库；③ **可靠性**——持久化队列，worker 宕机重启后消息不丢。对应架构图 Amazon MQ 的位置。

### Q4: 服务间调用用什么？服务发现怎么实现？
**答**：同步用 REST（RestTemplate/Feign），走 K8S Service DNS——`http://fund-service:8082`。K8S 内置 CoreDNS 提供服务发现，每个 Service 有稳定的 ClusterIP + DNS 名，Pod 伸缩不影响调用方。这就是架构图里 K8S CoreDNS 的职责。

### Q5: 数据库为什么不进 K8S？
**答**：生产上数据库这类有状态组件通常独立部署（托管 DB 或独立服务器），避免与无状态应用共享故障域。演示版 Postgres 跑在宿主机 Docker，K3S 里用 `hostAliases` 映射宿主机 IP 访问。这是架构上的务实取舍。

### Q6: 8GB 内存怎么分配？
**答**：4 个 Java 服务各 512MB 堆（JVM `-Xmx512m`），gateway 256MB，notification-worker 256MB，RabbitMQ 512MB，Postgres 1GB，Prometheus 512MB，Grafana 256MB，前端 nginx 64MB。总量约 3.4GB，留足余量。通过 K8S `resources.requests/limits` 保证调度和限制。

### Q7: 安全怎么处理？
**答**：JWT 无状态认证（各服务共享 secret 校验 token），数据库密码/JWT 密钥存 K8S Secret，非敏感配置用 ConfigMap。对应架构图 Secrets Manager + OAuth2 Center 的位置。

### Q8: 遇到过的坑？（展示解决问题的能力）
**答**：① **架构不匹配**——本地 Apple Silicon 构建的 arm64 镜像在 x86_64 服务器报 `exec format error`，改用服务器上构建 amd64 镜像导入 containerd；② **K8S 环境变量注入冲突**——RabbitMQ Service 自动注入 `RABBITMQ_PORT=tcp://...`，覆盖了 Spring 的 `spring.rabbitmq.port`，导致启动失败，用显式 env 覆盖解决；③ **ExternalName 服务指向 IP 不生效**，改用 `hostAliases` 映射宿主机；④ **单节点冷启动慢**，liveness 探针 90s 太短导致误杀，提高到 300s。

---

## 六、内网穿透接入说明

K3S 已配好 Traefik Ingress（监听 80/443），内网穿透软件把公网域名映射到 `192.168.31.192:80` 即可：

```
公网域名 → frp/nps 隧道 → 192.168.31.192:80 → Traefik Ingress
  ├── /      → frontend (React)
  └── /api/** → api-gateway → 各微服务
```

如果用 frp，配置参考：
```ini
# frpc.ini
[smart-invest-web]
type = http
local_ip = 127.0.0.1
local_port = 80
custom_domains = your-domain.com
```

面试时直接演示：浏览器打开公网域名 → 注册登录 → 下单 → 看通知。

---

## 七、常用运维命令

```bash
# 查看所有资源
kubectl -n smart-invest get all

# 查看日志
kubectl -n smart-invest logs deployment/user-service --tail=50

# 进入 pod
kubectl -n smart-invest exec -it <pod> -- sh

# 查看 RabbitMQ 管理台（端口转发）
kubectl -n smart-invest port-forward svc/rabbitmq 15672:15672
# 浏览器 localhost:15672，账号 smartmq/localdev_only

# 重新部署（改代码后）
./scripts/build-images.sh --push v2 && ./scripts/deploy-k3s.sh v2

# 完整重建
sudo helm uninstall smart-invest -n smart-invest
sudo helm install smart-invest /tmp/smart-invest-0.1.0.tgz -n smart-invest
```

---

## 八、已知限制（诚实交代，面试加分）

1. **单节点无高可用**——K3S 单控制面，演示自愈但非生产 HA
2. **服务发现用 CoreDNS**——生产可加 Istio 服务网格（架构图里就有）
3. **镜像导入非 CI**——演示环境离线导入镜像，CI 走 Docker Hub
4. **Postgres 单实例**——无备份/主从，生产应用托管 DB
5. **监控未部署**——Prometheus/Grafana 清单已备好（`deploy-monitoring.sh`）
