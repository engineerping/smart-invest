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

### Q28: K8s 中如何安全地存储数据库密码？AWS 中如何安全地存储数据库密码？

**答案：**

这是一个**多层纵深防御**的问题。密码安全不是靠一个工具，而是靠一套递进的方案。

---

#### 方案一：K8s 原生 Secret（基础方案，你的项目在用）

**原理：** K8s 将密码以 base64 编码存入 Secret 对象，通过环境变量或 Volume 注入 Pod。

```yaml
# =============================================================================
# 1. 创建 Secret（你的 smart-invest-secrets）
# =============================================================================
# Secret 数据字段的值必须是 base64 编码的
# echo -n 'P@ssw0rd123!' | base64  →  UEBzc3cwcmQxMjMh
# echo -n 'my-jwt-secret-key...' | base64  →  bXktand0LXNlY3JldC1rZXkuLi4=
apiVersion: v1
kind: Secret
metadata:
  name: smart-invest-secrets
  namespace: smart-invest
type: Opaque                       # Opaque = 通用 key-value secret
data:
  SPRING_DATASOURCE_PASSWORD: UEBzc3cwcmQxMjMh     # ← base64 编码后的值，不是明文！
  JWT_SECRET: bXktand0LXNlY3JldC1rZXkuLi4=
---
# =============================================================================
# 2. Deployment 引用 Secret（两种方式任选或组合）
# =============================================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
spec:
  template:
    spec:
      containers:
      - name: user-service
        image: gongchengship/smart-invest-user-service:v1

        # 方式 A：以环境变量注入（你的项目用的方式）
        # 优点：Spring Boot 可以直接用 ${SPRING_DATASOURCE_PASSWORD}
        # 缺点：环境变量对所有能 exec 进容器或看 /proc/<pid>/environ 的人可见
        env:
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: smart-invest-secrets      # 引用上面创建的 Secret 的名字
              key: SPRING_DATASOURCE_PASSWORD # 引用 Secret 中的哪个 key

        # 方式 B：以文件 Volume 挂载（更安全）
        # 优点：内容只存在于内存（tmpfs），不写入容器文件系统
        #       应用可以在运行时读取文件内容
        # 缺点：应用代码需要适配文件读取路径
        volumeMounts:
        - name: db-secret
          mountPath: /etc/secrets/db          # 挂载到这个路径
          readOnly: true                      # 只读挂载

      volumes:
      - name: db-secret
        secret:
          secretName: smart-invest-secrets
          # 文件权限：只允许 owner 读写（最严格）
          defaultMode: 0400                  # r-------- （八进制 400）
```

**K8s Secret 的局限性（面试加分项——展示你知道 base64 不是加密）：**

| 局限 | 说明 |
|------|------|
| **base64 不是加密** | `echo "UEBzc3cwcmQxMjMh" | base64 -d` → 一秒还原明文。任何人都能解码 |
| **etcd 中默认明文存储** | Secret 存入 etcd 时不加密，有 etcd 访问权 = 能看到所有密码 |
| **RBAC 权限可能过宽** | 能 `kubectl get secret` 的人就能拿密码 |
| **Git 中不能存 Secret YAML** | 明文放到 Git 上是安全灾难！ |

---

#### 方案二：K8s Secret + Encryption at Rest（etcd 存储加密）

**原理：** 用 EncryptionConfiguration 让 apiserver 在写入 etcd 前对 Secret 做 AES 加密。这样即使有人拿到了 etcd 的数据文件，也是密文。

```yaml
# /etc/kubernetes/encryption-config.yaml —— 这是 apiserver 的配置
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets              # 只加密 Secret 资源（最佳实践——按需加密，不影响性能）
    providers:
    - aescbc:              # 使用 AES-CBC 加密算法
        keys:
        - name: key1
          secret: <base64-encoded-32-byte-random-key>
    - identity: {}         # 兜底：如果上面的 key 丢了，至少还能读到旧未加密数据
```

```bash
# 检查 etcd 加密是否生效
# 加密前：直接 grep etcd 数据文件能看到明文
sudo ETCDCTL_API=3 etcdctl get /registry/secrets/smart-invest/smart-invest-secrets
# 加密后：返回的是乱码（AES 加密后的密文）
```

**面试要点：** 面试官问「etcd 里的 Secret 是加密的吗？」→ 默认不是！需要显式配置 EncryptionConfiguration。

---

#### 方案三：SealedSecret（安全存入 Git 的 K8s Secret）

**原理：** SealedSecret 是 Bitnami 开源的工具。你用集群的公钥加密 Secret → 产生一个 **密文的 SealedSecret YAML** → 这个密文可以安全放进 Git → 推到集群后，SealedSecret Controller 自动解密并生成真正的 Secret。

```bash
# 1. 安装 SealedSecret Controller（集群只需装一次）
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml

# 2. 本地用 kubeseal CLI 加密
kubectl create secret generic db-password \
  --from-literal=SPRING_DATASOURCE_PASSWORD='P@ssw0rd123!' \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > sealed-db-password.yaml

# 3. sealed-db-password.yaml 是密文，可以安全提交到 Git
cat sealed-db-password.yaml
```

```yaml
# sealed-db-password.yaml —— 这个文件可以安全地放进 Git！
# 它是用集群的公钥加密的，只有集群内的 SealedSecret Controller 能解密
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: db-password                     # 解密后会生成同名 Secret
  namespace: smart-invest
spec:
  encryptedData:
    # 下面这些是 RSA 加密后的密文！没有人能反推明文
    SPRING_DATASOURCE_PASSWORD: AgB4xK8mF3pQ...（几百个字符的密文）
```

```bash
# 4. 部署到集群
kubectl apply -f sealed-db-password.yaml

# 5. SealedSecret Controller 自动：
#    → 用它的私钥解密密文
#    → 生成真正的 K8s Secret（name: db-password）
#    → Pod 正常通过 secretKeyRef 引用，毫无感知

kubectl get secret db-password -n smart-invest
# NAME          TYPE     DATA   AGE
# db-password   Opaque   1      10s
```

**面试要点：** 「你的 Helm chart 里 Secret 的明文密码怎么存到 Git？」→ 不能用明文！用 SealedSecret 加密后再入库。

---

#### 方案四：ExternalSecret（从外部密钥管理器同步到 K8s——你朋友 SAP 项目用的方式）

**原理：** K8s 里不存密码的明文。密码存在 AWS Secrets Manager / HashiCorp Vault 里，ExternalSecret Operator 定期（或事件触发）把外部密码同步为 K8s Secret。

