# Hydsoft Technology DevOps 面试题库（中英双语）
# DevOps Interview Q&A for Hydsoft Technology (Bilingual)

> **岗位背景**: SAP Business Network NextGen — Planning Collaboration Team  
> **平台**: SAP Kyma (Managed Kubernetes) + Azure DevOps + SAP Piper/Hyperspace Pipeline  
> **版本**: 基于 smart-invest K3S 项目实践经验 + 前同事面试指导  
> **面试官风格**: 聚焦 k8s 实操排查、CI/CD、Jenkins Pipeline、云相关概念  

---

## 目录 / Table of Contents

| 章节 | 主题 | Topics |
|------|------|--------|
| 一 | K8s 核心资源与排查 | Core K8s Resources & Troubleshooting |
| 二 | Helm Chart 实操 | Helm Hands-on |
| 三 | Jenkins & CI/CD Pipeline | Jenkins & CI/CD |
| 四 | Docker 与镜像优化 | Docker & Image Optimization |
| 五 | 云基础设施与 IaC | Cloud & IaC |
| 六 | 可观测性 | Observability |
| 七 | 综合场景题 | Scenario-Based Questions |
| 附 | 常用命令速查 | Command Cheat Sheet |

---

## 一、K8s 核心资源与排查 / Core K8s Resources & Troubleshooting

### Q1: K8s 有哪些最常用的资源？请简要说明各自的作用。

**答案：**

| 资源 | 作用 | 类比 |
|------|------|------|
| **Pod** | K8s 最小调度单位，运行一个或多个容器 | 集装箱 |
| **Deployment** | 管理 Pod 的副本数、滚动更新、自愈 | 管家/工头——保证 N 个工人( Pod )在线 |
| **ReplicaSet** | 维护指定数量的 Pod 副本（通常由 Deployment 管理，不直接操作） | 排班表 |
| **Service** | 给一组 Pod 提供固定的 DNS 名 + ClusterIP（服务发现） | 前台电话——打这个号就行，不管谁接 |
| **Ingress** | 将外部 HTTP(S) 流量路由到集群内部的 Service | 大楼门禁——根据路径把访客引导到对应楼层 |
| **ConfigMap** | 非敏感配置（如环境变量、配置文件） | 公告栏——所有人都能看到 |
| **Secret** | 敏感配置（密码、Token），base64 编码 | 保险柜 |
| **HPA** | 根据 CPU/内存自动调整 Pod 副本数 | 自动排班系统——忙时加人 |
| **PVC** | 持久化存储请求 | 申请一个仓库 |

**SAP Kyma 特有资源（面试可能问）：**

| 资源 | 作用 |
|------|------|
| **VirtualService** (Istio) | 流量路由：按权重/路径/Header 分发到不同版本的服务 |
| **ServiceInstance** | Kyma 管理的云服务实例（数据库、MQ 等绑定） |
| **APIRule** | Kyma 专用的 API 暴露规则（相当于 Ingress 的 Kyma 版） |

**在我的 smart-invest 项目中：**
- [deployment.yaml:1-70](infrastructure/helm-charts/charts/user-service/templates/deployment.yaml) — 定义 user-service 的 Deployment
- [service.yaml:1-20](infrastructure/helm-charts/charts/user-service/templates/service.yaml) — 定义 ClusterIP Service
- [ingress.yaml:1-41](infrastructure/helm-charts/umbrella/templates/ingress.yaml) — 定义 Traefik Ingress，`/` → frontend，`/api` → api-gateway

---

### Q1: What are the most common K8s resources? Briefly explain each.

**Answer:**

| Resource | Purpose | Analogy |
|----------|---------|---------|
| **Pod** | Smallest deployable unit; runs containers | A shipping container |
| **Deployment** | Manages replicas, rolling updates, self-healing | A foreman — keeps N workers online |
| **ReplicaSet** | Maintains a stable set of replica Pods (managed by Deployment) | Shift roster |
| **Service** | Provides stable DNS + ClusterIP for a set of Pods | Front desk — call one number, doesn't matter who picks up |
| **Ingress** | Routes external HTTP(S) traffic to internal Services | Building entrance — routes visitors by floor |
| **ConfigMap** | Non-sensitive config (env vars, config files) | Bulletin board |
| **Secret** | Sensitive config (passwords, tokens), base64 encoded | Safe |
| **HPA** | Auto-scales Pods based on CPU/memory | Auto-scheduler — adds people when busy |
| **PVC** | Persistent storage request | Warehouse lease |

**SAP Kyma-specific resources:**