```yaml
# =============================================================================
# Step 1: 在 AWS Secrets Manager 中创建密码（通过 AWS Console 或 CLI）
# =============================================================================
# aws secretsmanager create-secret \
#   --name /smart-invest/prod/database-password \
#   --secret-string '{"SPRING_DATASOURCE_PASSWORD":"P@ssw0rd123!","DB_USERNAME":"smartadmin"}'
#   --region ap-southeast-1
#
# AWS Secrets Manager 自动加密存储 + 自动轮转 + 审计日志

# =============================================================================
# Step 2: ExternalSecret CRD——声明「我要同步哪个外部密钥」
# =============================================================================
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-password-ext
  namespace: smart-invest
spec:
  # 同步间隔：每 1 小时从 AWS Secrets Manager 拉一次最新密码
  refreshInterval: 1h

  # 引用 AWS Secrets Manager 中的密钥
  secretStoreRef:
    name: aws-secretsmanager        # ← 集群级别的 SecretStore
    kind: SecretStore               # SecretStore = 集群级 / ClusterSecretStore = 全局

  # 目标：在 K8s 中创建名为 db-password 的 Secret
  target:
    name: db-password               # 生成的 K8s Secret 名字
    creationPolicy: Owner           # ExternalSecret 拥有这个 K8s Secret 的生命周期

  # 映射关系：AWS Secrets Manager 的 key → K8s Secret 的 key
  data:
  - secretKey: SPRING_DATASOURCE_PASSWORD         # K8s Secret 中的 key 名
    remoteRef:
      key: /smart-invest/prod/database-password   # AWS Secrets Manager 中的 ARN 后缀
      property: SPRING_DATASOURCE_PASSWORD        # JSON 中的哪个字段
---
# =============================================================================
# Step 3: SecretStore——ExternalSecret 的「连接配置」
# =============================================================================
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: smart-invest
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-southeast-1
      auth:
        # 使用 IRSA（IAM Roles for Service Accounts）——AWS 最佳实践
        # Pod 通过其 ServiceAccount 自动获得访问 AWS Secrets Manager 的权限
        # 不需要在 K8s 中存 AWS Access Key/Secret Key！
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
```

**面试要点：** 你朋友 SAP 项目里用 Vault 也是同样的思路——密码存在 Vault 里，K8s 里通过 ExternalSecret 或 Vault Sidecar Injector 同步。进入一个新 region 只需加 Vault path 映射。

---

#### 方案五：Vault Sidecar Injector（运行时注入，密码不落 K8s 磁盘）

**原理：** 不需要 ExternalSecret 预先同步成 K8s Secret。密码在 Pod 启动时由 Vault Agent Sidecar 注入到容器的内存文件系统中，Pod 删除后密码消失，K8s etcd 中不存在任何密码痕迹。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: user-service
  annotations:
    # 启用 Vault Agent 注入——Istio sidecar 也是通过 annotation 注入的！
    vault.hashicorp.com/agent-inject: "true"
    # Vault 角色（对应 Vault 中的 K8s Auth Role）
    vault.hashicorp.com/role: "smart-invest-user-service"
    # 从 Vault path "database/creds/user-service" 拉取密码
    # 注入到容器内文件 /vault/secrets/db-creds
    vault.hashicorp.com/agent-inject-secret-db-creds: "database/creds/user-service"
    # 自定义模板——把 Vault 返回的 JSON 渲染成 Spring Boot 需要的 application.properties 格式
    vault.hashicorp.com/agent-inject-template-db-creds: |
      {{- with secret "database/creds/user-service" }}
      spring.datasource.username={{ .Data.data.username }}
      spring.datasource.password={{ .Data.data.password }}
      {{- end }}
spec:
  containers:
  - name: user-service
    image: gongchengship/smart-invest-user-service:v1
    # 容器中的 Spring Boot 读取 /vault/secrets/db-creds 文件
    # 这个文件由 Vault Agent Sidecar 在 Pod 启动时创建，内容是动态生成的
    # Pod 删除后文件消失，密码从未来过 K8s 的 etcd
```

---

#### AWS 中安全存储密码的完整方案

| 服务 | 全称 | 用途 | 什么时候用 |
|------|------|------|-----------|
| **AWS Secrets Manager** | — | 托管密钥存储 + **自动轮转** | 数据库密码、API Key。支持自动轮转 RDS/Aurora 密码！ |
| **AWS Parameter Store** | SSM Parameter Store | 简单 KV 配置存储 | 非敏感配置或简单的加密字符串。免费 tier 有 10000 个参数 |
| **AWS KMS** | Key Management Service | 加密密钥管理 | 一切加密的基础——Secrets Manager/S3/EBS 都用它提供的密钥 |
| **IRSA** | IAM Roles for Service Accounts | 让 K8s ServiceAccount 映射到 AWS IAM Role | Pod 访问 AWS 服务时的鉴权方式，不需要在 K8s 中存 AWS Access Key |

```bash
# Secrets Manager vs Parameter Store 的选择
#
# Secrets Manager（收费，但有高级功能）：
#   - 自动密码轮转（RDS / Redshift / DocumentDB 原生支持）
#   - 跨区域复制
#   - CloudTrail 审计
#
# Parameter Store（免费 tier 很慷慨）：
#   - SecureString 类型也有 KMS 加密
#   - 但不能自动轮转
#   - 适合：配置项 / 少量加密参数
```

**面试最佳回答套路（从低到高递进）：**

> 「安全的密码存储是个纵深问题。最基础的是 K8s Secret + RBAC 权限控制。进一步需要给 etcd 开 Encryption at Rest 防止数据文件泄露。管理面用 SealedSecret 把密文安全存入 Git，或 ExternalSecret 从 AWS Secrets Manager 同步。在 SAP 项目中我们用 Vault——密码不在 K8s 中落盘，Pod 启动时由 Vault Agent Sidecar 注入内存文件系统。AWS 端所有密钥用 KMS 管理，Pod 通过 IRSA 鉴权获取密码，整个链路没有长期 AK/SK。」

---

### Q28: How to securely store database passwords in K8s? In AWS?

**Answer — layered defense approach:**

| Layer | K8s Solution | AWS Solution |
|-------|-------------|-------------|
| Base | K8s Secret + RBAC | AWS Secrets Manager / Parameter Store (SecureString) |
| Encryption | etcd EncryptionConfiguration (AES-CBC) | AWS KMS (Key Management Service) — all secrets encrypted at rest |
| Git Safety | SealedSecret (encrypted YAML safe for Git) | K8s ExternalSecret + AWS Secrets Manager (sync from external, no plaintext in Git ever) |
| Runtime Injection | Vault Sidecar Injector (in-memory tmpfs, never touches etcd) | IRSA (IAM Roles for Service Accounts — Pods authenticate without long-lived AK/SK) |
| Rotation | ExternalSecret refreshInterval + Vault dynamic secrets | AWS Secrets Manager auto-rotation for RDS/Aurora natively |

```yaml
# SealedSecret —— safe to commit to Git
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: db-password
  namespace: smart-invest
spec:
  encryptedData:
    SPRING_DATASOURCE_PASSWORD: AgB4xK8mF3pQ...  # RSA-encrypted, only cluster can decrypt
```

```yaml
# ExternalSecret —— sync from AWS Secrets Manager into K8s
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-password-ext
spec:
  refreshInterval: 1h                        # Re-sync from AWS every hour
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: db-password                        # Resulting K8s Secret name
  data:
  - secretKey: SPRING_DATASOURCE_PASSWORD
    remoteRef:
      key: /smart-invest/prod/database-password
      property: SPRING_DATASOURCE_PASSWORD
```

**Interview answer pattern:** "It's defense in depth — K8s Secret is the base layer (not encryption per se), then etcd Encryption at Rest, SealedSecret for Git safety, ExternalSecret for external sync, and Vault Sidecar Injector for zero-disk footprint. On AWS side, KMS is the root of trust, and IRSA eliminates long-lived cloud credentials in K8s."

---

### Q29: K8s 领域的 Istio 是什么？给出使用 Istio 的实现代码示例，加上充分的注释。

**答案：**

**Istio**（希腊语「帆 / sail」）是一个 **Service Mesh（服务网格）**。它在每个 Pod 里注入一个 Envoy Sidecar 代理容器，通过 iptables 劫持所有进出流量，在不修改业务代码的前提下统一提供以下能力：

| 能力 | 说明 | 不用 Istio 时的做法 |
|------|------|-------------------|
| **流量管理** | 金丝雀发布、A/B 测试、超时、重试、熔断 | 写 Spring Cloud Gateway / Resilience4j 代码 |
| **安全** | 全网格 mTLS 加密 + 细粒度访问控制 | 每个服务自己配 SSL 证书 |
| **可观测性** | 自动采集 Metrics / Tracing / Logging | 每个服务自己接 Prometheus / Jaeger SDK |

---

#### 完整实战示例：Smart-Invest 项目加 Istio 实现金丝雀发布 + 熔断 + mTLS

**架构总览：**

```
                    ┌─────────────────────────────┐
                    │   Istio Ingress Gateway      │
                    │  （网格边界的"大门"）         │
                    │   监听 80/443                 │
                    └─────────────┬───────────────┘
                                  │ 根据 VirtualService 路由
                    ┌─────────────┼───────────────┐
                    │             │               │
                    ▼             ▼               ▼
            ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
            │order-service │ │user-service  │ │fund-service  │
            │┌────────────┐│ │┌────────────┐│ │┌────────────┐│
            ││ Java App   ││ ││ Java App   ││ ││ Java App   ││
            │└─────┬──────┘│ │└─────┬──────┘│ │└─────┬──────┘│
            │┌─────┴──────┐│ │┌─────┴──────┐│ │┌─────┴──────┐│
            ││Envoy Sdcar ││ ││Envoy Sdcar ││ ││Envoy Sdcar ││
            │└────────────┘│ │└────────────┘│ │└────────────┘│
            └──────────────┘ └──────────────┘ └──────────────┘
              ▲ 自动 mTLS ────┘ ▲ 自动 mTLS ────┘
```

**第一步：安装 Istio 并开启 Sidecar 注入**

```bash
# 1. 安装 Istio（使用 minimal profile，适合 K3S 资源有限的环境）
istioctl install --set profile=minimal -y

# 2. 给 namespace 打 Label——此后这个 namespace 下所有新 Pod 自动注入 Envoy Sidecar
kubectl label namespace smart-invest istio-injection=enabled

# 3. 重新部署应用——新 Pod 自动变成 2 个容器（Java App + Envoy）
helm upgrade --install smart-invest ./umbrella \
  -n smart-invest --create-namespace --wait

# 4. 验证注入成功
kubectl get pods -n smart-invest
# NAME                             READY   STATUS
# user-service-7d4f8c9b6-xk2lm    2/2     Running    ← 2/2！多了 Envoy Sidecar
# order-service-8e5f9d0c7-ym3kn   2/2     Running
```

**第二步：金丝雀发布——新版本 user-service:v2 先拿 5% 流量**

```yaml
# =============================================================================
# 1. DestinationRule —— 定义服务的「子版本」和熔断策略
# =============================================================================
# 作用：把 user-service 的 Pod 按 label 分成 v1 和 v2 两个 subset
#       v1 是当前稳定版本，v2 是你要灰度上线的新版本
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: user-service
  namespace: smart-invest
spec:
  host: user-service                              # 目标 K8s Service 名
  subsets:
  # Subset v1：稳定版 Pod（label version=v1）
  - name: v1
    labels:
      version: v1                                 # 匹配 Pod 的 version label
  # Subset v2：新版 Pod（label version=v2）
  - name: v2
    labels:
      version: v2

  # ===== 全局流量策略 =====
  trafficPolicy:
    # 连接池限制 → 防止某个版本打爆后端资源
    connectionPool:
      tcp:
        maxConnections: 100                       # 最大 TCP 连接数
      http:
        http1MaxPendingRequests: 10               # 排队的最大 HTTP/1.1 请求数
        maxRequestsPerConnection: 5               # 每个连接最多处理 5 个请求（防连接泄漏）

    # 负载均衡算法
    loadBalancer:
      simple: LEAST_CONN                          # 最少连接数（还有 ROUND_ROBIN / RANDOM）

    # ===== 异常检测 = 熔断触发条件（Istio 版的 Circuit Breaker） =====
    outlierDetection:
      consecutive5xxErrors: 5                     # 连续 5 次 5xx 错误 → 触发熔断
      interval: 30s                               # 每 30 秒评估一次
      baseEjectionTime: 60s                       # 熔断持续时间：60 秒内不向该 Pod 发流量
      maxEjectionPercent: 50                      # 最多熔断 50% 的 Pod（保护剩余 Pod 不被打爆）
      minHealthPercent: 30                        # 如果健康 Pod < 30%，整个熔断逻辑暂停（避免全面崩溃）
---
# =============================================================================
# 2. VirtualService —— 金丝雀流量分配规则（核心配置！）
# =============================================================================
# 作用：按条件把流量分发给 v1 或 v2
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: user-service
  namespace: smart-invest
spec:
  hosts:
  - user-service                                  # 拦截发往 user-service 的所有请求

  http:
  # ----- 规则 1：内测用户 Header 匹配 → 100% 走 v2 -----
  # 适用于：QA/PM 想提前验证新版
  - match:
    - headers:
        x-canary:                                 # 自定义 HTTP Header
          exact: "enabled"                        # 请求带 x-canary: enabled → 走 v2
    route:
    - destination:
        host: user-service
        subset: v2                                # 全部发给新版本
      weight: 100

  # ----- 规则 2：默认流量 → 95% v1 + 5% v2（金丝雀）-----
  - route:
    # 95% 流量给稳定版
    - destination:
        host: user-service
        subset: v1
      weight: 95                                  # weight = 流量权重（不是百分比，是相对值）
    # 5% 流量给新版本（金丝雀）
    - destination:
        host: user-service
        subset: v2
      weight: 5

    # ===== 超时控制（Istio 替你做了 Resilience4j @TimeLimiter 的事） =====
    timeout: 10s                                   # 请求超时 10 秒

    # ===== 重试策略（Istio 替你做了 Resilience4j @Retry 的事） =====
    retries:
      attempts: 3                                  # 最多重试 3 次
      perTryTimeout: 2s                            # 每次重试的超时时间
      retryOn: 5xx,connect-failure,refused-stream  # 什么情况触发重试
```

**第三步：mTLS 全网格加密——零代码修改**

```yaml
# =============================================================================
# 3. PeerAuthentication —— 全网格强制 mTLS 加密
# =============================================================================
# 作用：要求 smart-invest namespace 中所有服务间通信都必须双向 TLS
#       你的 Java 代码继续用 http://user-service:8081 就好
#       Istio 自动在传输层加密——应用完全无感
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication                        # Peer = 对等方（服务与服务之间）
metadata:
  name: smart-invest-mtls
  namespace: smart-invest