| Resource | Purpose |
|----------|---------|
| **VirtualService** (Istio) | Traffic routing: by weight/path/header to different service versions |
| **ServiceInstance** | Kyma-managed cloud service binding (DB, MQ instances) |
| **APIRule** | Kyma-specific API exposure rule (Kyma's equivalent of Ingress) |

In my smart-invest project, each microservice has a Deployment + Service defined via Helm templates.

---

### Q2: Pod 反复 CrashLoopBackOff，你的排查步骤是什么？

**答案——标准排查流程（直接用你项目中的真实场景）：**

**Step 1: 查看 Pod 状态和最近事件**
```bash
kubectl get pods -n smart-invest
kubectl describe pod <pod-name> -n smart-invest
```
聚焦 Events 区域：OOMKilled、ImagePullBackOff、Liveness probe failed。

**Step 2: 查看容器日志**
```bash
# 查看当前日志
kubectl logs <pod-name> -n smart-invest --tail=200

# 如果 Pod 反复重启，查看上一次崩溃的日志（最关键！）
kubectl logs <pod-name> -n smart-invest --previous
```
面试官想听到 `--previous` 这个参数——这说明你真正在生产环境排查过。

**Step 3: 常见原因及对应解法**

| 现象 | 可能原因 | 解决 |
|------|----------|------|
| `OOMKilled` (exit code 137) | 内存 limit 太小或内存泄漏 | 增大 `resources.limits.memory`；或用 `jmap -heap 1` 排查泄漏 |
| `ImagePullBackOff` | 镜像不存在 / tag 打错 / pull 权限不足 | 检查 `image.repository` + `image.tag`，确认 Docker Hub 上有该镜像 |
| `CrashLoopBackOff` + exit code 1 | 应用启动报错（配置/数据库连接/JDK版本） | `kubectl logs --previous` 看启动堆栈 |
| `Liveness probe failed` | 健康检查配得太严 | 增大 `initialDelaySeconds`（如 300s），确保启动完才检查 |
| `Error` (exit code 143) | 收到 SIGTERM → 可能 preStop 有问题 | 检查 `terminationGracePeriodSeconds` 是否足够 |

**Step 4: 如果日志不够，查看 ConfigMap / Secret / 依赖**
```bash
kubectl describe configmap -n smart-invest
kubectl get secrets -n smart-invest
# 检查数据库能否连通
kubectl run debug --image=busybox -it --rm -- nslookup postgres-host
```

**我的项目中的实践：**
- 在 [deployment.yaml:63-69](infrastructure/helm-charts/charts/user-service/templates/deployment.yaml) 中 `initialDelaySeconds: 300`，给 JVM 充足启动时间
- `livenessProbe` 路径是 `/actuator/health`，Spring Boot Actuator 标准端点
- 在 [values.yaml:27-33](infrastructure/helm-charts/charts/user-service/values.yaml) 中 `resources.limits.memory: 768Mi`

---

### Q2: A Pod is in CrashLoopBackOff — what's your troubleshooting process?

**Answer — Standard flow:**

**Step 1: Check Pod status + events**
```bash
kubectl get pods -n smart-invest
kubectl describe pod <pod-name> -n smart-invest
```
Focus on the Events section.

**Step 2: Check logs — including previous crash**
```bash
# Current logs
kubectl logs <pod-name> -n smart-invest --tail=200

# Previous crash logs — the most important flag!
kubectl logs <pod-name> -n smart-invest --previous
```
Interviewers want to hear `--previous` — it proves real production troubleshooting experience.

**Step 3: Common causes & fixes**

| Symptom | Cause | Fix |
|---------|-------|-----|
| OOMKilled (exit 137) | Memory limit too low / memory leak | Increase `resources.limits.memory`; check heap with `jmap` |
| ImagePullBackOff | Image doesn't exist / wrong tag / no pull creds | Verify `image.repository` + `image.tag` on Docker Hub |
| CrashLoopBackOff + exit 1 | App startup error (config / DB / JDK) | `kubectl logs --previous` to see startup stack trace |
| Liveness probe failed | Probe config too strict | Increase `initialDelaySeconds` (e.g., 300s) |
| Error (exit 143) | SIGTERM → preStop issue | Check `terminationGracePeriodSeconds` |

**Step 4: Check dependencies**
```bash
kubectl describe configmap -n smart-invest
kubectl get secrets -n smart-invest
kubectl run debug --image=busybox -it --rm -- nslookup postgres-host
```

In my K3S project, `initialDelaySeconds: 300` gives the JVM enough startup time; liveness probe hits `/actuator/health`.

---

### Q3: 一个 Service 访问不通，你怎么逐层排查？

**答案——7 层排查法（从外到内）：**

**Layer 1 — Service 定义**
```bash
kubectl get svc user-service -n smart-invest -o yaml
```
检查 `selector` 是否匹配 Pod 的 labels（`app.kubernetes.io/name: user-service`）。

**Layer 2 — Endpoints 是否为空（最常见的原因）**
```bash
kubectl get endpoints user-service -n smart-invest
```
如果显示 `<none>`：selector 没匹配到任何 Ready 的 Pod。检查：
- Pod 的 labels 是否和 Service selector 一致
- Pod 的状态是否为 Running + Ready（Readiness Probe 通过了没）

**Layer 3 — Pod 是否 Ready**
```bash
kubectl get pods -n smart-invest -o wide
```
如果 READY 是 `0/1`：Readiness Probe 挂了。回到 Q2 排查 Pod。

**Layer 4 — DNS 解析**
```bash
kubectl run test --image=busybox -it --rm -- nslookup user-service.smart-invest.svc.cluster.local
```
如果解析不了：CoreDNS 挂了。

**Layer 5 — 网络策略**
```bash
kubectl get networkpolicies -n smart-invest
```
检查是否有 policy 阻止了流量。

**Layer 6 — 从其他 Pod 实测连通**
```bash
kubectl run debug --image=nicolaka/netshoot -it --rm -- /bin/bash
curl http://user-service:8081/actuator/health
```

**Layer 7 — 如果是外部访问不通（Ingress）**
```bash
kubectl get ingress -n smart-invest
kubectl describe ingress smart-invest -n smart-invest
```
检查 Ingress Controller（我的 K3S 项目用的是 Traefik）是否在运行，以及路由规则是否正确。

**在我的项目中**，[ingress.yaml](infrastructure/helm-charts/umbrella/templates/ingress.yaml) 定义了：`/` → frontend:80，`/api` → api-gateway:8080

---

### Q3: A Service is unreachable — how do you troubleshoot layer by layer?

**Answer — 7-layer troubleshooting (outside-in):**

**Layer 1 — Service definition** — `kubectl get svc <svc> -n <ns> -o yaml` — check selector matches Pod labels.

**Layer 2 — Endpoints** — `kubectl get endpoints <svc> -n <ns>` — if `<none>`, no Ready Pods matched.

**Layer 3 — Pod Ready?** — `kubectl get pods -n <ns>` — `0/1` READY means Readiness Probe failing.

**Layer 4 — DNS** — `nslookup <svc>.<ns>.svc.cluster.local` — CoreDNS check.

**Layer 5 — NetworkPolicy** — `kubectl get networkpolicies -n <ns>` — traffic blocked?

**Layer 6 — Connectivity test** — `curl http://<svc>:<port>/health` from a debug Pod.

**Layer 7 — External access (Ingress)** — `kubectl describe ingress` — check routing rules and Ingress Controller.

---

### Q4: 线上 SAP ERP 服务起不来了，你怎么排查？

**答案——面向 SAP Kyma 环境的排查思路：**

面试官很可能就是让你模拟真实值班场景，你需要展示的是一个 **有先后顺序、有逻辑** 的思路。

**第一分钟：快速分诊（Triage）**
- 影响范围：所有 region 还是单个？所有用户还是部分？
- 时间窗口：出问题前有什么变更（部署了没、改了配置没）？
- 看告警：Dynatrace / Grafana 有什么异常？错误率、延迟、Pod 重启次数

**第二分钟：判断是不是刚部署引入的**
```bash
# 看部署历史
kubectl rollout history deployment/<service> -n <namespace>

# 看 deploy 最近事件
kubectl describe deployment/<service> -n <namespace> | grep -A10 Events
```
如果最近一次部署刚过去几分钟 → 极大概率是部署引入 → **立即回滚**：
```bash
kubectl rollout undo deployment/<service> -n <namespace>
```

**第三~五分钟：K8s 层面排查**
```bash
# Pod 状态
kubectl get pods -n smart-invest | grep -v Running

# 最近事件（按时间排序）
kubectl get events -n smart-invest --sort-by='.lastTimestamp' | tail -50

# OOM? 镜像拉不下来? 探针失败?
kubectl describe pod <bad-pod> -n smart-invest

# 看日志
kubectl logs <bad-pod> -n smart-invest --tail=200 --previous
```

**第五分钟后：基础设施 + 依赖**
- 节点有没有问题：`kubectl get nodes` + `kubectl describe node <node>`
- Kyma 级资源：`kubectl get serviceinstances -n <ns>`（数据库/缓存绑定还正常吗）
- VirtualService / Istio：sidecar 有没有问题
- Vault 里的 secret / 证书有没有过期
- 数据库连不连得上（Aurora / HANA）
- 是不是级联故障（一个服务挂了拖死其他服务）

**快速绕过方案：**
```bash
# 改 ConfigMap 暂时关掉有问题的功能
kubectl edit configmap <config-name> -n <namespace>
kubectl rollout restart deployment/<service-name> -n <namespace>
```

**面试加分项：**
- 先恢复服务再找根因（"rollback first, debug later"）
- 事后写 PIR（Post-Incident Review），包含时间线、根因、预防措施
- 通过 GitOps 后渲染器为 manifest 打来源标签，告警一出就能追溯到具体 PR/Commit

---

### Q4: A production SAP ERP service won't start — how do you troubleshoot?

**Answer — SAP Kyma-oriented approach:**

**Minute 1: Triage** — blast radius, time window, alert review (Dynatrace/Grafana)

**Minute 2: Was there a recent deploy?** — `kubectl rollout history` → if yes, **rollback first, debug later**: `kubectl rollout undo deployment/<svc> -n <ns>`

**Minutes 3-5: K8s layer** — Pod status, events, logs (`--previous`), describe Pod

**Minutes 5+: Infrastructure & dependencies** — nodes, ServiceInstances, VirtualServices, Vault secrets/certs expiry, DB connectivity, cascading failures

**Quick fix:** Toggle ConfigMap or env vars to temporarily bypass the broken feature + `kubectl rollout restart`

**Bonus points:** Rollback first → find root cause later → write PIR with timeline + prevention

---

### Q5: Readiness Probe 和 Liveness Probe 的区别？怎么配置？

**答案：**

| | Readiness Probe | Liveness Probe |
|---|---|---|
| **目的** | Pod 能否接收流量？ | Pod 是否需要重启？ |
| **失败后果** | 从 Service 摘除，不接收请求 | kubelet 杀死容器并重建 |
| **典型检查** | 外部依赖是否就绪？（DB、Redis、MQ 连接） | 应用自身是否死锁/僵死？(JVM 状态) |
| **关键参数** | `initialDelaySeconds` 需覆盖依赖初始化时间 | `initialDelaySeconds` 需覆盖完整启动时间，不能太小 |

**我的项目中的配置（[deployment.yaml:57-69](infrastructure/helm-charts/charts/user-service/templates/deployment.yaml)）：**
```yaml
readinessProbe:
  httpGet:
    path: /actuator/health
    port: 8081
  initialDelaySeconds: 30        # 30 秒后才检查，给数据库连接时间
  periodSeconds: 10

livenessProbe:
  httpGet:
    path: /actuator/health
    port: 8081
  initialDelaySeconds: 300       # 5 分钟！Spring Boot 启动 + JVM 预热
  periodSeconds: 15
```

**常见坑：**
- liveness `initialDelaySeconds` 设太小 → Pod 还没启动完就被杀 → CrashLoopBackOff
- Readiness 没检查外部依赖 → Pod Ready 了但 DB 不通 → 5xx
- `failureThreshold` 太小（如 1）→ 偶发抖动导致 Pod 被反复杀

---

### Q5: What's the difference between Readiness and Liveness Probes? How to configure?

| | Readiness | Liveness |
|---|---|---|
| Purpose | Ready for traffic? | Need restart? |
| On failure | Removed from Service | Container killed & recreated |
| Checks | External deps? (DB, Redis, MQ) | App healthy? (deadlocks, stuck) |

In my project: readiness `30s` delay (DB conn), liveness `300s` delay (JVM startup + warmup). Never set liveness too short — causes CrashLoopBackOff.

---

### Q6: HPA（Horizontal Pod Autoscaler）怎么工作？你配过吗？

**答案：**

**公式：** `desiredReplicas = ceil(currentReplicas × currentMetricValue / desiredMetricValue)`

例如：2 个 Pod，CPU 90%，目标 70% → `ceil(2 × 90/70)` = `ceil(2.57)` = 3 个 Pod

**关键配置：**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    kind: Deployment
    name: user-service
  minReplicas: 2            # 最少 2 个（高可用）
  maxReplicas: 5            # 最多 5 个
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300    # 缩容前等 5 分钟（防止抖动）
      policies:
      - type: Percent
        value: 50                        # 每次最多缩 50%
    scaleUp:
      stabilizationWindowSeconds: 0      # 扩容立刻生效
      policies:
      - type: Percent
        value: 100                       # 每次最多翻倍
```

**配合 PDB（PodDisruptionBudget）防止服务中断：**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 1          # 任何时候至少 1 个 Pod 在线
  selector:
    matchLabels:
      app: user-service
```

**我的简历中的实践：** HPA 配置了 2x~5x 弹性伸缩，CPU 70% 触发扩容，配合 PodAntiAffinity 让 Pod 分布在不同 AZ。

---

### Q6: How does HPA work? Have you configured it?

**Formula:** `desiredReplicas = ceil(currentReplicas × current / target)`. Uses `stabilizationWindowSeconds` to prevent flapping, `behavior.policies` to control velocity. Combined with PDB `minAvailable: 1` for availability.

---

### Q7: 什么是 VirtualService？在你的项目中有用到吗？

**答案：**

VirtualService 是 Istio Service Mesh 的流量管理资源，它运行在 L7（应用层），可以按权重、路径、Header 等规则分发流量。

**核心能力：**
1. **金丝雀发布（Canary）** — weight: 5（5% 流量到新版本）
2. **A/B 测试** — 按 Header 分发（如 `user-agent: mobile` → v2）
3. **熔断/超时** — HTTP timeout、retry、circuit breaker

**配置示例：**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: order-service-vs
spec:
  hosts:
  - order-service
  http:
  - match:
    - headers:
        version:
          exact: "v2"
    route:
    - destination:
        host: order-service
        subset: v2
  - route:                         # 默认路由
    - destination:
        host: order-service
        subset: v1
      weight: 95
    - destination:
        host: order-service
        subset: v2
      weight: 5                    # 5% 流量到新版
```

**在我简历中的实践：** 基于 Istio 实现 Canary Deployment——Jenkins Groovy 脚本通过 `kubectl patch virtualservice` 动态调整 weight：5% → 25% → 50% → 100%，配合 CloudWatch 监控自动回滚。

**SAP Kyma 环境下**，会在 GitOps 仓库中为每个 Service 配 VirtualService，实现多区域流量的精细化管理。

---

### Q7: What is a VirtualService? Have you used it?

VirtualService is Istio's L7 traffic management resource — routes by weight, path, or headers. Used for Canary deployments (gradually increase weight from 5% to 100%), A/B testing, and circuit breaking. I used it at HSBC for Canary Deployment with dynamic weight adjustment via Jenkins Groovy + CloudWatch monitoring for auto-rollback.

---

### Q8: Pod 优雅停机（Graceful Shutdown）怎么实现？

**答案：**

**三段式配置——Spring Boot + K8s + Istio 配合：**

**1. Spring Boot 层面：**
```yaml
spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s    # 最多 30 秒处理完在途请求
server:
  shutdown: graceful                   # 拒绝新请求，完成旧请求
```

**2. K8s Deployment 层面：**
```yaml
spec:
  terminationGracePeriodSeconds: 45    # k8s 最多等你 45 秒
  containers:
  - name: app
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "curl -X POST localhost:8080/actuator/shutdown && sleep 5"]
```

**3. 时间关系（关键理解）：**
```
terminationGracePeriodSeconds = 45s
├── preStop 执行 (~6s: curl shutdown + sleep 5)
├── SIGTERM → 主容器 → Spring graceful shutdown (最多 30s)
├── SIGTERM → Istio sidecar → 排空剩余请求
└── 45s 到期 → 仍未退出 → SIGKILL（强制杀）
```

**面试加分：** 为什么要 `sleep 5`？因为 Istio sidecar 需要一点时间把自己从 Envoy 路由表里摘掉，避免新流量还发给这个即将关闭的 Pod。

---

### Q8: How to implement Pod Graceful Shutdown?

Three-layer orchestration: Spring Boot `server.shutdown=graceful` + K8s preStop hook (`/actuator/shutdown` + `sleep 5` for Istio sidecar draining) + `terminationGracePeriodSeconds: 45` > preStop + Spring timeout. Always `sleep 5` after shutdown to let Istio sidecar drain from Envoy routing table.

---

## 二、Helm Chart 实操 / Helm Hands-on

### Q9: Helm 怎么部署一个应用？你项目里用什么命令？

**答案：**

**我项目里实际用的命令（[deploy-k3s.sh:51-65](scripts/deploy-k3s.sh)）：**
```bash
sudo helm upgrade --install smart-invest . \
  --namespace smart-invest --create-namespace \
  --set user-service.image.tag=v1 \
  --set fund-service.image.tag=v1 \
  --set secrets.dbPassword='bG9jYWxkZXYtb25seQ==' \
  --wait --timeout 300s
```

**关键参数讲解：**
| 参数 | 说明 |
|------|------|
| `upgrade --install` | 如果 release 不存在就安装，存在就升级（面试高频考点！） |
| `--namespace smart-invest --create-namespace` | 指定 namespace，不存在则创建 |
| `--set key=value` | 覆盖 values.yaml 中的值 |
| `-f values-prod.yaml` | 指定额外的 values 文件（可多个） |
| `--wait` | 等待所有 Pod 就绪后才返回（配合 CI/CD 使用） |
| `--timeout` | 超时时间，超时则标记失败 |

**面试官可能追问：** 如果 `helm upgrade` 报 "release not found" 怎么办？
→ 用 `--install`，即 `helm upgrade --install <release> <chart>`，这个组合命令是工业标准。

---

### Q9: How to deploy an app with Helm? What command do you use in your project?

**My actual deploy command:**
```bash
sudo helm upgrade --install smart-invest . \
  --namespace smart-invest --create-namespace \
  --set user-service.image.tag=v1 \
  --wait --timeout 300s
```

`--install` is the key — it auto-installs if the release doesn't exist, upgrades if it does. This is the industry standard approach. `--wait` blocks until Pods are Ready (avoids CI green but K8s red).

---

### Q10: Helm 应用出问题需要回滚，有哪些步骤？

**答案：**

**Step 1: 查看当前 release 状态**
```bash
helm status smart-invest -n smart-invest
```
可以看到当前部署的版本号（revision）、状态、和部署时间。

**Step 2: 查看历史版本**
```bash
helm history smart-invest -n smart-invest
```
输出示例：
```
REVISION  UPDATED                  STATUS          CHART               DESCRIPTION
1         Mon Aug  4 10:00:00     deployed        smart-invest-0.1.0  Install complete
2         Mon Aug  4 14:00:00     deployed        smart-invest-0.1.0  Upgrade complete
3         Mon Aug  4 18:00:00     failed          smart-invest-0.1.0  Upgrade failed
4         Tue Aug  5 09:00:00     deployed        smart-invest-0.1.0  Upgrade complete
```
STATUS 为 `deployed` 的就是可用版本，`failed` 的说明那次部署有问题。

**Step 3: 回滚到指定版本**
```bash
# 回滚到上一个版本
helm rollback smart-invest -n smart-invest