spec:
  mtls:
    mode: STRICT                                # STRICT = 只接受 mTLS 流量，拒绝任何明文 HTTP
    # 还有一个值是 PERMISSIVE = 同时接受明文和加密（迁移期用）
---
# =============================================================================
# 4. AuthorizationPolicy —— 细粒度访问控制（谁能调谁）
# =============================================================================
# 作用：基于 workload 身份做白名单/黑名单
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: user-service-access
  namespace: smart-invest
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: user-service       # 这条规则用于 user-service
  action: ALLOW                                  # 白名单模式
  rules:
  # 允许来自 order-service 和 api-gateway 的 GET 请求
  - from:
    - source:
        principals:
        - "cluster.local/ns/smart-invest/sa/order-service"  # order-service 的 ServiceAccount
        - "cluster.local/ns/smart-invest/sa/api-gateway"     # api-gateway 的 ServiceAccount
    to:
    - operation:
        methods: ["GET"]                                  # 只允许 GET
        paths: ["/api/users/*"]                           # 只允许这个路径
  # 允许来自 notification-worker 的 POST 请求
  - from:
    - source:
        principals:
        - "cluster.local/ns/smart-invest/sa/notification-worker"
    to:
    - operation:
        methods: ["POST"]
        paths: ["/api/notifications/*"]
```

**第四步：在 CI/CD Pipeline 中动态调整金丝雀比例（Jenkins Groovy）**

```groovy
// =============================================================================
// Jenkins Pipeline 中的金丝雀推进脚本 / Canary Progression Script
// =============================================================================
// 这个 Groovy 脚本在你的 Jenkins Pipeline 中被调用
// 它逐步增大新版本的流量比例，每步都检查监控指标

def canaryProgression(String serviceName, String namespace) {
    def checkIntervalSeconds = 300               // 每 5 分钟检查一次（让新版本充分被观察）
    def stages = [5, 25, 50, 100]               // 金丝雀阶段：5% → 25% → 50% → 100%

    for (int weight in stages) {
        echo ">>> 金丝雀推进: ${serviceName} v2 流量 → ${weight}%"

        // kubectl patch —— 动态修改 VirtualService 的 weight，无需重新部署
        // 原理：kubectl patch 发 HTTP PATCH 给 apiserver → Istio Pilot 检测到变更 →
        //       通过 xDS 协议推送给所有 Envoy Sidecar → Sidecar 立即生效
        sh """
            kubectl patch virtualservice ${serviceName} -n ${namespace} \
              --type='json' \
              -p='[{
                "op": "replace",
                "path": "/spec/http/1/route/0/weight",   # v1 的 weight
                "value": ${100 - weight}
              }, {
                "op": "replace",
                "path": "/spec/http/1/route/1/weight",   # v2 的 weight
                "value": ${weight}
              }]'
        """

        // 等待并观察指标
        sleep(checkIntervalSeconds)

        // 调用监控 API 检查新版本的健康状况
        def errorRate = sh(
            script: """
                curl -s 'http://prometheus:9090/api/v1/query?query=' \\
                  --data-urlencode 'query=sum(rate(istio_requests_total{reporter="source",destination_service_name="${serviceName}",destination_version="v2",response_code!~"2.."}[5m])) / sum(rate(istio_requests_total{reporter="source",destination_service_name="${serviceName}",destination_version="v2"}[5m]))' \\
                | jq '.data.result[0].value[1] | tonumber'
            """,
            returnStdout: true
        ).trim() as double

        if (errorRate > 0.01) {                  // 错误率 > 1% → 自动回滚！
            echo "!!! 错误率过高: ${errorRate} → 自动回滚"
            // 把 v2 的 weight 直接置 0（全部流量回 v1）
            sh """
                kubectl patch virtualservice ${serviceName} -n ${namespace} \
                  --type='json' \
                  -p='[{"op":"replace","path":"/spec/http/1/route/0/weight","value":100},
                      {"op":"replace","path":"/spec/http/1/route/1/weight","value":0}]'
            """
            error("金丝雀发布失败，已自动回滚")
        }

        echo ">>> 阶段 ${weight}% 通过，错误率: ${errorRate}"
    }

    echo ">>> 金丝雀发布完成！v2 现已承载 100% 流量"
}
```

**第五步：可观测性——零代码获得的"免费午餐"**

```yaml
# =============================================================================
# 5. 安装 Kiali + Jaeger + Grafana（Istio 配套可视化工具）
# =============================================================================
# 安装后你立刻获得：
#   - Kiali: 服务拓扑图（哪个服务调了哪个，流量大小，延迟颜色）
#   - Jaeger: 分布式 Trace（一次请求横跨 order→fund→user 的完整链路）
#   - Grafana: 预置的 Istio 监控面板