# 回滚到指定版本（例如回滚到第 2 次部署）
helm rollback smart-invest 2 -n smart-invest
```

**Step 4: 验证回滚结果**
```bash
helm status smart-invest -n smart-invest
kubectl get pods -n smart-invest
```

**面试加分：** 除了 `helm rollback`，你还可以用 `kubectl rollout undo` 来回滚 Deployment：
```bash
kubectl rollout undo deployment/user-service -n smart-invest
kubectl rollout undo deployment/user-service -n smart-invest --to-revision=2
```

两者的区别：
- `helm rollback`：回滚整个 Helm release（所有服务一起回滚）
- `kubectl rollout undo`：单个 Deployment 回滚（更精细）

---

### Q10: Steps to rollback a Helm application?

**Step 1:** `helm status <release> -n <ns>` — see current state  
**Step 2:** `helm history <release> -n <ns>` — find a `deployed` revision number  
**Step 3:** `helm rollback <release> <revision> -n <ns>` — rollback  
**Step 4:** Verify: `helm status` + `kubectl get pods`

Bonus: `kubectl rollout undo deployment/<name>` for per-Deployment rollback (more granular).

---

### Q11: Helm Chart 的基本结构是什么？你的项目里是怎么组织的？

**答案：**

**标准 Helm Chart 目录结构：**
```
my-chart/
├── Chart.yaml              # chart 元数据：名称、版本、依赖
├── values.yaml             # 默认配置值
├── templates/              # K8s 资源模板（Go template 语法）
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── hpa.yaml
│   └── _helpers.tpl        # 模板辅助函数
└── charts/                 # 子 chart（通过 dependencies 自动下载）
    └── sub-chart-0.1.0.tgz
```

**我的项目中的结构（[helm-charts/](infrastructure/helm-charts/)）：**
```
helm-charts/
├── charts/                             # 每个微服务一个独立chart
│   ├── user-service/
│   │   ├── Chart.yaml                  # name: user-service
│   │   ├── values.yaml                 # 端口 8081, 副本数, 资源限制, 探针配置
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── deployment.yaml
│   │       └── service.yaml
│   ├── fund-service/                   # 同上
│   ├── order-service/
│   ├── api-gateway/
│   ├── notification-worker/
│   ├── frontend/
│   └── rabbitmq/
└── umbrella/                           # 聚合 chart（Umbrella Chart 模式）
    ├── Chart.yaml                      # 7 个子 chart 通过 file:// 依赖引用
    ├── values.yaml                     # 全局配置 + 各子chart覆盖值
    ├── templates/
    │   ├── ingress.yaml                # 共享 Ingress
    │   └── secret.yaml                 # 共享 Secret
    └── charts/                         # helm dependency build 产生的 .tgz
```

**Umbrella Chart 模式的好处：**
- 每个服务独立打包、独立版本、独立回滚
- 一条命令 `helm install smart-invest` 部署整套系统
- 也可以单独 `helm upgrade user-service` 只更新一个服务

**我的 [Chart.yaml](infrastructure/helm-charts/umbrella/Chart.yaml) 中的 dependencies：**
```yaml
dependencies:
  - name: user-service
    version: 0.1.0
    repository: "file://../charts/user-service"
  - name: fund-service
    version: 0.1.0
    repository: "file://../charts/fund-service"
  # ... 共 7 个子 chart
```

---

### Q11: What's the structure of a Helm Chart? How did you organize yours?

Standard: `Chart.yaml` + `values.yaml` + `templates/` (deployment.yaml, service.yaml, hpa.yaml, _helpers.tpl).

My project uses **Umbrella Chart pattern**: each microservice has its own independent chart under `charts/`, and `umbrella/Chart.yaml` declares them as `file://` dependencies. This gives independent versioning + rollback per service, but also one-command full-system deploy.

---

### Q12: Helm Values 级联（Values Cascade）怎么工作的？

**答案：**

**覆盖优先级（从低到高）：**
```
1. 子 chart 内置 values.yaml        （最低优先级，默认值）
2. 父 chart values.yaml 的子chart段  （我项目中的 umbrella/values.yaml）
3. helm install -f custom.yaml       （命令行指定文件，可多个，后覆盖前）
4. helm install --set key=value      （命令行设置，最高优先级！）
```