# Kiali dashboard
# 地址：istioctl dashboard kiali
# 你能看到：
#   order-service ──(15.3 req/s, P99=120ms)──→ user-service(v1) 95%
#                                            └─ user-service(v2)  5%
# 如果 v2 的延迟/错误率高，Kiali 上 v2 节点会变红色！
```

---

#### 面试最佳回答思路

> 「Istio 是一个 Service Mesh。它的核心思想是通过 sidecar 模式把流量治理、安全和可观测性从应用代码中剥离。技术实现上通过 Mutating Admission Webhook 在每个 Pod 里注入 Envoy 代理，用 iptables 劫持流量。VirtualService 控制流量到哪去（按权重/Header/路径路由），DestinationRule 控制到了后怎么处理（熔断、负载均衡、mTLS）。我们项目用它做金丝雀发布——从 5% 到 100% 渐进放量，Jenkins Groovy 脚本动态 patch VirtualService 的 weight，配合 Prometheus 监控，错误率超阈值自动回滚。」

---

### Q29: What is Istio in the K8s ecosystem? Provide detailed code examples with full comments.

**Answer:**

Istio (Greek for "sail") is a **Service Mesh**. It injects an Envoy Sidecar proxy into every Pod via Mutating Admission Webhook, intercepts all traffic with iptables rules, and provides traffic management (Canary, A/B, timeout, retry, circuit breaker), security (automatic mTLS + AuthorizationPolicy), and observability (Metrics/Tracing/Logging) — all with **zero application code changes**.

**Architecture:**
```
Control Plane: istiod (Pilot + Citadel + Galley → one binary since v1.5)
Data Plane: Envoy Sidecar in every Pod (C++ proxy, ~50MB memory overhead)
```

**Core CRDs and their roles:**

| CRD | Purpose | Analogy |
|-----|---------|---------|
| **VirtualService** | "Where does traffic go?" — route by weight/header/path | Nginx `server { location }` |
| **DestinationRule** | "What to do at destination?" — subsets, circuit breaker, load balancing, mTLS settings | Upstream connection pool config |
| **Gateway** | Mesh edge ingress/egress | Nginx listening on :80/:443 |
| **PeerAuthentication** | Enforce mTLS between services | "All communication must be encrypted" |
| **AuthorizationPolicy** | Allow/deny based on workload identity | "Only order-service can call user-service" |

**Key code examples included above:**

1. **DestinationRule** — defines v1/v2 subsets + connection pool limits + outlier detection (circuit breaker with `consecutive5xxErrors: 5`, `baseEjectionTime: 60s`)
2. **VirtualService** — Canary routing: 95% v1 + 5% v2, with `x-canary: enabled` header override for internal testers, timeout 10s, retry 3x on 5xx
3. **PeerAuthentication** — STRICT mTLS for entire namespace
4. **AuthorizationPolicy** — allow only order-service and api-gateway to GET user-service, allow notification-worker to POST
5. **Jenkins Groovy** — automated canary progression 5%→25%→50%→100%, auto-rollback if error rate > 1%

**Interview one-liner:** "Istio gives you AOP for microservice communication — cross-cutting concerns like retry, circuit breaker, mTLS, and tracing happen at the network proxy layer instead of in application code. One VirtualService YAML deploys a Canary release that would otherwise require custom routing code in every service."

---

### Q30: Ansible 的原理是什么？给出使用 Ansible 的实现代码示例，加上充分的注释。

**答案：**

#### Ansible 是什么

**Ansible**（名字来自 Ursula K. Le Guin 科幻小说中一种能超光速通讯的虚构装置）是一个**无 Agent 的 IT 自动化工具**，用 SSH 连接远程机器，执行任务。

**核心特点对比其他工具：**

| 对比维度 | Ansible | Puppet / Chef | Terraform |
|----------|---------|---------------|-----------|
| **架构** | **无 Agent**——SSH 连上去执行 | 每台机器装 Agent | API 调云厂商 |
| **语言** | YAML（Playbook） | 各自的 DSL | HCL |
| **用途** | 配置管理 + 应用部署 + 编排 | 配置管理（保证配置不漂移） | 基础设施即代码（IaC） |
| **状态管理** | 无状态文件——每次执行都事无巨细检查 | 有 Agent 持续运行 | tfstate 文件 |
| **类比** | 一个机器人 SSH 到所有服务器执行你的剧本 | 每台服务器上装一个保安，时刻巡逻 | 云资源的遥控器 |

---

#### Ansible 的核心原理

**Ansible 不装 Agent——它怎么工作？**

```
┌──────────────────────────────────────────────────────────────────┐
│                     Ansible Control Node（你敲命令的机器）         │
│                                                                  │
│  ┌────────────────────┐                                         │
│  │   Playbook (YAML)   │  ← 你写的剧本：「装 JDK 21 → 创建用户    │
│  │   - 目标机器         │     → 部署 jar → 启动服务」              │
│  │   - 任务列表         │                                         │
│  └────────┬───────────┘                                         │
│           │                                                      │
│           ▼                                                      │
│  ┌────────────────────┐                                         │
│  │  Ansible Engine    │                                         │
│  │  1. 解析 Playbook   │                                         │
│  │  2. 生成 Python 脚本 │  ← 把每个 task 翻译成 Python 代码        │
│  │  3. SSH 到目标机器    │                                         │
│  │  4. 把 Python 脚本    │                                         │
│  │     scp 过去          │                                         │
│  │  5. 远程执行 + 收集结果│                                         │
│  └────────┬───────────┘                                         │
│           │                                                      │
└───────────┼──────────────────────────────────────────────────────┘
            │ SSH (你机器上已有的 ~/.ssh/id_rsa)
            │
   ┌────────┴────────┬────────────────┬────────────────┐
   ▼                 ▼                ▼                ▼
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Server 1 │  │ Server 2 │  │ Server 3 │  │ Server 4 │
│ 只需要：  │  │ 只需要：  │  │ 只需要：  │  │ 只需要：  │
│ • SSH     │  │ • SSH     │  │ • SSH     │  │ • SSH     │
│ • Python  │  │ • Python  │  │ • Python  │  │ • Python  │
│ 不需要装   │  │ 不需要装   │  │ 不需要装   │  │ 不需要装   │
│ Agent!   │  │ Agent!   │  │ Agent!   │  │ Agent!   │
└──────────┘  └──────────┘  └──────────┘  └──────────┘
```

**关键原理——Ansible 的幂等性（Idempotency）：**

Ansible 的每个 module 都实现了**幂等**逻辑。例如 `apt: name=openjdk-21-jdk state=present`：

```python
# Ansible 执行时的伪代码逻辑（实际是 Python）
def apt_module(package_name, desired_state):
    current_state = check_if_installed(package_name)  # dpkg -l | grep openjdk-21-jdk

    if current_state == desired_state:
        return {"changed": False, "msg": "already installed"}   # 幂等！什么都不做

    if desired_state == "present":
        run("apt install -y openjdk-21-jdk")
        return {"changed": True, "msg": "installed"}            # 真的安装了

# 这就是为什么同一个 Playbook 可以反复跑——第二次跑所有 task 都是 ok（绿色），不是 changed（黄色）
```

---

#### 完整实战示例：用 Ansible 初始化一台新的 Ubuntu 服务器并部署 smart-invest

**项目目录结构（Ansible 最佳实践）：**

```
ansible-smart-invest/
├── ansible.cfg                    # Ansible 全局配置
├── inventory/
│   ├── production                 # 生产环境机器列表（Inventory）
│   └── staging                    # 测试环境机器列表
├── playbooks/
│   ├── site.yml                   # 主 Playbook（入口）
│   ├── init-server.yml            # 服务器初始化
│   ├── deploy-app.yml             # 部署应用
│   └── canary-release.yml         # 金丝雀发布
├── roles/
│   ├── common/                    # 通用角色：所有服务器都要装的
│   │   ├── tasks/main.yml
│   │   └── handlers/main.yml
│   ├── java/                      # JDK 安装角色
│   │   └── tasks/main.yml
│   ├── docker/                    # Docker 安装角色
│   │   └── tasks/main.yml
│   ├── k3s/                       # K3S 安装角色
│   │   └── tasks/main.yml
│   └── smart-invest/              # 应用部署角色
│       ├── tasks/main.yml
│       ├── templates/             # Jinja2 模板文件
│       │   └── values-override.yaml.j2
│       └── files/                 # 要拷贝到目标机器的静态文件
│           └── helm-charts.tar.gz
└── group_vars/
    ├── all.yml                    # 所有机器的公共变量
    ├── production.yml             # 生产环境变量
    └── staging.yml                # 测试环境变量
```

**文件 1：Inventory（机器清单）**

```yaml
# =============================================================================
# inventory/production —— Ansible 的「机器清单」
# =============================================================================
# 告诉 Ansible 要管理哪些机器、怎么连、怎么分组
all:                                          # all = 所有机器的根分组
  children:                                   # children = 子分组
    k3s_master:                               # 分组 1：K3S Master 节点
      hosts:
        asus-server:                          # 机器别名（host alias）
          ansible_host: 192.168.31.192        # 实际 IP 或域名
          ansible_user: george                # SSH 用户名
          ansible_become: yes                 # 是否使用 sudo 提权
          ansible_become_method: sudo         # 提权方式
          ansible_become_password: "George0"  # sudo 密码（生产环境用 ansible-vault 加密！）
    k3s_worker:                               # 分组 2：K3S Worker 节点（未来扩展）
      hosts:
        worker-1:
          ansible_host: 192.168.31.193
          ansible_user: george
          ansible_become: yes

    k3s_cluster:                              # 逻辑分组：包含 Master + Worker
      children:
        k3s_master:
        k3s_worker:
```

**文件 2：全局变量**

```yaml
# =============================================================================
# group_vars/all.yml —— 所有机器共享的变量
# =============================================================================
# 在 Playbook / Template 中通过 {{ variable_name }} 引用

# ---------- 通用 ----------
timezone: "Asia/Shanghai"

# ---------- Java ----------
java_package: "openjdk-21-jdk-headless"        # 生产用 headless（无 GUI，节省空间）
java_home: "/usr/lib/jvm/java-21-openjdk-arm64"

# ---------- Docker ----------
docker_users:                                   # 哪些用户能用 docker 命令
  - george

# ---------- K3S ----------
k3s_version: "v1.28.4+k3s2"                   # 锁定版本（不用 latest——防止意外升级）
k3s_token: "{{ vault_k3s_token }}"             # 引用 ansible-vault 加密的变量
k3s_tls_san:
  - "192.168.31.192"
  - "asus-server.local"

# ---------- smart-invest 应用 ----------
smart_invest_namespace: "smart-invest"
smart_invest_release_name: "smart-invest"
smart_invest_image_registry: "gongchengship"
smart_invest_chart_path: "/opt/smart-invest/helm-charts/umbrella"
```

**文件 3：Ansible 全局配置**

```ini
# =============================================================================
# ansible.cfg —— Ansible 的全局行为配置
# =============================================================================
# 可以放在项目根目录或 /etc/ansible/ansible.cfg
[defaults]
# inventory 文件路径
inventory = ./inventory/production

# 并发执行的任务数（Controls how many hosts to configure in parallel）
forks = 5

# SSH 连接复用（显著加速——避免每次 task 都重新 SSH 握手）
pipelining = True

# 输出格式：可读的而非 JSON
stdout_callback = yaml

# 角色目录
roles_path = ./roles

# 不使用 cowsay（彩蛋——默认会在输出里随机显示一头牛: " _____ < Moo! >"）
nocows = True

# 私钥
private_key_file = ~/.ssh/id_ed25519

# 不检查 host key（首次连接不会卡在确认提示）
host_key_checking = False

[ssh_connection]
# SSH 参数
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

**文件 4：主 Playbook（入口）**

```yaml
# =============================================================================
# playbooks/site.yml —— 主 Playbook（唯一的执行入口）
# =============================================================================
# 用法：ansible-playbook playbooks/site.yml
#       ansible-playbook playbooks/site.yml --tags "deploy"    # 只跑 deploy
#       ansible-playbook playbooks/site.yml --limit k3s_master # 只跑 master
#       ansible-playbook playbooks/site.yml --check --diff     # 干跑（dry-run）
---
# ===== Play 1：初始化所有服务器 =====
- name: "初始化所有 K3S 节点：基础环境"         # play 的名字（人类可读）
  hosts: k3s_cluster                          # 目标主机组（来自 inventory）
  gather_facts: yes                           # 先收集目标机器的系统信息（OS/CPU/内存/IP）
  roles:
    - common                                  # 角色：装常用工具、配置时区、SSH 加固
    - java                                    # 角色：装 JDK 21
    - docker                                  # 角色：装 Docker + 配置用户组

# ===== Play 2：安装 K3S Master =====
- name: "安装 K3S Master 节点"
  hosts: k3s_master
  roles:
    - k3s                                     # 角色：装 K3S + 等 Ready

# ===== Play 3：部署 smart-invest 应用到 K3S =====
- name: "部署 smart-invest 微服务全家桶"
  hosts: k3s_master
  vars:
    deploy_image_tag: "{{ lookup('env', 'IMAGE_TAG') | default('latest', true) }}"
  roles:
    - smart-invest                            # 角色：上传 Helm chart + helm upgrade --install
```

**文件 5：服务器初始化角色**

```yaml
# =============================================================================
# roles/common/tasks/main.yml —— 服务器基础初始化
# =============================================================================
---
# 任务 1：更新 apt 缓存
# apt = Ansible 内置 module，用于 Debian/Ubuntu 的包管理
# update_cache=yes  → 等价于 apt update
# cache_valid_time  → 3600 秒内如果已更新过，就跳过（幂等性优化）
- name: "更新 apt 软件包索引"
  ansible.builtin.apt:                         # 内置 apt 模块
    update_cache: yes
    cache_valid_time: 3600

# 任务 2：安装常用工具包
# state: present  → 确保这些包已安装（已装就跳过 = 幂等）
- name: "安装服务器常用工具"
  ansible.builtin.apt:
    name:
      - htop                                   # 交互式进程查看器
      - net-tools                              # ifconfig / netstat
      - curl
      - wget
      - vim
      - git
      - jq                                     # JSON 命令行处理（kubectl get -o json | jq）
      - unzip
      - ufw                                    # 防火墙
    state: present
    # absent = 删掉包 / latest = 更新到最新版 / present = 装好了就行

# 任务 3：配置时区
- name: "设置系统时区为 {{ timezone }}"
  ansible.builtin.timezone:                   # 内置时区模块
    name: "{{ timezone }}"                    # 引用 group_vars/all.yml 中的变量

# 任务 4：配置 SSH 安全加固
# template 模块 = 把本地 Jinja2 模板变量替换后，拷贝到远程机器
- name: "应用 SSH 安全配置"
  ansible.builtin.template:
    src: sshd_config.j2                       # 本地模板文件（Jinja2 格式）
    dest: /etc/ssh/sshd_config                # 目标机器上的路径
    owner: root
    group: root
    mode: '0600'                              # 只有 root 可读写
    validate: '/usr/sbin/sshd -t -f %s'       # 应用前先验证！防止配错后 SSH 断掉
  notify: restart sshd                        # 如果文件被修改了 → 通知 handler "restart sshd"

# 任务 5：配置防火墙
- name: "开启 UFW 防火墙"
  community.general.ufw:
    rule: allow                               # allow / deny / reject
    port: "22"
    proto: tcp
  # 你可以在以后的任务中加入：
  # - name: "允许 K3S API Server"
  #   community.general.ufw: { rule: allow, port: "6443", proto: tcp }
```

**文件 6：Handlers（触发器）**

```yaml
# =============================================================================
# roles/common/handlers/main.yml —— 被 notify 触发的动作
# =============================================================================
# Handler 特殊之处：只有当 notify 它的 task 的 changed=true 时才执行
# 而且所有 task 跑完后统一执行（不是立即执行），避免重复重启
---
- name: "重启 SSH 服务"
  ansible.builtin.service:
    name: sshd                                # systemctl 的服务名
    state: restarted
```

**文件 7：K3S 安装角色**