**举个例子——user-service 的镜像 tag 最终值由谁决定：**
```
1. charts/user-service/values.yaml   → image.tag: latest
2. umbrella/values.yaml               → user-service.image.tag: v1  （覆盖 latest）
3. helm upgrade --install ... --set user-service.image.tag=abc123
                                       → 最终 tag = abc123（最高优先级）
```

**在多区域场景（SAP 项目）：**
```
values.yaml          ← 公共基础配置
values-us20.yaml     ← US20 覆盖：域名、副本数
values-eu20.yaml     ← EU20 覆盖：域名、副本数
values-in30.yaml     ← IN30 覆盖：域名、副本数
```
每个区域的 values 文件只覆盖差异部分，基础 chart 保持统一。新区域接入只需新建一个 values 文件。

---

### Q12: How does the Helm Values Cascade work?

Priority (low→high): subchart defaults → parent values → `-f` file overrides → `--set` overrides.

In my project, `umbrella/values.yaml` overrides each subchart's tag and replica count. In SAP's multi-region scenario, `values-us20.yaml` / `values-eu20.yaml` each override only the differences (domain, replicas, feature flags), keeping the base chart unified.

---

### Q13: `helm dependency build` 和 `helm dependency update` 有什么区别？

**答案：**

| 命令 | 作用 |
|------|------|
| `helm dependency update` | 下载依赖并更新 `Chart.lock`（锁定文件） |
| `helm dependency build` | 仅从 `Chart.lock` 重新下载依赖（不更新 lock） |

**实际使用：**
```bash
# 首次或 Chart.yaml 改动后：更新依赖 + lock
helm dependency update ./umbrella

# CI/CD 环境：只用 lock 文件，保证可重复构建
helm dependency build ./umbrella
```

我的 [cd-k3s.yml:108](.github/workflows/cd-k3s.yml) 中 CI pipeline 用的是 `helm dependency build` 。

---

### Q13: What's the difference between `helm dependency build` and `helm dependency update`?

`update` downloads deps and regenerates `Chart.lock`. `build` only downloads from the existing `Chart.lock` (reproducible, preferred in CI/CD). My CI pipeline uses `build`.

---

## 三、Jenkins & CI/CD Pipeline / Jenkins & CI/CD

### Q14: Jenkins Pipeline 有哪两种模式？区别是什么？

**答案：**

**Declarative Pipeline（声明式）vs Scripted Pipeline（脚本式）**

| | Declarative | Scripted |
|---|---|---|
| 语法 | 约束 DSL，必须在 `pipeline {}` 内 | 自由 Groovy，在 `node {}` 内 |
| 报错时机 | **解析时**就报错（更安全） | **运行时**才报错 |
| 代码复用 | 需用 `script {}` 块写逻辑 | 原生支持 Groovy 语法 |
| 学习曲线 | 低（适合标准化流水线） | 高（需要 Groovy 知识） |
| 蓝海视图 | stage 自动展示 | 需手动标记 |

**Declarative 示例（更有工业感）：**
```groovy
pipeline {
    agent any
    parameters {
        string(name: 'ENV', defaultValue: 'dev', description: '部署环境')
        string(name: 'IMAGE_TAG', defaultValue: 'latest', description: '镜像版本')
    }
    environment {
        REGISTRY = 'gongchengship'
    }
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Build') {
            steps { sh 'mvn -B clean package -DskipTests' }
        }
        stage('Sonar Scan') {
            steps { sh 'mvn sonar:sonar' }
        }
        stage('Docker Build & Push') {
            steps {
                sh 'docker build -t ${REGISTRY}/app:${IMAGE_TAG} .'
                sh 'docker push ${REGISTRY}/app:${IMAGE_TAG}'
            }
        }
        stage('Deploy') {
            when { expression { params.ENV == 'prd' } }   // 只生产环境运行
            steps {
                sh 'helm upgrade --install app ./chart -n prod --set image.tag=${IMAGE_TAG}'
            }
        }
    }
    post {
        always   { emailext body: 'Build finished', subject: "${env.JOB_NAME}", to: 'team@example.com' }
        failure  { emailext body: 'Build FAILED', subject: "FAILED: ${env.JOB_NAME}", to: 'team@example.com' }
        success  { emailext body: 'Build succeeded', subject: "OK: ${env.JOB_NAME}", to: 'team@example.com' }
    }
}
```

**面试要点：** 面试官可能会追问 "你项目里用了哪种？为什么？"
→ 我在 HSBC 项目里用的是 **Declarative** + **Shared Library** 的组合：pipeline 结构是 Declarative 保证标准，自定义 step 逻辑放 Shared Library（Groovy 脚本）保证复用。

---

### Q14: What are the two modes of Jenkins Pipeline? What's the difference?

**Declarative** (constrained DSL, fails at parse time, better for standardization) vs **Scripted** (flexible Groovy, fails at runtime, better for complex logic). I used Declarative + Shared Library at HSBC — Declarative for structure, Shared Library for reusable steps.

---

### Q15: 什么是 Jenkins Shared Library？你在项目中怎么用的？

**答案：**

**Shared Library** 是把可复用的 Pipeline 代码（Groovy）抽到一个独立的 Git 仓库，供所有项目的 Pipeline 引用。

**我在 HSBC 的实践：**

1. 在现有 stage（git-clone、maven-build、push-to-nexus）基础上，增加了 Sonar Scan、IQ Scan、Checkmarx Scan、docker-build、deploy-by-ansible-core、告警抑制、JMeter 测试等 stage
2. 封装为 Shared Library，开发者只需写一个 JSON 文件声明式调用
3. 参数化支持多环境（DEV/UAT/PRD），开发团队不用改 Pipeline 代码

**Shared Library 目录结构：**
```
jenkins-shared-library/
├── vars/
│   ├── mavenBuild.groovy       # 全局变量/函数
│   ├── dockerBuild.groovy
│   ├── helmDeploy.groovy
│   └── sonarScan.groovy
└── src/
    └── com/acme/
        └── Notifier.groovy     # 复杂工具类
```

**调用方式：**
```groovy
@Library('shared-lib@v1.2') _    // 引入 Shared Library

pipeline {
    stages {
        stage('Build')   { steps { mavenBuild('java21') } }
        stage('Sonar')   { steps { sonarScan('my-project') } }
        stage('Deploy')  { steps { helmDeploy('smart-invest', 'dev') } }
    }
}
```

**核心价值：** 安全团队要求加新合规扫描 → 只需改 Shared Library 一处 → 所有项目自动生效。

---

### Q15: What is Jenkins Shared Library? How did you use it?

A separate Git repo housing reusable Groovy pipeline logic. At HSBC, I built one with stages like mavenBuild, sonarScan, dockerBuild, helmDeploy — developers just invoked them declaratively. When security mandated a new scan, one change in the library → all projects got it.

---

### Q16: 你的 CI/CD Pipeline 是怎么设计的？结合你的 GitHub Actions 说说

**答案：**

**我的 smart-invest 项目中有两套 Pipeline：**

**1. CI Pipeline（[ci.yml](.github/workflows/ci.yml)）— 代码质量门禁：**
```
Push/PR → Backend Build & Test (Maven) + Frontend Build (npm)
         + Terraform Validate
```
- 后端：`mvn -B clean verify`（编译 + 单元测试），上传 test reports 为 artifact
- 前端：`npm ci` → `npm run build`（类型检查）
- Terraform：`terraform init` + `terraform validate`（IaC 语法验证）

**2. CD Pipeline（[cd-k3s.yml](.github/workflows/cd-k3s.yml)）— 部署到 K3S：**
```
Manual Trigger → Checkout → Setup Java 21 → Maven Build (skipTests)
                → Setup Node 22 → npm Build
                → Login Docker Hub
                → Build & Push 6 images (user/fund/order/notification/api-gateway + frontend)
                → SSH to ASUS Server
                → helm upgrade --install smart-invest . --namespace smart-invest --wait
                → Verify: kubectl get pods + rollout status
```

**HSBC 项目的更完整版本（SIT → UAT → PRD）：**
```
PR → CIT: Unit Test + SonarQube + 最小镜像构建
Merge → SIT: 完整镜像构建 + 集成测试
Manual Approve → UAT: UAT 部署 + 性能测试
Manual Approve → PRD: 生产部署（单独 Pipeline + 审批）
```

**面试官可能追问："你的 Pipeline 是怎么支持多环境的？"**
→ 通过 values 文件分层（values-dev.yaml / values-uat.yaml / values-prd.yaml），部署时用 `-f` 选择对应环境。

---

### Q16: How is your CI/CD Pipeline designed? Explain using your GitHub Actions.

**CI** (ci.yml): Maven verify + npm build + Terraform validate — quality gate on every PR.
**CD** (cd-k3s.yml): Maven build → Docker build & push (6 images) → SSH → `helm upgrade --install smart-invest . -n smart-invest --wait` → verify pods.
At HSBC: PR → CIT (SonarQube + unit test) → Merge → SIT → manual approve → UAT → PRD with separate release pipeline. Multi-env via values-dev/uat/prd.yaml cascade.

---

### Q17: 什么是 Single-Trunk 模式？和 GitFlow 有什么区别？

**答案：**

**Single-Trunk** 是所有开发者直接向一个主干分支 commit / 提 PR 的协作模式。

| | Single-Trunk | GitFlow |
|---|---|---|
| 分支数 | 极少（基本上只有 main） | 多（main/develop/feature/release/hotfix） |
| 合并频率 | 每天多次 | 每个 release 一次 |
| 冲突概率 | 低（小步快跑） | 高（分支存活时间长） |
| CI/CD 复杂度 | 1 条主流水线 | 多分支多条流水线 |
| 发布控制 | Feature Flag + 条件部署 | 分支隔离 |

**SAP 项目实践（你朋友的工作场景）：**
- 单主干 Azure DevOps Pipeline：所有代码 → main → 自动 CIT → SIT → UAT deploy → NFR deploy
- 多区域通过 feature flag + values 级联区分，**不是代码分支**
- 每个区域一个 values 文件：values-us20.yaml, values-eu20.yaml, values-in30.yaml

---

### Q17: What is Single-Trunk vs GitFlow?

Single-Trunk = one main branch, all devs commit/PR to it, frequent merges, low conflict, simple pipeline. SAP uses it: all code → main → CIT → SIT → UAT → PRD. Multi-region differentiation via values cascade + feature flags, NOT code branches.

---

### Q18: 什么是 CI/CD Pipeline 中的 Change-Aware 增量部署？

**答案：**

**问题：** 一个 GitOps 仓库管理了几百个环境 × namespace 组合，每次 commit 都跑全量部署太慢了，也浪费集群资源。

**方案：Change-Aware Incremental Execution**

**实现思路：**
1. 比较本次 commit 和上一次部署 commit 的文件变更
2. 只部署 "manifests 发生了变化的" 环境 / namespace
3. 未变化的跳过部署阶段

**Helm/Kustomize 的干运行判断：**
```bash
# 生成本次部署的 manifests
helm template ./chart -f values-us20.yaml > /tmp/current.yaml

# 比较和上次部署的差异
diff /tmp/current.yaml /tmp/last-deployed-us20.yaml
if [ $? -eq 0 ]; then
  echo "No changes for US20, skipping..."
  exit 0
fi
```

**SAP 项目实践（你朋友的实际工作）：**
- 在共享 Pipeline 模板库中实现了 per-environment change detection
- 模板级别的 environment-targeting annotation：只有清单确实变化的 landscape 才触发部署
- 这在大规模场景下很关键——几百个 environment × namespace 组合，避免 Pipeline 跑太久

---

### Q18: What is Change-Aware incremental deployment in CI/CD?

Only deploy environments/namespaces whose manifests actually changed between commits. Use `helm template` + `diff` to detect changes. At SAP, my friend implemented this at scale across hundreds of environment × namespace combinations — only changed landscapes trigger the deploy stage.

---

## 四、Docker 与镜像优化 / Docker & Image Optimization

### Q19: 什么是 Multi-stage Build？你怎么在你的项目中用的？

**答案：**

**核心思想：** 一个 Dockerfile 多个 FROM 语句，构建阶段用大镜像（含编译工具），运行阶段只复制产物到小镜像。