```yaml
# =============================================================================
# roles/k3s/tasks/main.yml —— 安装并配置 K3S
# =============================================================================
---
# 任务 1：下载 K3S 安装脚本
- name: "下载 K3S 安装脚本"
  ansible.builtin.get_url:                    # 类似 wget 的模块
    url: https://get.k3s.io
    dest: /tmp/k3s-install.sh
    mode: '0755'                              # rwxr-xr-x

# 任务 2：安装 K3S
# 只有 K3S 还没装的时候才执行（creates 参数）
# creates: 如果这个文件已经存在 → 跳过（幂等！）
- name: "安装 K3S Master"
  ansible.builtin.shell:                      # shell = 执行任意命令（比 command 更灵活）
    cmd: |
      INSTALL_K3S_VERSION="{{ k3s_version }}"       # 锁定版本
      INSTALL_K3S_EXEC="--tls-san {{ k3s_tls_san | join(',') }}"  # TLS SAN
      /tmp/k3s-install.sh
  args:
    creates: /usr/local/bin/k3s               # 如果 k3s 二进制已存在 → 跳过安装

# 任务 3：等 K3S 就绪
- name: "等待 K3S API Server 就绪"
  ansible.builtin.command: "k3s kubectl get nodes"
  register: k3s_result                        # 把命令输出存到变量 k3s_result
  until: k3s_result.rc == 0                   # 重试直到退出码为 0（成功）
  retries: 30                                 # 最多重试 30 次
  delay: 10                                   # 每次等 10 秒
  changed_when: false                         # 这个 task 永远不是 "changed"

# 任务 4：配置 kubectl（把 K3S 的 kubeconfig 拷到 george 用户下）
- name: "把 kubeconfig 拷贝到用户目录"
  ansible.builtin.copy:
    src: /etc/rancher/k3s/k3s.yaml           # 源（远程机器上）
    dest: /home/george/.kube/config           # 目标
    owner: george
    group: george
    mode: '0600'
    remote_src: yes                           # src 在远程机器上而非本地

# 任务 5：安装 Helm
- name: "下载并安装 Helm"
  ansible.builtin.shell: |
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  args:
    creates: /usr/local/bin/helm
```

**文件 8：应用部署角色（核心）**

```yaml
# =============================================================================
# roles/smart-invest/tasks/main.yml —— Helm 部署 smart-invest
# =============================================================================
---
# 任务 1：创建项目目录
- name: "创建 smart-invest 部署目录"
  ansible.builtin.file:                       # file 模块操作文件属性
    path: /opt/smart-invest
    state: directory                          # 确保是个目录（directory / file / link / absent）
    owner: george
    group: george
    mode: '0755'

# 任务 2：上传 Helm charts 到服务器
# synchronize = rsync 封装（比 copy 快——只传差异！）
- name: "同步 Helm Charts 到服务器"
  ansible.posix.synchronize:
    src: "{{ playbook_dir }}/../infrastructure/helm-charts/"  # 本地路径
    dest: /opt/smart-invest/helm-charts/                      # 远程路径
    # 删除远程有但本地没有的文件（保持完全一致）
    delete: yes
    rsync_opts:
      - "--exclude=.git"
      - "--exclude=*.tgz"

# 任务 3：构建 Helm 依赖
- name: "构建 Helm Chart 依赖"
  ansible.builtin.command:
    cmd: helm dependency build .
    chdir: "{{ smart_invest_chart_path }}"     # 在哪个目录下执行
  register: helm_dep_result                   # 存输出

# 任务 4：从 Values 模板生成环境配置文件
# template: Jinja2 变量替换后写入远程文件
# 你的 group_vars/production.yml 中的变量会被填入 values-override.yaml.j2 模板
- name: "生成环境配置文件"
  ansible.builtin.template:
    src: values-override.yaml.j2              # Jinja2 模板
    dest: /opt/smart-invest/values-override.yaml
    owner: george
    group: george
    mode: '0644'

# 任务 5：Helm 部署（或升级）
- name: "部署 smart-invest（Helm upgrade --install）"
  ansible.builtin.command:
    cmd: >
      helm upgrade --install {{ smart_invest_release_name }} .            # --install = 首次安装也兼容
      --namespace {{ smart_invest_namespace }}
      --create-namespace
      --values /opt/smart-invest/values-override.yaml                     # 环境变量文件
      --set user-service.image.tag={{ deploy_image_tag }}                 # 动态镜像 tag
      --set fund-service.image.tag={{ deploy_image_tag }}
      --set order-service.image.tag={{ deploy_image_tag }}
      --set notification-worker.image.tag={{ deploy_image_tag }}
      --set api-gateway.image.tag={{ deploy_image_tag }}
      --set frontend.image.tag={{ deploy_image_tag }}
      --wait --timeout 300s
    chdir: "{{ smart_invest_chart_path }}"
  register: helm_result

# 任务 6：输出部署结果（方便在 Ansible 输出中看到）
- name: "打印 Helm 部署结果"
  ansible.builtin.debug:
    var: helm_result.stdout_lines

# 任务 7：健康检查——确认所有 Pod Running
- name: "验证所有 Pod 都在运行"
  ansible.builtin.command: "kubectl get pods -n {{ smart_invest_namespace }}"
  register: pod_status
- name: "打印 Pod 状态"
  ansible.builtin.debug:
    var: pod_status.stdout_lines
```

**文件 9：Jinja2 模板示例**

```yaml
# =============================================================================
# roles/smart-invest/templates/values-override.yaml.j2
# =============================================================================
# 这是一个 Jinja2 模板。{{ }} 中的变量在 ansible-playbook 执行时被替换。
# 模板可以在远程服务器上生成不同环境的配置文件，不需要为每个环境维护一份独立的 YAML。

# 全局镜像版本（由 CI/CD 的 IMAGE_TAG 环境变量传入）
global:
  imageTag: "{{ deploy_image_tag }}"              # {{ }} = Jinja2 变量占位符

# Secrets —— 生产密码从 Ansible Vault 加密变量中解密后写入
# 注意：这个文件是运行时生成的，生成后可以立即删除
secrets:
  # lookup('community.hashi_vault.vault_kv2_read', ...) → 从 HashiCorp Vault 动态拉取密码
  dbPassword: "{{ vault_db_password }}"
  jwtSecret: "{{ vault_jwt_secret }}"
  rabbitmqPassword: "{{ vault_rabbitmq_password }}"

# 各服务的副本数——生产环境至少 2 个
{% for svc in ['user-service', 'fund-service', 'order-service'] %}  {# Jinja2 for 循环 #}
{{ svc }}:
  replicaCount: {{ prod_replica_count | default(2) }}  {# | default = 过滤器，有默认值 #}
  image:
    tag: "{{ deploy_image_tag }}"
{% endfor %}                                     {# 循环结束 #}

# api-gateway 是流量入口，需要多副本
api-gateway:
  replicaCount: {{ api_gateway_replicas | default(3) }}
  image:
    tag: "{{ deploy_image_tag }}"

# 特殊服务——notification-worker 只需要 1 个（避免重复消费 MQ）
notification-worker:
  replicaCount: 1
  image:
    tag: "{{ deploy_image_tag }}"
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: "1"
      memory: 512Mi

# 环境差异化配置
{% if env == 'production' %}                     {# Jinja2 条件判断 #}
# 生产环境：HPA 弹性伸缩
user-service:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 70
{% else %}
# 非生产环境：固定副本数，不开 HPA（省钱）
user-service:
  autoscaling:
    enabled: false
{% endif %}
```