**典型 Spring Boot Dockerfile：**
```dockerfile
# Stage 1: 构建（用大镜像 Maven + JDK）
FROM maven:3.9-amazoncorretto-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: 运行（只用 JRE，不要 Maven）
FROM amazoncorretto:21-alpine
WORKDIR /app
RUN jlink --add-modules java.base,java.sql,java.naming,java.management \
          --strip-debug --no-man-pages --output /opt/jre-minimal
ENV JAVA_HOME=/opt/jre-minimal
COPY --from=builder /app/target/*.jar app.jar
USER 1001
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**效果：** Build 阶段 ~500MB，Runtime 阶段精简 JRE (~40MB) + jar (~50MB) = **~100MB**。

**为什么要这么搞？**
- 镜像小 → 拉取快 → Pod 启动快
- Build 工具不留在运行时 → 安全风险小（没有 maven/gcc 攻击面）
- 缓存利用好：`mvn dependency:go-offline` 在源码没变时不重复下载

---

### Q19: What is Multi-stage Build? How do you use it?

Multiple FROM in one Dockerfile: build stage (Maven image, ~500MB) → copy only the jar to runtime stage (slim JRE, ~40MB) → final image ~100MB. Smaller image = faster pull = faster Pod startup. No build tools in runtime = smaller attack surface.

---

### Q20: Docker 镜像优化有哪些技巧？

**答案：**

| 技巧 | 效果 |
|------|------|
| **Multi-stage Build** | 最终镜像不含编译工具，体积小 |
| **jlink 定制 JRE** | 只包含需要的 Java 模块（如 base, sql, naming），~40MB |
| **选择 Alpine/Slim 基础镜像** | 比完整 CentOS/Ubuntu 小 10 倍 |
| **.dockerignore** | 排除 node_modules, .git, target（加速构建） |
| **利用构建缓存** | 先 COPY 依赖文件（pom.xml / package.json），后 COPY 源码——依赖不变时不重复安装 |
| **USER 非 root** | `USER 1001`，防止容器逃逸 |
| **合并 RUN 层** | `RUN cmd1 && cmd2` 减少镜像层数 |

---

### Q20: Docker image optimization tips?

Multi-stage build, jlink slim JRE (~40MB), Alpine base images, `.dockerignore`, layer caching (copy deps first, then source), non-root user, merge RUN layers.

---

## 五、云基础设施与 IaC / Cloud & IaC

### Q21: Terraform 的核心工作流程是什么？你怎么用的？

**答案：**

**三个核心命令：**
```
terraform init    → 初始化目录，下载 provider 插件（如 AWS provider）
terraform plan    → 对比 tfstate 和目标配置，输出 diff（要创建/修改/删除什么）
terraform apply   → 执行变更
```

**State 文件（terraform.tfstate）—— 核心概念：**
- 记录 "代码里的资源" ↔ "云上实际资源" 的映射
- 存在远程后端（如 S3 + DynamoDB 锁）实现团队协作
- **绝对不能手动改**，不能进 .gitignore

**我在 HSBC 的实践：**
用 Terraform 写了 AWS 全量基础设施代码——VPC、EKS、Aurora PostgreSQL Multi-AZ、ElastiCache Redis、DocumentDB、Amazon MQ、S3 + CloudFront + WAF、ACM、Route53、KMS、Secrets Manager、IAM + IRSA、AppConfig、Prometheus + Grafana + X-Ray。全部通过 `terraform.tfvars` 按 DEV/UAT/PRD 参数化。

---

### Q21: What's the Terraform core workflow? How did you use it?

`terraform init` → `plan` (diff) → `apply` (execute). State file maps code ↔ cloud resources, stored remotely (S3 + DynamoDB lock). I wrote full AWS infra as Terraform modules — VPC, EKS, Aurora, Redis, MQ, S3, CloudFront, WAF, ACM, Route53, KMS, IAM+IRSA, monitoring — all parameterized by DEV/UAT/PRD via `terraform.tfvars`.

---

### Q22: VPC 三层子网怎么设计？为什么？

**答案：**

```
Internet ─→ [Public Subnet]       ─→ [Private Subnet]      ─→ [Database Subnet]
              NLB / Kong Ingress      EKS Worker Nodes          Aurora / Redis / MQ
              公网可达                仅 NAT Gateway 出公网       无公网访问
              
              SG: allow 443           SG: only from Public      SG: only from Private
                                      (443)                     (5432, 6379)
```

| 层 | 放什么 | 公网 inbound | 出网方式 |
|----|--------|-------------|----------|
| Public | NLB、Kong/Ingress、Bastion | ✓ | Internet Gateway |
| Private | EKS Worker、应用 Pod | ✗ | NAT Gateway |
| Database | Aurora、Redis、MQ | ✗ | 无 |

**安全组遵循最小权限：**
- Public → Private: 仅 443
- Private → Database: 仅 5432 (PG) / 6379 (Redis)
- 禁止 Public → Database 直连
- 禁止 Database → Internet 出网

---

### Q22: How to design a three-tier VPC? Why?

Public (NLB/Kong, internet-facing) → Private (EKS workers, NAT outbound only) → Database (Aurora/Redis/MQ, no internet). Security Groups enforce least privilege: Public→Private 443 only, Private→DB 5432/6379 only, no Public→DB direct, no DB egress.

---

## 六、可观测性 / Observability

### Q23: 可观测性三大支柱是什么？你在项目中怎么做的？

**答案：**

| 支柱 | 回答的问题 | 工具链（我的项目） |
|------|-----------|-------------------|
| **Logging（日志）** | 发生了什么？ | `kubectl logs`, ELK Stack, Cloud Logging |
| **Metrics（指标）** | 系统数值状态如何？ | Prometheus + Grafana, ServiceMonitor CRD |
| **Tracing（追踪）** | 一个请求经过了哪些服务？ | AWS X-Ray, Istio EnvoyFilter |

**我的实践：**

**Metrics — Prometheus + Grafana：**
- [servicemonitor.yaml](infrastructure/monitoring/servicemonitor.yaml)：定义 ServiceMonitor CRD，让 Prometheus 自动从 `/actuator/prometheus` 抓取 JVM 指标
- Istio Telemetry API 开启 service mesh 级指标（请求量、成功率、延迟分布）——无需改业务代码
- Dashboard as Code：Grafana JSON 模板纳入 Git 管理

**Logging：**
- 应用日志 → stdout → K8s 采集 → ELK 索引
- 日志断断续续不连续怎么办？→ 用 `kubectl logs --previous` 看上次崩溃的日志

**Tracing：**
- AWS X-Ray SDK + Istio EnvoyFilter 自动传播 trace-id
- Service Map 可视化调用拓扑和延迟热力图

---

### Q23: What are the Three Pillars of Observability? How did you set them up?

**Logging** (kubectl logs, ELK), **Metrics** (Prometheus + Grafana via ServiceMonitor CRD, Istio Telemetry), **Tracing** (AWS X-Ray + Istio EnvoyFilter). Dashboard as Code: Grafana JSON in Git.

---

## 七、综合场景题 / Scenario-Based Questions

### Q24: 凌晨 3 点 P1 告警——生产服务全 5xx。你怎么处理？

**答案——黄金 10 分钟：**

**0-2 分钟：确认**
- 真故障还是误报？看 Dynatrace / Grafana 确认
- 影响范围？所有 region？所有用户？
- 发通知：Slack / WeCom / 电话升级（看 SOP）

**2-5 分钟：快速定位**
```bash
# 有最近部署吗？—— 最常见的根因
kubectl rollout history deployment/<svc> -n prod
kubectl describe deployment/<svc> -n prod | grep -A10 Events

# Pod 状态
kubectl get pods -n prod | grep -v Running

# 崩溃日志
kubectl logs <pod> -n prod --tail=100 --previous
```

**5-8 分钟：快速恢复（第一原则：先恢复，后找原因！）**
```bash
# 部署引起 → 立即回滚
kubectl rollout undo deployment/<svc> -n prod

# 或 Helm 回滚
helm rollback <release> -n prod
```
- 如果是节点故障 → cordon + drain 节点
- 如果是外部依赖（DB 挂了）→ 切备用端点

**8-10 分钟：升级**
- 自己搞不定 → 升级给资深同事或 EU/US shift
- 写清楚：发生了什么、排查了什么、当前状态

**事后——PIR（Post-Incident Review）：**
- 时间线、根因、修复、预防措施
- 更新告警规则
- 如果是部署引入 → 加强 Canary / 变更审批

**面试核心态度：** 第一反应是 "恢复服务"，不是 "找根因"——面试官要听到这个！

---

### Q24: 3 AM P1 alert — all production services returning 5xx. What do you do?

**Golden 10 minutes:** (0-2) confirm + notify → (2-5) diagnostic (was there a recent deploy? check pods, logs --previous) → (5-8) **recover first** — rollback immediately if deploy-related → (8-10) escalate with clean context. Post-incident: PIR with timeline, root cause, prevention. **Key attitude:** restore service first, root cause second.

---

### Q25: 面试官问："你在前公司 CI/CD 体系中最有成就感的一件事是什么？"

**建议回答（选一个跟你简历匹配的）：**

**选项 1 — Jenkins Shared Library 推广（匹配 HSBC 经验）：**
"在 HSBC 项目，我引入了 Jenkins Shared Library，把每个团队各自写的 Pipeline 变为 JSON 声明式调用，减少 80% Pipeline 代码量。安全团队要求加合规扫描时，改 Shared Library 一处，所有项目自动生效。"

**选项 2 — Canary Deployment 实现（匹配 Istio 经验）：**
"我基于 Istio VirtualService 实现了 Canary Deployment——从 5% → 25% → 50% → 100% 渐进式放量，Jenkins Groovy 脚本动态调整 weight，CloudWatch 监控自动回滚。"

**选项 3 — K3S 全家桶一键部署（匹配 smart-invest 项目）：**
"我为 smart-invest 项目设计了 Umbrella Chart 模式——7 个微服务 + 前端 + RabbitMQ，一条 `helm upgrade --install` 命令部署整套系统。每个服务又可独立升级回滚。"

---

### Q25: "What are you most proud of in your CI/CD work?"

Pick one: (1) Jenkins Shared Library standardization — 80% code reduction, one change affects all projects; (2) Istio Canary Deployment — progressive traffic shift 5%→100% with auto-rollback; (3) Umbrella Chart one-command deploy for a 9-service system.

---

### Q26: 你如何看待 On-Call？有夜班经验吗？

**答案：**

**我的态度：**
- On-Call 是 DevOps 的核心职责——我们写的代码和管的基础设施，就应该我们负责
- 目标是 "响了能快速处理" 和 "逐步减少告警", 不是 "永远不要响"

**我的经验（HSBC 项目）：**
- 参与 On-Call Night Shift 轮值
- 配置了 XMatters 分级告警：P1（电话+短信，10min） / P2（WeCom，30min）
- 按 SOP 处理告警，维护值班日志

**我会怎么改进：**
- 降低告警噪音（调阈值）
- 通过 GitOps 变更追踪（post-renderer annotations）缩短 MTTD
- 建立 Runbook 标准化常见问题处理流程

---

### Q26: Your view on On-Call? Night shift experience?

On-Call is core DevOps responsibility — we own what we build. At HSBC, I did night shift rotation with XMatters tiered alerts (P1: phone+SMS/10min, P2: WeCom/30min) following SOP. I'd improve by: reducing alert noise, GitOps change traceability for faster MTTD, building runbooks.

---

### Q27: 什么是 GitOps？你如何实践？

**答案：**

**GitOps** = Git 仓库是声明式基础设施和应用的 **唯一事实来源（Single Source of Truth）**。

**4 个核心原则：**
1. **声明式**：所有资源以 YAML 存在 Git
2. **版本化**：每次变更是 Git commit，可审计可回滚
3. **自动同步**：Git 变更 → 自动应用到集群
4. **持续协调**：对比期望状态（Git）vs 实际状态（集群），自动修正 drift

**两种实践模式：**
| | Push 模式 | Pull 模式 |
|---|---|---|
| 驱动方 | CI/CD Pipeline（Jenkins/ADO） | GitOps Agent（ArgoCD） |
| 命令 | `kubectl apply` / `helm upgrade` | ArgoCD 自动拉取并同步 |
| 我的项目 | GitHub Actions → SSH → `helm upgrade` | — |

**我的项目是 Push 模式：** [cd-k3s.yml](.github/workflows/cd-k3s.yml) 中 GitHub Actions → SSH 到服务器 → `helm upgrade --install`

---

### Q27: What is GitOps? How do you practice it?

Git as single source of truth for declarative infra + apps. Push mode (my project: GitHub Actions → SSH → helm upgrade) vs Pull mode (ArgoCD auto-sync). Core: declarative YAML, versioned in Git, auto-synced, continuously reconciled.

---

## 附录 / Appendix

### 常用 K8s 排错命令速查 / Common K8s Troubleshooting Commands

```bash
# ===== Pod =====
kubectl get pods -n <ns> -o wide                    # Pod 列表 + 节点 + IP
kubectl describe pod <pod> -n <ns>                   # Pod 详情 + Events（排查首选！）
kubectl logs <pod> -n <ns> --tail=200                # 当前日志
kubectl logs <pod> -n <ns> --previous                # 上一次崩溃日志（面试考点！）
kubectl exec -it <pod> -n <ns> -- /bin/sh            # 进入容器
kubectl top pod <pod> -n <ns>                        # CPU/内存实时用量

# ===== Deployment =====
kubectl describe deployment <deploy> -n <ns>         # 部署详情 + 事件
kubectl rollout history deployment/<deploy> -n <ns>  # 部署历史（回滚前必看）
kubectl rollout undo deployment/<deploy> -n <ns>     # 回滚到上一版本
kubectl rollout restart deployment/<deploy> -n <ns>  # 重启 Pod

# ===== Service =====
kubectl get svc -n <ns>                              # Service 列表
kubectl get endpoints <svc> -n <ns>                  # 后端 Pod（如果 <none> 就是问题！）
kubectl describe svc <svc> -n <ns>                   # Service 详情

# ===== Helm =====
helm list -n <ns>                                     # 所有 release
helm status <release> -n <ns>                        # release 当前状态
helm history <release> -n <ns>                       # 部署历史（回滚前必看）
helm rollback <release> <revision> -n <ns>           # 回滚到指定版本
helm get values <release> -n <ns>                    # 查看当前生效的 values

# ===== 网络 =====
kubectl get ingress -n <ns>                          # Ingress 路由规则
kubectl get networkpolicies -n <ns>                  # 网络策略（可能阻断流量）
kubectl run debug --image=nicolaka/netshoot -it --rm -- /bin/bash  # 临时排查 Pod
# 在 debug Pod 里：
nslookup <svc>.<ns>.svc.cluster.local                # DNS 解析测试
curl -v http://<svc>:<port>/health                   # HTTP 连通测试

# ===== 事件 =====
kubectl get events -n <ns> --sort-by='.lastTimestamp' | tail -50  # 最近事件（按时间排序）

# ===== 节点 =====
kubectl get nodes -o wide                             # 节点列表
kubectl describe node <node>                          # 节点详情（磁盘、内存、条件）
kubectl cordon <node>                                 # 标记节点不可调度
kubectl drain <node> --ignore-daemonsets               # 驱逐节点上所有 Pod
```

---

> **面试核心要点 / Key Interview Takeaways:**
>
> 1. **先恢复，后找根因** — 面试官想听到的第一句话是 "rollback first, debug later"
> 2. **能用 kubectl 命令行描述每一步排查** — 不要只说 "我会查日志"，要说 `kubectl logs <pod> -n <ns> --previous`
> 3. **理解 "为什么"** — 为什么 Canary 而不是 Blue-Green，为什么 values 要级联，为什么 liveness initialDelaySeconds 要 300s
> 4. **体现跨时区协作经验** — 提到如何和 EU/US 班次做干净的上下文交接
> 5. **结合你的真实项目** — smart-invest 部署在 K3S 上，用 GitHub Actions + Helm Umbrella Chart，这些都是实打实的经验
>
> **Key traits interviewers look for:**
> 1. First instinct: restore service, not find root cause
> 2. Can describe troubleshooting with actual kubectl commands
> 3. Understands the "why" behind architectural choices
> 4. Cross-timezone collaboration: clean handoffs to EU/US shifts
> 5. Real project experience: smart-invest on K3S, GitHub Actions CI/CD, Helm Umbrella Chart pattern