**文件 10：金丝雀发布 Playbook**

```yaml
# =============================================================================
# playbooks/canary-release.yml —— 金丝雀发布
# =============================================================================
# 用法：ansible-playbook playbooks/canary-release.yml -e "canary_weight=25"
---
- name: "金丝雀发布——调整 user-service v2 流量为 {{ canary_weight }}%"
  hosts: k3s_master
  vars:
    canary_weight: "{{ canary_weight | default(5) }}"  # 默认 5%，可命令行 -e 覆盖
    v1_weight: "{{ 100 - canary_weight | int }}"        # v1 的流量 = 100 - 金丝雀比例
  tasks:
    # Step 1：调整 VirtualService weight
    - name: "更新 VirtualService 流量权重"
      ansible.builtin.command:
        cmd: |
          kubectl patch virtualservice user-service -n smart-invest \
            --type='json' \
            -p='[
              {"op":"replace","path":"/spec/http/1/route/0/weight","value":{{ v1_weight }}},
              {"op":"replace","path":"/spec/http/1/route/1/weight","value":{{ canary_weight }}}
            ]'

    # Step 2：等几分钟让新版本充分暴露在流量下
    - name: "等待 {{ canary_wait_seconds | default(300) }} 秒——观察金丝雀指标"
      ansible.builtin.pause:
        seconds: "{{ canary_wait_seconds | default(300) }}"

    # Step 3：检查新版本的健康状态
    - name: "查询 Prometheus——v2 的 5xx 错误率"
      ansible.builtin.uri:                       # uri 模块 = curl 的 Ansible 版
        url: "http://prometheus:9090/api/v1/query"
        method: GET
        body_format: form-urlencoded
        body:
          query: |
            sum(rate(istio_requests_total{
              destination_service_name="user-service",
              destination_version="v2",
              response_code=~"5.."
            }[5m]))
            /
            sum(rate(istio_requests_total{
              destination_service_name="user-service",
              destination_version="v2"
            }[5m]))
      register: prometheus_result

    # Step 4：如果错误率超阈值 → 自动回滚
    - name: "自动回滚——v2 错误率过高！"
      ansible.builtin.command:
        cmd: |
          kubectl patch virtualservice user-service -n smart-invest \
            --type='json' \
            -p='[
              {"op":"replace","path":"/spec/http/1/route/0/weight","value":100},
              {"op":"replace","path":"/spec/http/1/route/1/weight","value":0}
            ]'
      when: (prometheus_result.json.data.result[0].value[1] | float) > 0.01
      # when = 条件判断——只在错误率 > 1% 时执行！
```

**文件 11：用 Ansible Vault 加密敏感变量**

```bash
# =============================================================================
# Ansible Vault —— 加密你的密码文件
# =============================================================================

# 1. 创建加密文件
ansible-vault create group_vars/production/vault.yml
# 输入密码 → 打开编辑器 → 写入：
# vault_db_password: "P@ssw0rd123!"
# vault_jwt_secret: "prod-jwt-secret-key-32bytes"
# 保存退出 → 文件自动 AES-256 加密

# 2. 查看加密文件内容（需要密码）
ansible-vault view group_vars/production/vault.yml

# 3. 执行 Playbook 时自动解密
ansible-playbook playbooks/site.yml --ask-vault-pass     # 交互式输入密码
ansible-playbook playbooks/site.yml --vault-password-file ~/.ansible-vault-pass  # 从文件读密码

# 4. CI/CD 中自动化（Jenkins / GitHub Actions）
# 把 vault 密码存在 Jenkins Credentials / GitHub Secrets 中
# Jenkinsfile 中：
#   withCredentials([string(credentialsId: 'ansible-vault-password', variable: 'VAULT_PASS')]) {
#     sh 'ansible-playbook playbooks/site.yml --vault-password-file <(echo ${VAULT_PASS})'
#   }
```

---

#### 面试最佳回答思路

> 「Ansible 是无 Agent 的自动化工具——通过 SSH 连到目标机器，把 YAML Playbook 翻译成 Python 脚本，scp 过去执行。核心优势是不需要在目标机器装 Agent。每个 module 实现幂等逻辑，同一个 Playbook 可以反复安全执行。我们用 Ansible 做服务器初始化（装 JDK/Docker/K3S）、应用 Helm 部署、以及金丝雀发布的流程编排。敏感变量用 Ansible Vault AES-256 加密存储，CI/CD Pipeline 中用 --vault-password-file 解密。」

---

### Q30: What is Ansible's principle? Provide detailed code examples with full comments.

**Answer:**

Ansible is an **agentless IT automation tool** that uses SSH to connect to remote machines, translates YAML Playbooks into Python scripts, copies them over, executes them, and collects results. No agent installation required on target hosts — just SSH and Python.

**Core principles:**

| Principle | Explanation |
|-----------|-------------|
| **Agentless** | Connects via SSH — no agent daemon to install, upgrade, or maintain on target machines |
| **Idempotency** | Every module checks current state before acting. Run the same Playbook 100 times — only the first run actually changes anything |
| **Declarative** | You describe the desired state (`state: present`), Ansible figures out how to get there |
| **Push-based** | Control node initiates the connection (vs Puppet/Chef where agents pull from a master) |

**Architecture:**
```
Playbook (YAML) → Ansible Engine → translates each task into Python script
                                 → SSH + scp to target machine
                                 → execute remotely
                                 → collect results
```

**Execution output colors:**
- **Green** = ok (already in desired state, idempotent — nothing changed)
- **Yellow** = changed (made a modification)
- **Red** = failed (error occurred, execution stopped)

**Key modules used in the example:**

| Module | Purpose | Equivalent |
|--------|---------|------------|
| `ansible.builtin.apt` | Package management | `apt install/update` |
| `ansible.builtin.copy` | Copy files | `scp` |
| `ansible.builtin.template` | Copy + Jinja2 variable substitution | `sed` on steroids |
| `ansible.builtin.command` / `shell` | Execute arbitrary commands | `ssh ... "command"` |
| `ansible.builtin.file` | Manage file/directory attributes | `mkdir` + `chmod` + `chown` |
| `ansible.posix.synchronize` | rsync wrapper | `rsync` |
| `ansible.builtin.get_url` | Download file | `curl` / `wget` |
| `ansible.builtin.debug` | Print variable | `echo` |
| `ansible.builtin.pause` | Wait N seconds | `sleep` |
| `community.general.ufw` | Firewall management | `ufw allow/deny` |
| `ansible.builtin.uri` | HTTP request | `curl` |
| `community.hashi_vault.vault_kv2_read` | Read from HashiCorp Vault | `vault read` |

**Interview one-liner:** "Ansible is an agentless automation tool that uses SSH to push configuration changes. Its Playbooks are declarative YAML — you say `state: present` and Ansible handles the idempotency check. We use it for server provisioning, Helm-based deployments, and canary release orchestration, with Ansible Vault encrypting all secrets at rest with AES-256."

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
