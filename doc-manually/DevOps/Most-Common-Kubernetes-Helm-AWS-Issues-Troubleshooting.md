# Hydsoft DevOps 面试题库——故障排查 & 云平台监控 实战
# Hydsoft DevOps Interview Q&A — Troubleshooting & Cloud Observability

> **岗位**: Hydsoft Technology DevOps Engineer（SAP Kyma / SAP Business Network NextGen）
> **仓库参考**: [smart-invest](/) —— Java Spring Boot 多微服务, Helm Umbrella Chart, K3S/Terraform/AWS/Istio
> **面试期待**: 聚焦 "实际工作中你会怎么排查问题" 而不是背概念——每题都要能讲出命令 + 思路
> **编排**: 按 DevOps 职能领域分章节,每章按最常见→最罕见排序

---

## 目录 / Table of Contents

### Part I: 核心——K8s Pod 诞生流程故障排查
| Q1.1 | ImagePullBackOff | kubelet 拉镜像 |
| Q1.2 | CrashLoopBackOff + exit code 诊断 | 容器崩溃 |
| Q1.3 | Pod Pending / Scheduler 调度失败 | Scheduler |
| Q1.4 | Readiness Probe 失败 / Pod 不 Ready | Readiness Probe |
| Q1.5 | Service 访问不通 / Endpoints 为空 | Endpoints Controller |
| Q1.6 | OOMKilled (exit 137) | Cgroups 内存 Kill |
| Q1.7 | kube-proxy iptables 规则不生效 | kube-proxy |
| Q1.8 | Admission Webhook 拒绝部署 | API Server Admission |

### Part II: Helm 实战
| Q2.1 | `helm upgrade --install` + release not found |
| Q2.2 | Helm 回滚 (rollback / history / status) |
| Q2.3 | Umbrella Chart 结构与 values 级联 |
| Q2.4 | `helm template` 模板渲染调试 |
| Q2.5 | Helm Hook + 部署顺序控制 |
| Q2.6 | Helm 依赖管理 (dependency update) |

### Part III: Docker & 镜像
| Q3.1 | Dockerfile 最佳实践 (multi-stage / non-root) |
| Q3.2 | 镜像体积优化 |
| Q3.3 | 容器启动慢排查 |

### Part IV: CI/CD & Jenkins Pipeline
| Q4.1 | Jenkins Pipeline Declarative vs Scripted |
| Q4.2 | Jenkinsfile stage / step / when / post |
| Q4.3 | Pipeline 失败了怎么排查 |
| Q4.4 | 多分支 Pipeline (Multibranch) |
| Q4.5 | CI/CD 中的安全扫描集成 |

### Part V: Istio Service Mesh
| Q5.1 | VirtualService 流量路由实战 |
| Q5.2 | DestinationRule — 熔断 & 负载均衡 |
| Q5.3 | Sidecar 注入失败排查 |
| Q5.4 | mTLS 工作不正常排查 |
| Q5.5 | Istio vs Resilience4j (Java 面试最爱问) |

### Part VI: 监控 & 可观测性
| Q6.1 | Prometheus + Grafana 架构 & 指标排查 |
| Q6.2 | ServiceMonitor & PodMonitor |
| Q6.3 | CloudWatch / Cloud Logging |
| Q6.4 | 告警规则设计 (Alerting) |
| Q6.5 | Distributed Tracing (Jaeger/Zipkin) |

### Part VII: GitOps & ArgoCD
| Q7.1 | GitOps 核心思想 |
| Q7.2 | ArgoCD Sync 失败排查 |
| Q7.3 | 多环境 GitOps (branches vs overlays) |

### Part VIII: HashiCorp Vault & Secret 管理
| Q8.1 | K8s Secret vs Vault |
| Q8.2 | Vault 集成 Pipeline 的常见问题 |

### Part IX: 网络 & DNS
| Q9.1 | CoreDNS 解析失败排查 |
| Q9.2 | NetworkPolicy 排查 |
| Q9.3 | Ingress 路由不通 |

### Part X: K8s 安全
| Q10.1 | RBAC 排查 (forbidden error) |
| Q10.2 | SecurityContext 与容器安全 |
| Q10.3 | Image Scanning & Supply Chain Security |

### Part XI: Linux & OS
| Q11.1 | 磁盘满了怎么排查 |
| Q11.2 | CPU 高负载排查 |
| Q11.3 | 网络连通性排查 (tcpdump / netstat / ss) |

### Part XII: AWS / Cloud 基础设施
| Q12.1 | VPC 网络设计 & Security Group 排查 |
| Q12.2 | RDS 连接问题排查 |
| Q12.3 | IAM 权限不足排查 |
| Q12.4 | EC2 实例启动失败 (user_data) |

### Part XIII: Terraform IaC
| Q13.1 | Terraform state 管理 |
| Q13.2 | `terraform plan` 报错排查 |
| Q13.3 | Module 设计与依赖管理 |

### Part XIV: 综合场景
| Q14.1 | 线上业务挂了——on-call 完整排查流程 |
| Q14.2 | 多 Region 部署故障诊断 |
| Q14.3 | 零停机滚动更新失败排查 |
| Q14.4 | 数据库密码轮换后服务全部断连 |

---

## Part I: 核心——K8s Pod 诞生流程故障排查
## Part I: Core — Troubleshooting the K8s Pod Birth Flow

*按 Pod 诞生流程的每一步可能卡住的位置排序。面试官最爱从这里切入。*

---

### Q1.1: ImagePullBackOff —— 镜像拉不下来

> **Pod 诞生步骤 6**: kubelet 调用 CRI → registry pull 失败
> **Pod birth step 6**: kubelet calls CRI → registry pull fails

#### 中文

**症状**:
```bash
kubectl get pods -n smart-invest
NAME                     READY   STATUS             RESTARTS   AGE
user-service-7d5f-abc1   0/1     ImagePullBackOff    0          2m
```

**排查**:
```bash
kubectl describe pod <pod> -n smart-invest | tail -15
# Events:
#   Warning  Failed   Failed to pull image "xxx:v99": rpc error: code = NotFound ...
#   Warning  Failed   Error: ErrImagePull
#   Normal   BackOff  Back-off pulling image "xxx:v99"
```

| 原因 | 验证方法 | 解决 |
|------|---------|------|
| tag 写错 / 镜像不存在 | `docker pull gongchengship/smart-invest-user-service:v99` | 修正 `values.yaml` 的 `image.tag` |
| Registry 认证失败 | `kubectl get secrets -n <ns>` 确认 imagePullSecrets | 创建 docker-registry Secret: `kubectl create secret docker-registry ...` |
| 网络不通 (Docker Hub rate limit) | 节点上 `curl -v https://registry-1.docker.io/v2/` | 配置 dockerproxy.net 镜像加速,或配置 Docker Hub 登录 |
| 节点磁盘满 (`no space left`) | `df -h` / `crictl rmi --prune` | 清理旧镜像,扩容节点磁盘 |
| SAP Kyma 上 Registry Secret 未创建 | GitOps 仓库里 namespace 创建模版缺少 imagePullSecrets | 在 GitOps repo 的 namespace provisioning 里补上 Secret 声明 |

**面试金句**:
> "ImagePullBackOff 的本质是 kubelet 无法从 registry 拉取镜像。优先怀疑 tag 不存在——这是最常见的原因。第二步看 imagePullSecrets 是否配好。我们项目因为 K3S 在墙内,用了 dockerproxy.net 做 Docker Hub pull-through cache。"

---

#### English

**Symptom**: Pod stuck in `ImagePullBackOff`.
**Troubleshooting**: `kubectl describe pod <pod>` → check Events.

| Cause | Verify | Fix |
|-------|--------|-----|
| Wrong tag / image not found | `docker pull <image>:<tag>` | Correct `image.tag` in `values.yaml` |
| Registry auth missing (private) | `kubectl get secrets -n <ns>` | `kubectl create secret docker-registry ...` |
| Network unreachable / rate limit | `curl -v https://registry-1.docker.io/v2/` on node | Configure pull-through mirror (dockerproxy.net) or Docker Hub login |
| Node disk full | `df -h`, `crictl rmi --prune` | Clean old images, expand disk |
| SAP Kyma: missing imagePullSecrets | GitOps namespace template | Add Secret to namespace provisioning |

**Key phrase**: *"ImagePullBackOff means kubelet can't pull the image. First suspect: the tag doesn't exist. Second: imagePullSecrets. On K3S behind the GFW, we use dockerproxy.net as a mirror."*

---

### Q1.2: CrashLoopBackOff —— Pod 反复崩溃 (核心题)

> **Pod 诞生步骤 6-7**: 容器启动后进程退出 (exit code ≠ 0)
> **Pod birth steps 6-7**: Container starts, process exits with non-zero

#### 中文

**症状**:
```bash
kubectl get pods -n smart-invest
NAME                     READY   STATUS             RESTARTS   AGE
order-service-5c8-xyz2   0/1     CrashLoopBackOff    7          5m
# RESTARTS 列持续增长 → 说明容器不断被 K8s 杀掉再重启
```

**标准 4 步排查 (面试按这个顺序说)**:

```bash
# 1. 看 Events
kubectl describe pod <pod> -n smart-invest | tail -20
# 找: OOMKilled / Liveness probe failed / BackOff

# 2. 看当前日志
kubectl logs <pod> -n smart-invest --tail=200

# 3. ** 看上次崩溃日志 —— 面试重点! **
kubectl logs <pod> -n smart-invest --previous

# 4. 如果 Pod 起不来进不去 exec,检查 ConfigMap/Secret 引用
kubectl get configmap -n smart-invest
kubectl get secret -n smart-invest
```

**按 exit code 定位**:

| Exit Code | 含义 | 我们项目最常见的情况 |
|-----------|------|-------------------|
| **1** | 应用启动报错 | DB URL 配错 (`postgres-host` 不通)、JWT secret 为空、端口冲突 |
| **137** | OOMKilled (9+128) | 内存超 limit → 详见 Q1.6 |
| **139** | SIGSEGV | JNI/native 层崩 (JVM 极少见) |
| **143** | SIGTERM | 正常终止,但 `terminationGracePeriodSeconds` 太短 |

**常见具体场景**:

```bash
# 场景 A: 数据库连不上 (Spring Boot 最常见)
# 日志: "CommunicationsException: Communications link failure"
# 排查:
kubectl exec -it <pod> -n smart-invest -- nslookup postgres-host  # DNS 通吗?
kubectl get endpoints postgres-host -n smart-invest               # DB Service 有 Endpoint 吗?

# 场景 B: ConfigMap mount 不存在
# Event: "MountVolume.SetUp failed for volume..."
kubectl describe pod <pod> -n smart-invest | grep -A5 "Mount"

# 场景 C: 端口冲突
# 日志: "Address already in use"
kubectl exec -it <pod> -n smart-invest -- netstat -tlnp
```

**我的项目实践**:
- [values.yaml:37-42](infrastructure/helm-charts/charts/user-service/values.yaml) 中 `initialDelaySeconds: 300` 给 JVM 启动时间
- Liveness/Readiness Probe 均指向 `/actuator/health` (Spring Boot Actuator)
- `--previous` 参数是面试官判断你有没有真正在生产环境排查过问题的关键信号

---

#### English

**Symptom**: Pod in `CrashLoopBackOff`, RESTARTS increasing.

**Standard 4-step flow (memorize this order)**:

```bash
# 1. Describe → read Events
kubectl describe pod <pod> -n smart-invest | tail -20

# 2. Current logs
kubectl logs <pod> -n smart-invest --tail=200

# 3. *** PREVIOUS crash logs — THE interview keyword! ***
kubectl logs <pod> -n smart-invest --previous

# 4. If exec is impossible (Pod won't start), check ConfigMap/Secret refs
kubectl get configmap,secret -n smart-invest
```

**Diagnosis by exit code**:

| Exit | Meaning | Most Common Scenarios |
|------|---------|----------------------|
| **1** | App startup error | DB unreachable, JWT secret missing, port conflict |
| **137** | OOMKilled (128+9) | See Q1.6 |
| **139** | SIGSEGV | JNI/native crash (rare for JVM) |
| **143** | SIGTERM | Graceful shutdown too short |

**Key interview signal**: If you mention `kubectl logs --previous`, the interviewer knows you've done real production troubleshooting. This is the single most impactful flag to drop.

---

### Q1.3: Pod 一直 Pending —— Scheduler 调度失败

> **Pod 诞生步骤 5**: Scheduler 的 Filtering 阶段找不到可用节点
> **Pod birth step 5**: Scheduler Filtering finds no suitable node

#### 中文

**症状**:
```bash
kubectl get pods -n smart-invest
NAME                     READY   STATUS    RESTARTS   AGE
fund-service-6d9-abc3    0/1     Pending   0          10m
# Pending 超过几分钟 → 不是正常的等待,是卡住了
```

**排查——读 Events 是 80% 的答案**:
```bash
kubectl describe pod <pod> -n smart-invest | grep -A10 Events
```

| Event 信息 | 含义 | 我们的处理 |
|-----------|------|-----------|
| `0/3 nodes: insufficient cpu` | 节点资源不够 (requests 超出可用) | 减小 `resources.requests` 或扩容节点 |
| `1 node(s) had taint ... that pod didn't tolerate` | 节点有污点且 Pod 没容忍 | 给 Pod 加 `tolerations`,或用 `kubectl taint node <n> key-` 去污 |
| `pod has unbound immediate PersistentVolumeClaims` | PVC 还没绑到 PV | 检查 `kubectl get pvc` — PVC 是 Pending 状态吗? |
| `node(s) had volume node affinity conflict` | PV 的可用区/节点亲和性与 Pod 不匹配 | 检查 PV affinity,或 rebuild PV |
| `didn't match pod's node selector` | nodeSelector 配得太窄 | `kubectl get nodes --show-labels` 查看节点标签 |

**还要查节点的可用资源**:
```bash
kubectl describe node <node> | grep -A5 "Allocated"
kubectl top nodes    # CPU/Memory 实时用量 (需 metrics-server)
```

**面试金句**:
> "Scheduler 的 FailedScheduling Event 已经把失败原因写在脸上了。读完 Event 再去查对应的节点、PV、污点即可。记住 Scheduler 的两阶段: **Filtering** (排除不合格) → **Scoring** (打分选最优)。"

---

#### English

**Symptom**: Pod stuck `Pending` for minutes with no containers created.

**Troubleshooting**: `kubectl describe pod <pod>` → read Events.
The `FailedScheduling` event spells out the reason. Common: insufficient resources, taint/toleration mismatch, PVC not bound, node affinity unsatisfied.

**Key phrase**: *"The Scheduler's FailedScheduling event is self-documenting. Read the message, then check the corresponding node/taint/PV. The Scheduler works in two phases: Filtering (elimination) → Scoring (ranking)."*

---

### Q1.4: Readiness Probe 失败 —— Pod 在 Running 但没 Ready

> **Pod 诞生步骤 7**: kubelet 执行 Readiness Probe 失败
> **Pod birth step 7**: kubelet Readiness Probe fails

#### 中文

**症状**:
```bash
kubectl get pods -n smart-invest
NAME                    READY   STATUS    RESTARTS   AGE
api-gateway-7f8c-abc4   0/1     Running   0          5m
# STATUS=Running ✓ 说明容器活着
# READY=0/1     ✗ 说明没通过健康检查——不能接流量!
```

**排查**:
```bash
kubectl describe pod <pod> -n smart-invest | grep -A3 "Conditions"
#   Ready             False   ReadinessProbeFailed
#   ContainersReady   False   ReadinessProbeFailed
# Events:
#   Warning  Unhealthy  Readiness probe failed: Get "http://10.42.0.15:8081/actuator/health": context deadline exceeded
```

| 原因 | 症状 | 解决 |
|------|------|------|
| **initialDelaySeconds 太短** | JVM 还在启动就被 Probe | 增大到 60-120s (Spring Boot); 我的项目 30s 已足够 |
| **路径错误** | `HTTP probe failed: 404` | 确认 `readinessProbe.path` 是 `/actuator/health` |
| **端口错误** | `connection refused` | `readinessProbe.port` 必须等于应用的 `containerPort` |
| **依赖未就绪 (最特殊)** | `/health` 返回 503 | **这是正确的行为!** 不需要改 Probe,去修依赖 (如 DB 挂了) |
| **探针超时** | `context deadline exceeded` | 增大 `timeoutSeconds` |

**Readiness vs Liveness 面试必须能区分**:

| | Readiness | Liveness |
|---|----------|---------|
| 问题 | "能接流量了吗?" | "还活着吗?" |
| 失败后果 | 从 Service Endpoints 摘除 (不重启) | Kill 容器并重启 |
| 重启风暴风险 | 0 | 如果不区分,失败了会无限重启 |

**面试亮点**:
> "如果 DB 挂了,Readiness 返回 503 是正确的——Pod 确实无法服务,从负载均衡中摘除是对的。但 Liveness Probe 不应该因为 DB 挂了就失败,否则会导致重启风暴。生产上 Readiness 和 Liveness 应该检查不同级别的健康度。"

---

#### English

**Symptom**: Pod STATUS=Running, READY=0/1.

**Troubleshooting**: `kubectl describe pod <pod>` → Conditions + Events. Common: `initialDelaySeconds` too short for JVM startup, wrong path/port, or dependency returning 503 (which is **correct** behavior — the Readiness probe is honestly reporting that the Pod can't serve traffic).

**Key interview distinction**: *"Readiness determines whether a Pod receives traffic. Liveness determines whether it gets restarted. If you tie Liveness to DB health, a DB outage causes a restart storm. Always use different health levels for Readiness vs Liveness in production."*

---

### Q1.5: Service 访问不通 —— Endpoints 为空

> **Pod 诞生步骤 8**: Endpoints Controller 没有把 Pod IP 加入 Endpoints
> **Pod birth step 8**: Endpoints Controller didn't add Pod IP to the Endpoints list

#### 中文

**症状**: `curl http://user-service.smart-invest.svc.cluster.local:8081` → timeout/d refused

**5 层排查 (面试必须能流畅讲出来)**:

```bash
# Layer 1: Service 的 Selector 对了吗?
kubectl get svc user-service -n smart-invest -o jsonpath='{.spec.selector}'
# → {"app.kubernetes.io/name":"user-service"}

# Layer 2: Endpoints 是否为空 ← 最关键!
kubectl get endpoints user-service -n smart-invest
# 如果 <none> → selector 没匹配到 Ready Pod

# Layer 3: Pod labels 和 Service selector 一致吗?
kubectl get pods -n smart-invest --show-labels | grep user-service
# Service selector: {"app.kubernetes.io/name":"user-service"}
# Pod labels 里必须有这组 key:value

# Layer 4: Pod 是 Ready 的吗?
kubectl get pods -n smart-invest
# 0/1 READY → Readiness Probe 失败 → 回到 Q1.4

# Layer 5: DNS 解析
kubectl run dns-test --image=busybox:1.28 -it --rm -- \
  nslookup user-service.smart-invest.svc.cluster.local
```

**面试核心 (背下来)**:
> **"Service 是通过 selector 匹配 Pod 的 labels 来找到后端的。`kubectl get endpoints` 为空时,说明 labels 没对上或 Pod 不 Ready。"**

---

#### English

**Symptom**: curl to Service DNS name times out or connection refused.

**5-layer diagnostic (memorize)**:

```bash
# 1. Service selector correct?
# 2. Endpoints EMPTY? (key diagnostic)
# 3. Pod labels match Service selector?
# 4. Pods Ready?
# 5. CoreDNS resolving?
```

**Core mantra**: *"A Service finds its backend Pods by matching `selector` against Pod `labels`. Empty Endpoints → labels mismatch or Pods not Ready."*

---

### Q1.6: OOMKilled (exit 137) —— 容器被 OOM Killer 杀掉

> **Pod 诞生步骤 6**: 容器超出 cgroup 内存限制,被 Linux 内核 OOM Killer 杀掉
> **Pod birth step 6**: Container exceeds cgroup memory limit, killed by Linux kernel OOM Killer

#### 中文

**症状**:
```bash
kubectl describe pod <pod> -n smart-invest | grep -A3 "Last State"
#   Last State:   Terminated
#     Reason:     OOMKilled          ← 一眼定位
#     Exit Code:  137                ← 137 = 128 + 9 (SIGKILL)
```

**OOMKilled 的机制**:
1. 容器内存 > `resources.limits.memory`
2. 内核 OOM Killer → SIGKILL (不可捕获,无法优雅关闭)
3. K8s 重启容器 → CrashLoopBackOff

**排查**:
```bash
# 确认 OOM
kubectl describe pod <pod> -n smart-invest | grep -E "Reason|Exit Code"

# 查看当前 limit
kubectl get pod <pod> -n smart-invest -o yaml | grep -A4 "resources:"

# 看 Pod 的内存使用历史 (有 Prometheus 时)
# container_memory_working_set_bytes{pod="..."}

# 节点级 OOM 事件
dmesg | grep -i "out of memory"
```

**Java 特有问题——JVM 堆外内存**:
> JVM 的内存 = 堆 (Heap,受 `-Xmx` 控制) + 堆外 (Metaspace、Direct Buffer、线程栈、native code)。如果把 `-Xmx` 设成等于 `limits.memory`,容器必定 OOM!

**公式**: **`-Xmx = limits.memory × 0.75`** (留 25% 给堆外)

在 [values.yaml:27-33](infrastructure/helm-charts/charts/user-service/values.yaml) 中:
```yaml
resources:
  limits:
    memory: 768Mi   # 容器总内存
# 对应 JVM: -Xmx512m  (512 ≈ 768 × 0.67)
```

---

#### English

**Symptom**: `Reason: OOMKilled, Exit Code: 137` in `kubectl describe`.

**Key insight**: Exit 137 = 128 + 9 (SIGKILL). The kernel OOM Killer killed the container because it exceeded `resources.limits.memory`. It's not catchable — no graceful shutdown.

**Java-specific**: *"`-Xmx` controls JVM heap only. Metaspace, Direct Buffers, thread stacks are off-heap. The formula: `-Xmx = limits.memory × 0.75`. Setting `-Xmx` equal to the limit guarantees OOM."*

---

### Q1.7: kube-proxy iptables 规则不生效

> **Pod 诞生步骤 9**: kube-proxy 未及时更新 iptables 规则
> **Pod birth step 9**: kube-proxy didn't update iptables in time

#### 中文

**症状**: Pod Ready,Endpoints 有 IP,但 curl SVC 不通 —— 说明问题在 iptables 层。

**排查**:
```bash
# 1. kube-proxy Pod 正常吗?
kubectl get pods -n kube-system | grep kube-proxy

# 2. 节点上检查 iptables 规则
iptables -t nat -L KUBE-SERVICES -n | grep <cluster-ip>

# 3. kube-proxy 日志
kubectl logs <kube-proxy-pod> -n kube-system --tail=50

# 4. iptables 模式 vs IPVS 模式
kubectl logs <kube-proxy-pod> -n kube-system | grep "Using"
# "Using iptables Proxier" 或 "Using ipvs Proxier"
```

**大集群常见问题**: iptables 规则太多 (>1000 条) → 更新变慢 → 切到 IPVS 模式 (`--proxy-mode=ipvs`)

---

#### English

**Symptom**: Pod Ready, Endpoints has IPs, but Service curl fails. Problem is at the iptables/IPVS layer.

**Check**: kube-proxy Pod healthy? `iptables -t nat -L KUBE-SERVICES` on node? Large clusters should switch from iptables to IPVS mode (`--proxy-mode=ipvs`).

---

### Q1.8: Admission Webhook 拒绝部署

> **Pod 诞生步骤 2**: Mutating/Validating Admission Webhook 拒绝了 Pod 创建
> **Pod birth step 2**: Admission Webhook rejects Pod creation

#### 中文

**症状**:
```bash
kubectl apply -f deployment.yaml
# Error: failed calling webhook "istio-sidecar-injector.istio.io":
#   Post "https://istiod.istio-system.svc:443/inject": connection refused
```

**排查**:
```bash
# 1. 找到哪个 Webhook
kubectl get mutatingwebhookconfigurations,validatingwebhookconfigurations

# 2. Webhook 的 Service/Pod 还活着吗?
kubectl get svc -n istio-system istiod
kubectl get pods -n istio-system | grep istiod

# 3. Webhook 证书过期? 看 Webhook YAML 的 caBundle
kubectl get mutatingwebhookconfigurations istio-sidecar-injector -o yaml | grep caBundle
```

**紧急修复**:
```bash
# 删除 Webhook (不影响已经运行的 Pod,但新 Pod 不会注入 sidecar)
kubectl delete mutatingwebhookconfigurations istio-sidecar-injector

# 或者: 给 namespace 关掉注入
kubectl label namespace smart-invest istio-injection=disabled --overwrite
```

---

#### English

**Symptom**: `kubectl apply` fails with `failed calling webhook`.

**Troubleshoot**: Identify the Webhook name from the error → check its backend Service/Pod → check certificate expiry. Emergency: delete the Webhook config or disable injection via namespace label.

---

## Part II: Helm 实战
## Part II: Helm Hands-on

*你同事特别强调的领域。SAP Kyma 所有部署都走 Helm。*

---

### Q2.1: `helm upgrade --install` — 生产上最常用的 Helm 命令

#### 中文

面试官期待的答案:

```bash
helm upgrade --install <release-name> <chart-path> -n <namespace>
```

- Release 不存在 → 自动 `helm install`
- Release 已存在 → 自动 `helm upgrade`
- **一条命令覆盖两种场景,不需要先判断再选择**

我们项目的实际使用 ([deploy-k3s.sh:54](scripts/deploy-k3s.sh)):
```bash
sudo helm upgrade --install smart-invest . \
  --namespace smart-invest --create-namespace \
  --set user-service.image.tag=v2 \
  --wait --timeout 300s
```

**关键参数**:
| 参数 | 作用 |
|------|------|
| `--install` | release 不存在时自动安装 |
| `--wait` | 等所有资源就绪才返回 (CI Pipeline 必须) |
| `--timeout` | 超时时间,配合 `--wait` 使用 |
| `--create-namespace` | namespace 不存在时自动创建 |
| `--set` | 覆盖 values.yaml 中的值 (仅适合简单覆盖) |
| `-f values-prod.yaml` | 用文件覆盖 (生产推荐) |
| `--dry-run` | 模拟执行,不真正部署 |
| `--atomic` | 部署失败自动回滚 |

---

#### English

```bash
helm upgrade --install <release> <chart> -n <ns>
```
- No release → auto-install
- Release exists → auto-upgrade
- One command handles both. This is the single most-used Helm command in production.

---

### Q2.2: Helm 回滚 (rollback / history / status)

#### 中文

```bash
# Step 1: 当前状态
helm status smart-invest -n smart-invest

# Step 2: 查历史版本
helm history smart-invest -n smart-invest
# REVISION  UPDATED                  STATUS      CHART           DESCRIPTION
# 1         ...                      superseded  smart-invest-0.1.0  Install complete
# 2         ...                      superseded  smart-invest-0.2.0  Upgrade complete
# 3         ...                      deployed    smart-invest-0.2.0  Upgrade complete

# Step 3: 回滚到指定 revision
helm rollback smart-invest 2 -n smart-invest

# Step 4: 验证
helm history smart-invest -n smart-invest
# REVISION 4  ...  deployed  ...  Rollback to 2
```

**面试必知**:
- `helm rollback` 会创建新的 REVISION (比如 3→4)
- `helm uninstall` 删除 release (想恢复只能重新 install)
- Helm 3 不再需要 Tiller (服务端组件已移除,比 Helm 2 更安全)

---

#### English

```bash
helm status <release> -n <ns>          # Current state
helm history <release> -n <ns>         # All revisions
helm rollback <release> <revision> -n <ns>  # Rollback
```

*Note: Rollback creates a new REVISION. Helm 3 removed Tiller — all state is stored in K8s Secrets.*

---

### Q2.3: Umbrella Chart 结构与 values 级联

#### 中文

我们 smart-invest 项目的真实结构:

```
infrastructure/helm-charts/
├── umbrella/                          # 聚合 chart
│   ├── Chart.yaml                     # name + dependencies (子 chart 列表)
│   ├── Chart.lock                     # dependency update 锁定
│   ├── values.yaml                    # 顶层 values (传给子 chart)
│   ├── charts/                        # 依赖的子 chart 打包文件
│   │   ├── user-service-0.1.0.tgz
│   │   └── ...
│   └── templates/                     # umbrella 级的模板 (ingress, secret)
│       ├── ingress.yaml
│       └── secret.yaml
│
├── charts/                            # 各子 chart 源码
│   ├── user-service/
│   │   ├── Chart.yaml                 # name: user-service, version: 0.1.0
│   │   ├── values.yaml                # 默认值 (可被 umbrella 覆盖)
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── deployment.yaml
│   │       └── service.yaml
│   ├── fund-service/                   # … 同理 …
│   ├── order-service/
│   ├── notification-worker/
│   ├── api-gateway/
│   ├── frontend/
│   └── rabbitmq/
```

**Values 级联优先级 (低→高)**:
```
子 chart values.yaml  <  umbrella values.yaml  <  helm install --set  <  -f 外部文件
```

在 [umbrella/values.yaml:21-25](infrastructure/helm-charts/umbrella/values.yaml):
```yaml
user-service:
  replicaCount: 1
  fullnameOverride: user-service
  image:
    tag: v1
```
这行通过 chart 名 (`user-service:`) 将配置传给子 chart 的 `.Values`。

---

#### English

Our project uses an **Umbrella Chart** pattern: one top-level chart with sub-chart dependencies, each sub-chart manages one microservice. Values cascade: sub-chart defaults < umbrella values < `--set` < `-f` external file.

---

### Q2.4: `helm template` — 不部署, 只看渲染后的 YAML

#### 中文

```bash
# 渲染整个 release (会处理 dependencies)
helm template smart-invest ./umbrella -n smart-invest

# 只渲染某个子 chart 的 deployment
helm template smart-invest ./umbrella -n smart-invest \
  -s charts/user-service/templates/deployment.yaml

# 模拟渲染 (看替换后的值), 配合 --debug 看到实际参数
helm template smart-invest ./umbrella -n smart-invest --debug 2>&1 | less
```

**什么场景用**: 怀疑 Helm template 的 Go 模板语法有问题、values 没传对、变量没展开——先 `helm template` 看一眼渲染结果。

---

#### English

`helm template` renders templates locally without applying to the cluster. Use `--debug` to see computed values. Essential for debugging Go template syntax or values passing.

---

### Q2.5: Helm Hook — 部署顺序控制

#### 中文

Helm Hook 控制资源创建/删除的顺序:

```yaml
metadata:
  annotations:
    "helm.sh/hook": pre-install, pre-upgrade   # 在 install/upgrade 前执行
    "helm.sh/hook": post-install, post-upgrade  # 在 install/upgrade 后执行
    "helm.sh/hook": pre-delete                  # 在删除前执行 (如数据库备份)
    "helm.sh/hook-weight": "5"                 # Hook 间的执行顺序 (越小越先)
```

**典型场景**: 部署前跑 DB migration Job (pre-upgrade hook),部署后跑 smoke test Job (post-install hook)。

---

#### English

Helm Hooks control resource lifecycle ordering via `helm.sh/hook` annotations. Common: `pre-upgrade` for DB migration Jobs, `post-install` for smoke tests.

---

### Q2.6: Helm 依赖管理

#### 中文

```bash
# 更新依赖 (下载远程 chart 到 charts/ 目录)
helm dependency update ./umbrella

# 列出当前依赖
helm dependency list ./umbrella

# 构建依赖 (只打包本地,不下载)
helm dependency build ./umbrella
```

在 [umbrella/Chart.yaml:17-38](infrastructure/helm-charts/umbrella/Chart.yaml) 中:
- `file://../charts/user-service` → 本地子 chart → `helm dependency build` 打包
- `repository: "https://charts.bitnami.com/bitnami"` → 远程 chart → `helm dependency update` 下载

---

#### English

`helm dependency update` downloads remote charts. `helm dependency build` packages local charts. Local deps use `file://`, remote deps use a Helm repo URL.

---

## Part III: Docker & 镜像
## Part III: Docker & Image Management

---

### Q3.1: Dockerfile 最佳实践

#### 中文

我们项目 [build-images.sh](scripts/build-images.sh) 中的精简 Dockerfile:

```dockerfile
# 好的写法: 多阶段 + non-root
FROM eclipse-temurin:21-jre-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
# 创建非 root 用户
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**面试关键点**:
1. **Multi-stage build**: build stage 用 JDK,runtime stage 只用 JRE → 镜像体积减半
2. **Non-root user**: `USER app` → 容器不以 root 运行 (安全必须)
3. **Alpine 基础镜像**: 体积小,攻击面小
4. **EXPOSE 不实际暴露端口**: 只是文档作用,真正暴露靠 `docker run -p`
5. **ENTRYPOINT vs CMD**: ENTRYPOINT 是固定命令,CMD 是默认参数 (可被 `docker run` 覆盖)

我们项目为什么没在容器内 `mvn package`?
> 因为 CI 里已经提前 `mvn package` 好了,Dockerfile 直接 COPY jar → 极速构建。避免了在容器内重新下载所有 Maven 依赖。

---

#### English

Best practices: multi-stage (JDK build → JRE runtime), non-root user (`USER app`), Alpine base, COPY pre-built JAR from CI (don't rebuild inside Docker). ENTRYPOINT is the fixed command; CMD provides overridable defaults.

---

### Q3.2: Docker 镜像体积优化

#### 中文

| 手段 | 效果 |
|------|------|
| Alpine 基础镜像 | eclipse-temurin:21-jre-alpine ≈ 200MB vs ubuntu ≈ 600MB |
| Multi-stage build | 构建工具不进入最终镜像 |
| .dockerignore | 排除 `target/`, `node_modules/` 等不必要文件 |
| 合并 RUN 指令 | 减少 layer 数量: `RUN cmd1 && cmd2 && cmd3` |
| jlink (JVM): | 只用你需要的模块,生成 custom JRE ≈ 40MB |

---

#### English

Shrink images via Alpine base, multi-stage builds, `.dockerignore`, layer squashing, and JVM `jlink` for custom minimal JREs.

---

### Q3.3: 容器启动慢排查

#### 中文

**常见原因**:
1. JVM 类加载 → `-XX:+PrintClassHistogram` 看类加载时间
2. 依赖等待 (DB/MQ 没准备好) → `initContainers` 做依赖检查
3. 镜像太大,拉取慢 → 镜像优化 + 节点本地缓存 (imagePullPolicy: IfNotPresent)
4. Spring Boot lazy initialization: `spring.main.lazy-initialization=true`

---

## Part IV: CI/CD & Jenkins Pipeline
## Part IV: CI/CD & Jenkins Pipeline

---

### Q4.1: Jenkins Pipeline: Declarative vs Scripted

#### 中文

**这是你同事说面试必问的题。**

| | Declarative Pipeline | Scripted Pipeline |
|---|---------------------|-------------------|
| **语法** | `pipeline { ... }` 结构化 | `node { ... }` 自由 Groovy |
| **学习曲线** | 低——定义式,类似 YAML | 高——需要 Groovy 编程 |
| **错误处理** | 内置 `post {}` 块 | 需要 `try/catch` |
| **代码复用** | 受限——只能模板化 | 灵活——Shared Library 写任意 Groovy |
| **适用场景** | 95% 的 CI/CD 场景 | 复杂逻辑: 自定义并行、动态 stage |
| **SAP 环境** | ✅ SAP Piper 用 Declarative | SAP 内部高级模板可能含 Scripted |

**Declarative 示例**:
```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }
        stage('Deploy') {
            when { branch 'main' }    // 只有 main 分支才部署
            steps {
                sh 'helm upgrade --install app ./chart -n prod'
            }
        }
    }
    post {
        failure { emailext to: 'team@example.com', subject: 'Build Failed' }
    }
}
```

**Scripted 示例** (什么时候需要):
```groovy
node {
    stage('Parallel Tests') {
        // 动态并行: Declarative 的 parallel {} 做不到这种运行时决定
        def testTargets = sh(script: 'find . -name "*Test.java"', returnStdout: true).trim().split('\n')
        def branches = [:]
        testTargets.each { test ->
            branches[test] = { sh "mvn test -Dtest=${test}" }
        }
        parallel branches
    }
}
```

---

#### English

| | Declarative | Scripted |
|---|------------|----------|
| Syntax | `pipeline { stages { stage { steps {} } } }` | `node { stage { ... } }` |
| Error handling | Built-in `post {}` | Manual `try/catch` |
| SAP usage | SAP Piper templates use Declarative | Advanced shared libraries may embed Scripted |
| When to use Scripted | Dynamic parallel stages, runtime-determined logic | |

---

### Q4.2: Jenkinsfile — stage / step / when / post

#### 中文

```groovy
pipeline {
    agent any
    environment {                       // 全局环境变量
        HELM_REPO = 'infrastructure/helm-charts'
    }
    stages {
        stage('Checkout') { steps { checkout scm } }
        stage('Build') {
            steps { sh 'mvn package' }
        }
        stage('Security Scan') {        // 并行阶段
            parallel {
                stage('SonarQube') { steps { sh 'mvn sonar:sonar' } }
                stage('CodeQL')    { steps { sh 'codeql analyze' } }
            }
        }
        stage('Deploy to Dev') {
            when { branch 'develop' }   // 条件执行
            steps { sh 'helm upgrade --install ...' }
        }
        stage('Deploy to Prod') {
            when { branch 'main' }
            input { message 'Approve?' } // 人工确认
            steps { sh 'helm upgrade --install ...' }
        }
    }
    post {
        always   { cleanWs() }          // 无论成功失败都清理
        success  { echo 'OK!' }
        failure  { emailext body: '...', subject: 'FAILED', to: 'team@co.com' }
    }
}
```

面试讲清楚: **`when` 控制 stage 是否执行, `post` 是钩子 (回调), `parallel` 并行加速**。

---

#### English

`when` controls conditional stage execution. `post` is lifecycle hooks (always/success/failure). `parallel` runs stages concurrently. SAP Piper builds on these with pre-built shared library stages for compliance scanning.

---

### Q4.3: Pipeline 失败排查

#### 中文

**标准排查流程**:

```bash
# 1. Jenkins Blue Ocean 看 stage 视图——哪个 stage 红的?
# 2. 点进失败的 stage → Console Output → 找第一个 ERROR 行
# 3. 常见错误模式:

# 模式 A: "command not found"
# → 缺少工具: agent 镜像中没有 mvn/helm/kubectl

# 模式 B: "Permission denied"
# → kubeconfig 不对或过期 / Vault token 过期 / Git credential 失效

# 模式 C: "Connection refused"
# → K8s API Server 不可达 / 网络问题 / Vault 地址不可达

# 模式 D: Replay 大法
# → Jenkins 点 "Replay" 按钮 → 不改 Jenkinsfile 直接重新跑 (排查神器)
```

**SAP Piper 特有**: SAP Piper/Hyperspace pipeline 出错时,先检查 Compliance Stage (SonarQube / Checkmarx / Black Duck 扫描是否被新代码触发了新问题拦住了)。

---

#### English

Step 1: Blue Ocean view → which stage is red? Step 2: Console Output → find first ERROR. Step 3: Common patterns — `command not found` (missing tools), `Permission denied` (expired kubeconfig/Vault token), `Connection refused` (API server/Vault unreachable). Jenkins "Replay" button is the debugging Swiss Army knife.

---

### Q4.4: 多分支 Pipeline (Multibranch)

#### 中文

面试要讲清楚:
- **Multibranch Pipeline** → 自动为每个分支/PR 创建对应的 Pipeline Job
- **Jenkinsfile 放在 repo 根目录** → 每个分支可以有自己的 Pipeline 定义
- **配合 GitHub Webhook** → 每次 push/PR 自动触发对应分支的 Pipeline

SAP 环境是 Single-Trunk (单主干),所以主要是 feature branch → CI build → PR merge → trunk → CD deploy 这个流程。

---

### Q4.5: CI/CD 安全扫描集成 (SAP Piper 特有)

#### 中文

SAP Piper compliance chain 包含:
| 工具 | 扫描什么 |
|------|---------|
| **SonarQube** | 代码质量 + 安全漏洞 |
| **CodeQL** | 语义级代码安全分析 |
| **Checkmarx One** | SAST (静态应用安全测试) |
| **Black Duck** | 开源组件许可证 + 漏洞扫描 (SCA) |
| **Cumulus** | SAP 内部合规检查 |

**面试说法**: "CI Pipeline 有专门的 Compliance Stage,安全扫描不过就直接 Fail——不让进下一阶段。如果在模板库里修了 compliance steps,所有消费 repo 自动受益。"

---

## Part V: Istio Service Mesh
## Part V: Istio Service Mesh

---

### Q5.1: VirtualService 流量路由实战

#### 中文

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: user-service-canary
spec:
  hosts:
  - user-service
  http:
  - match:
    - headers:
        x-canary:
          exact: "enabled"       # 内部测试人员带这个 header → 走 v2
    route:
    - destination:
        host: user-service
        subset: v2
  - route:                       # 其他所有人默认
    - destination:
        host: user-service
        subset: v1
      weight: 95
    - destination:
        host: user-service
        subset: v2
      weight: 5                  # 金丝雀 5%
```

面试讲: **"VirtualService 回答 '流量到哪儿去'——按 Header/权重/路径把请求分发到不同的服务版本。"**

---

#### English

VirtualService answers *"where does traffic go?"* — routes by header, weight, or path to different service subsets. Used for canary deployments (5% → 25% → 50% → 100%), A/B testing, and circuit breaking.

---

### Q5.2: DestinationRule — 熔断 & 负载均衡

#### 中文

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: user-service-dr
spec:
  host: user-service
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN        # 最少连接
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 10
        maxRequestsPerConnection: 5
    outlierDetection:            # 熔断!
      consecutive5xxErrors: 3
      interval: 30s
      baseEjectionTime: 60s      # 踢出 60s
      maxEjectionPercent: 50
```

面试讲: **"DestinationRule 回答 '到了之后怎么处理'——负载均衡策略、连接池、熔断（outlier detection 弹开不健康的 Pod）。"**

---

#### English

DestinationRule answers *"once traffic arrives, how do we handle it?"* — load balancing strategy (LEAST_CONN / ROUND_ROBIN), connection pool limits, and circuit breaking (outlierDetection ejects unhealthy Pods).

---

### Q5.3: Sidecar 注入失败排查

#### 中文

**症状**: Pod 没有 sidecar 容器 (READY 1/1 而不是 2/2,因为 Istio sidecar 应该多一个 Envoy 容器)。

**排查**:
```bash
# 1. Namespace label 有 istio-injection 吗?
kubectl get namespace smart-invest --show-labels

# 2. 如果 label 有,但没注入 → Istio 的 mutating webhook 挂了
kubectl get mutatingwebhookconfigurations istio-sidecar-injector

# 3. istiod 还活着吗?
kubectl get pods -n istio-system | grep istiod

# 4. 看 istiod 日志
kubectl logs deployment/istiod -n istio-system --tail=50
```

---

#### English

Check namespace label `istio-injection=enabled`, verify the mutating webhook is healthy, check istiod Pod status. If the webhook is down, no new Pods get sidecars — and existing Pods still work (but without mTLS/routing).

---

### Q5.4: mTLS 工作不正常排查

#### 中文

**症状**: 微服务间调用突然报 TLS 错误 (`upstream connect error or disconnect/reset before headers`)。

**排查**:
```bash
# 1. PeerAuthentication 策略是什么?
kubectl get peerauthentication -A

# 2. DestinationRule 的 tls mode
kubectl get destinationrule -A -o yaml | grep "mode:"

# 3. 如果 istiod 重启后,证书过期 → 检查 istiod 日志
kubectl logs deployment/istiod -n istio-system | grep -i cert
```

**常见**: `PeerAuthentication` 设为 STRICT (强制 mTLS) 但某些服务没 sidecar → 连接被拒绝。

---

### Q5.5: Istio vs Resilience4j (Java 面试最爱问)

#### 中文

| | Istio | Resilience4j |
|---|-------|-------------|
| **层面** | 网络层 (Sidecar) | 应用层 (Java 库) |
| **改不改代码** | 不改 | 要加依赖 + 注解 |
| **范围** | 跨所有语言/服务 | 只 Java |
| **熔断粒度** | 网络连接级 | 方法调用级 (更细) |
| **是否替代?** | **不替代——互补** | Istio 管网络层,Resilience4j 管应用逻辑 |

面试说法: **"Istio 和 Resilience4j 不是替代关系,是互补。Istio 管网络级重试/超时/mTLS;Resilience4j 管业务方法级的熔断/限流/舱壁。两者可以同时用。"**

---

#### English

Istio (network-level, language-agnostic) and Resilience4j (application-level, Java-specific) are complementary, not substitutes. Istio handles retries/timeouts/mTLS at the proxy layer; Resilience4j handles method-level circuit breaking, rate limiting, and bulkheads in Java code.

---

## Part VI: 监控 & 可观测性
## Part VI: Observability & Monitoring

---

### Q6.1: Prometheus + Grafana 架构

#### 中文

```
┌─────────────┐    ┌──────────────┐    ┌──────────────┐
│  Java App   │───→│  Prometheus   │───→│   Grafana    │
│ /actuator/  │    │  (Pull 模式:   │    │  (可视化面板)  │
│ prometheus  │    │   每15s 抓一次) │    │              │
└─────────────┘    └──────┬───────┘    └──────────────┘
                          │
                   ┌──────┴───────┐
                   │ AlertManager │
                   │  (告警→Slack/ │
                   │   邮件/电话)   │
                   └──────────────┘
```

我们项目 [deploy-monitoring.sh](scripts/deploy-monitoring.sh) 用 kube-prometheus-stack (Prometheus Operator) 部署,通过 [ServiceMonitor](infrastructure/monitoring/servicemonitor.yaml) CRD 告诉 Prometheus 抓取哪些 Service 的 `/actuator/prometheus`。

---

#### English

Prometheus pulls metrics every 15s from `/actuator/prometheus` (Spring Boot Micrometer). ServiceMonitor CRDs define scrape targets. AlertManager sends alerts to Slack/email. Grafana visualizes.

---

### Q6.2: ServiceMonitor & PodMonitor

#### 中文

我们项目的 [servicemonitor.yaml](infrastructure/monitoring/servicemonitor.yaml):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: smart-invest-services
  namespace: monitoring
  labels:
    release: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/instance: smart-invest   # 抓取所有 smart-invest umbrella 下的 Pod
  namespaceSelector:
    matchNames:
      - smart-invest
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 15s
```

**面试**: "ServiceMonitor 是 Prometheus Operator 的 CRD。它告诉 Prometheus 哪些 Service 需要被抓取——通过 label selector 匹配,不需要手动改 Prometheus 配置文件。"

---

#### English

ServiceMonitor is a Prometheus Operator CRD that declaratively defines scrape targets via label selectors — no manual Prometheus config changes needed.

---

### Q6.3: CloudWatch / Cloud Logging

#### 中文

```bash
# AWS CloudWatch 查 EC2 CPU
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-xxx \
  --start-time 2026-08-01T00:00:00Z --end-time 2026-08-08T00:00:00Z \
  --period 300 --statistics Average

# 查 ALB 5xx 错误
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=app/my-alb/xxx ...
```

**SAP Kyma 上**: 用 Dynatrace + AvS + Cloud Logging (非自建 Prometheus)。面试时可以说: "Prometheus 是 K8s 原生监控的事实标准;Dynatrace 是企业级的全栈 APM,有 AI 异常检测。"

---

### Q6.4: 告警规则设计

#### 中文

**面试常问**: "你配过哪些 Prometheus 告警规则?"

```yaml
groups:
  - name: smart-invest
    rules:
      - alert: HighErrorRate
        expr: rate(http_server_requests_seconds_count{status=~"5.."}[5m]) > 0.05
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.service }} 错误率超过 5%"

      - alert: PodRestartingFrequently
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m

      - alert: HighMemoryUsage
        expr: container_memory_working_set_bytes / container_spec_memory_limit_bytes > 0.85
        for: 10m
```

**面试**: "告警规则的设计原则: 1) 关注 symptom (症状) 而非 root cause (根因); 2) `for` 避免毛刺触发; 3) `annotations` 和 `labels` 做好路由和 runbook 链接。"

---

### Q6.5: Distributed Tracing (Jaeger/Zipkin)

#### 中文

**面试要说出**: "一个请求经过 order-service → fund-service → user-service 三个微服务,怎么追踪慢在哪一步?"

Istio + Jaeger: Sidecar (Envoy) 自动 propagate trace headers (b3 / w3c tracecontext), 不需要改代码。Jaeger UI 可以看整个调用链的水线图 (span waterfall)。

Spring Boot 项目加 Micrometer Tracing + bridge 后, 也可以在 `/actuator/httpexchanges` 看请求追踪。

---

## Part VII: GitOps & ArgoCD
## Part VII: GitOps & ArgoCD

---

### Q7.1: GitOps 核心思想

#### 中文

> **"Git 是唯一的 source of truth。集群的期望状态存在 Git 仓库里。ArgoCD/Flux 自动把 Git 中的状态同步到集群中。"**

**Pull vs Push**:
- Push (CI/CD): Jenkins push 到 K8s (`kubectl apply`)
- Pull (GitOps): ArgoCD watch Git → 发现变更 → 自动 apply

**SAP Kyma 场景**: GitOps repo 存 namespace-level 资源 (ServiceInstances, VirtualServices, ConfigMaps, role bindings, image-pull secrets)。新增 region → 新加一个 values 文件 + ArgoCD Application → 自动创建 namespace 下所有资源。

---

#### English

Git is the single source of truth. ArgoCD continuously reconciles the cluster state to match Git. Push (Jenkins) vs Pull (ArgoCD). SAP Kyma: GitOps repo provisions all namespace-level resources per region.

---

### Q7.2: ArgoCD Sync 失败排查

#### 中文

```bash
# ArgoCD UI: App → SYNC STATUS → OutOfSync / Unknown

# CLI 排查:
argocd app get <app-name> --show-operation
argocd app diff <app-name>              # 看 Git 和集群的实际差异
argocd app logs <app-name>              # 看 sync 日志

# 常见 sync 失败原因:
# 1. Helm values 语法错误 → Vault 路径变了但 values 没更新
# 2. CRD 还没安装 → 先装 CRD 再 sync
# 3. webhook 超时 → Istio sidecar 注入慢,增大 ArgoCD timeout
```

---

### Q7.3: 多环境 GitOps (环境差异化)

#### 中文

常见两种模式:
1. **Branch-based**: `env/dev` → dev cluster, `env/prod` → prod cluster (简单,但 branch 多了难维护)
2. **Overlay-based** (Kustomize): `base/` + `overlays/dev/` + `overlays/prod/` (我们项目用这种方式)

我们 [kustomize/overlays/prd/](infrastructure/kustomize/overlays/prd/) 展示了 prd 环境覆盖 dev 的 replicas 和资源规格。

---

## Part VIII: HashiCorp Vault & Secret Management
## Part VIII: HashiCorp Vault & Secret Management

---

### Q8.1: K8s Secret vs Vault

#### 中文

| | K8s Secret | HashiCorp Vault |
|---|-----------|----------------|
| **存储** | 集群内 etcd (base64,明文可解) | 独立服务 (加密存储) |
| **轮换** | 手动 (改 Secret → 重启 Pod) | 自动! Dynamic secret TTL 过期自动轮换 |
| **审计** | 没有审计日志 | 完整的审计 trail |
| **访问控制** | RBAC | 细粒度 Policy |

SAP Kyma 环境中,所有 Secret (kubeconfigs, GitHub tokens, Artifactory credentials) 都走 Vault, Pipeline 通过 Vault path 拉取。

---

#### English

K8s Secrets are base64-encoded in etcd (decodable), no rotation, no audit. Vault offers encrypted storage, dynamic secrets with auto-rotation, full audit trails. SAP Kyma pipelines fetch all credentials from Vault paths.

---

### Q8.2: Vault 集成 Pipeline 的常见问题

#### 中文

**症状**: Pipeline 报 `403 Forbidden` 拉 Vault secret。

**排查**:
```bash
# 1. Vault token 过期了?
vault token lookup

# 2. Policy 变更导致权限缩小?
vault policy read <policy-name>

# 3. Vault server 不可达?
curl -v https://vault.internal.example.com/v1/sys/health
```

SAP Piper/Hyperspace 场景: 新增 region 只需加一条 Vault path mapping,被 Application Pipeline 和 GitOps Pipeline 共享。

---

## Part IX: 网络 & DNS
## Part IX: Networking & DNS

---

### Q9.1: CoreDNS 解析失败排查

#### 中文

**症状**: Pod 内 `nslookup user-service` 报 `server can't find user-service: NXDOMAIN`

**排查**:
```bash
# 1. CoreDNS Pod 还活着吗?
kubectl get pods -n kube-system | grep coredns

# 2. CoreDNS 配置
kubectl get configmap coredns -n kube-system -o yaml

# 3. 从 debug Pod 测试 DNS
kubectl run dns-test --image=busybox:1.28 -it --rm -- nslookup kubernetes.default

# 4. 如果 kubernetes.default 能解析,但自定义 Service 不能
#    → 检查 Service 的 DNS 名是否正确: <service>.<namespace>.svc.cluster.local
```

---

#### English

Check CoreDNS Pods, ConfigMap, and DNS resolution from a debug Pod. If `kubernetes.default` resolves but your Service doesn't → verify Service DNS name format: `<svc>.<ns>.svc.cluster.local`.

---

### Q9.2: NetworkPolicy 排查

#### 中文

**症状**: Pod A 突然连不上 Pod B,但昨天还是好的。

**排查**:
```bash
kubectl get networkpolicies -n smart-invest
# 如果有 NetworkPolicy → 默认是 deny-all,白名单模式!
# 没有 NetworkPolicy → 默认 allow-all
```

**关键**: 一旦 namespace 有任何 NetworkPolicy,默认规则变成 deny-all。新加的 NetworkPolicy 可能漏掉了某些 podSelector。

---

### Q9.3: Ingress 路由不通

#### 中文

我们项目 [ingress.yaml](infrastructure/helm-charts/umbrella/templates/ingress.yaml) 定义了 Traefik 路由:

```yaml
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-gateway
                port:
                  number: 8080
```

**排查**:
```bash
kubectl get ingress -n smart-invest
# Ingress 有 ADDRESS 吗? 没有 → Ingress Controller 没在工作

kubectl get pods -n kube-system | grep traefik   # K3S 默认 Traefik
kubectl describe ingress smart-invest -n smart-invest
```

---

## Part X: K8s 安全
## Part X: K8s Security

---

### Q10.1: RBAC 排查 (Forbidden Error)

#### 中文

**症状**:
```bash
kubectl get pods
# Error from server (Forbidden): pods is forbidden: User "xxx" cannot list resource "pods"
```

**排查**:
```bash
# 1. 我是谁?
kubectl auth whoami

# 2. 我能做什么?
kubectl auth can-i list pods -n smart-invest

# 3. 检查 Role/RoleBinding
kubectl get role,rolebinding -n smart-invest
kubectl describe rolebinding <name> -n smart-invest

# 4. ServiceAccount 与 Deployment
kubectl get pod <pod> -n smart-invest -o jsonpath='{.spec.serviceAccountName}'
```

---

### Q10.2: SecurityContext 与容器安全

#### 中文

```yaml
spec:
  securityContext:
    runAsNonRoot: true       # 禁止 root 运行
    runAsUser: 1000          # 指定 UID
    fsGroup: 1000
  containers:
  - securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]        # 丢掉所有 Linux Capabilities
```

面试: "容器安全的底线: non-root、只读根文件系统、禁止权限提升、丢掉所有 capabilities。"

---

### Q10.3: Image Scanning & Supply Chain

#### 中文

CI Pipeline 中的安全链: SonarQube (代码) → CodeQL (语义) → Checkmarx (SAST) → Black Duck (SCA / 组件漏洞) → 容器镜像签名 (Cosign / Notary)。SBOM (Software Bill of Materials) 记录所有依赖及版本。

---

## Part XI: Linux & OS
## Part XI: Linux & OS Troubleshooting

---

### Q11.1: 磁盘满了怎么排查

#### 中文

```bash
# 1. 整体
df -h

# 2. 哪个目录最大?
du -sh /* 2>/dev/null | sort -rh | head -10

# 3. Docker/K8s 镜像/容器占的空间
docker system df
crictl images | head -20
crictl rmi --prune         # 清理无用镜像

# 4. 日志文件过大?
du -sh /var/log/*
journalctl --disk-usage     # systemd journal

# 5. 已删除但未释放的文件 (进程还在写)
lsof | grep deleted | sort -nrk7 | head -10
```

---

### Q11.2: CPU 高负载排查

#### 中文

```bash
# 1. 整体负载
top    # 看 load average、按 CPU 排序

# 2. 哪个进程?
ps aux --sort=-%cpu | head -10

# 3. 容器维度
kubectl top pods -n smart-invest
kubectl top nodes

# 4. 容器内的 Java 进程
kubectl exec -it <pod> -n smart-invest -- top -bn1
kubectl exec -it <pod> -n smart-invest -- jstack 1  # Java 线程 dump
```

---

### Q11.3: 网络连通性排查

#### 中文

```bash
# DNS
nslookup example.com
dig example.com

# 端口连通
nc -zv 10.0.0.1 5432        # TCP
telnet 10.0.0.1 5432

# 路由
traceroute 10.0.0.1
ip route show

# 抓包
tcpdump -i eth0 port 443 -nn

# 当前连接
ss -tlnp                     # 监听
ss -tnp                      # 已建立
```

---

## Part XII: AWS / Cloud 基础设施
## Part XII: AWS / Cloud Infrastructure

---

### Q12.1: VPC 网络设计 & Security Group 排查

#### 中文

**最常见问题**: Security Group 忘开端口。

我们项目的 [VPC 模块](infrastructure/modules/vpc/main.tf):
- VPC `10.0.0.0/16` → public subnet `10.0.1.0/24` + private subnet `10.0.2.0/24`
- Internet Gateway → public 子网可以访问外网
- EC2 SG: 入站 443 (HTTPS) + 22 (SSH,限 admin IP)
- RDS SG: 入站 5432 (PostgreSQL, 只接受来自 EC2 SG 的流量)

**排查**:
```bash
# AWS Console → EC2 → Security Groups → Inbound Rules
# 入站开了需要的端口吗? 源 IP/源 SG 对了吗?
# 出站 (Egress) 也是默认全开,如果有自定义就可能拦截
```

---

### Q12.2: RDS 连接问题

#### 中文

**症状**: Java 应用日志: `CommunicationsException: Communications link failure`

**排查**:
```bash
# 1. RDS endpoint 对吗?
aws rds describe-db-instances --db-instance-identifier smart-invest-db \
  --query 'DBInstances[0].Endpoint.Address'

# 2. SG 允许来自 EC2 的 5432 流量吗?
# 3. RDS 是 publicly_accessible=false → 必须从 VPC 内访问
# 4. RDS 的 master password secret → Vault 取到了吗?
aws secretsmanager get-secret-value --secret-id <secret-arn>
```

---

### Q12.3: IAM 权限不足排查

#### 中文

**症状**: `AccessDenied` 出现在 CloudWatch 日志 / AWS CLI

**排查**:
```bash
# 1. 当前身份
aws sts get-caller-identity

# 2. 模拟 policy 检查
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<account>:role/<role-name> \
  --action-names s3:GetObject ec2:DescribeInstances

# 3. CloudTrail 看谁拒绝的
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=AccessDenied
```

---

### Q12.4: EC2 启动失败 (user_data)

#### 中文

EC2 启动后应用没起来? 查 user_data 脚本日志:
```bash
# 连上 EC2 (如果 SSH 不通,用 Session Manager):
cat /var/log/cloud-init-output.log
cat /var/log/cloud-init.log
```

我们 [user_data.sh](infrastructure/modules/ec2/user_data.sh) 做了: 安装 Java、从 S3 下载 JAR、配置 DB Secret、启动服务。

---

## Part XIII: Terraform IaC
## Part XIII: Terraform IaC

---

### Q13.1: Terraform State 管理

#### 中文

| 方式 | 适用 |
|------|------|
| **Local state** | 个人学习 (`.terraform/terraform.tfstate`) |
| **S3 + DynamoDB** | 团队协作: S3 存 state, DynamoDB 做 state lock |
| **Terraform Cloud** | 企业级 remote state + 自动 plan/apply |

**关键**: State 文件包含所有资源的真实信息 (ARN, IP 等) → 必须加密! State lock 防止两人同时 `apply` 导致冲突。

---

### Q13.2: `terraform plan` 报错排查

#### 中文

常见错误:
- `Error: Provider configuration not present` → `terraform init` 没跑,或 provider 版本不兼容
- `Error: Error acquiring the state lock` → 上一个 apply 进程还持有锁 → `terraform force-unlock` 或等超时
- `Error: Missing required argument` → 变量没设,`terraform.tfvars` 缺失 → 检查 `variables.tf` 和值源

---

### Q13.3: Module 设计与依赖管理

#### 中文

我们 [main.tf](infrastructure/main.tf) 通过 module 依赖链:
```
vpc → iam → rds → ec2 → s3_cloudfront
```

`outputs.tf` 暴露模块间的依赖 (如 `vpc.public_subnet_id` → `ec2` 模块)。面试: "Terraform 会根据 `depends_on` 和 resource 引用自动推导依赖图——这就是 plan 阶段能看到创建顺序的原因。"

---

## Part XIV: 综合场景
## Part XIV: Scenario-Based Questions

---

### Q14.1: 线上业务挂了——On-Call 完整排查流程

#### 中文

**面试官问**: "你正在 on-call,PagerDuty 响了,用户说网站打不开。从你爬起来到解决问题,每一步做什么?"

**标准化回答 (按时间线)**:

**第 0-1 分钟: Triage (分诊)**
- 确认告警: 是单个 service 还是全站? 哪个 region? 多少用户受影响?
- 看 Dynatrace/Grafana: 错误率、延迟、Pod 重启数有没有异常 spike?
- 最近的变更——检查 `kubectl rollout history` 看有没有刚刚部署的新版本

**第 1-3 分钟: 如果是部署引入的 → 立即回滚**
```bash
kubectl rollout undo deployment/<svc> -n <ns>
# 回滚是最快、最安全的止血手段
```

**第 3-5 分钟: 不是部署 → K8s 层面排查**
```bash
kubectl get pods -n <ns>                     # 有 CrashLoop? Pending?
kubectl describe pod <crashing-pod> -n <ns>  # Events 说什么?
kubectl logs <crashing-pod> -n <ns> --previous --tail=100
```

**第 5-10 分钟: 基础设施**
- 节点健康: `kubectl get nodes`, `kubectl top nodes`
- DB 连得上吗? `kubectl run debug --image=postgres -it --rm -- psql -h <rds-endpoint> -U smartadmin`
- Vault token 过期? Pipeline 能用 Vault 吗?

**第 10+ 分钟: 如果还没解决 → 升级**
- 把排查信息整理好 (War Room doc)
- 通知对应 on-call: DB team / Network team / Cloud infra team
- **给出诊断结论,不只是"我不行"** → "Pod crash 的原因是连不上 RDS,从 K8s 层面做了 port forward 也连不上,怀疑是 SG 被改了。需要云平台 team 确认。"

---

#### English

**On-call flow**:
1. Triage (0-1m): scope, region, recent changes, Dynatrace dashboard
2. If recently deployed → `kubectl rollout undo` immediately (fastest blood-stopper)
3. If not deploy → K8s pods → Events → logs `--previous` → dependencies (DB, Vault, DNS)
4. Infrastructure: nodes, RDS connectivity, Vault token, SG rules
5. Escalate with concrete diagnosis, not just "I can't fix it"

---

### Q14.2: 多 Region 部署故障诊断

#### 中文

**场景**: "在 US20 和 EU20 都部署了,US20 正常,EU20 的 Pod 起不来。"

**排查**:
1. Region 间配置差异: EU20 `values.yaml` 的 DB endpoint、Vault path、imagePullSecrets 是否配对?
2. K8s 集群差异: EU20 的节点资源、StorageClass、RBAC 是否一致?
3. 网络差异: EU20 的 egress 能否访问 Docker Hub/Vault?
4. Pipeline 日志: Azure DevOps 的 deploy 阶段,EU20 的 kubectl 输出有什么错误?

**SAP 实战**: 新增 region 通常在一天内完成 (chart values + Vault paths + ADO stage + GitOps infra),出错最多的是 Vault path mapping 遗漏和 imagePullSecrets 没配。

---

### Q14.3: 零停机滚动更新失败

#### 中文

**滚动更新策略**:
```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # 最多比 desired 多 1 个 Pod
      maxUnavailable: 0  # 可用 Pod 数绝不能降低
```

**失败排查**:
```bash
kubectl rollout status deployment/user-service -n smart-invest
kubectl rollout history deployment/user-service -n smart-invest

# 新 Pod 起不来 → Readiness Probe 一直失败 → 旧 Pod 不会被下线
# → 这就是"滚动更新不会导致全部挂掉"的保证
# → 如果 maxUnavailable=1, 旧 Pod 可能下线了但新 Pod 又起不来 → 服务部分瘫痪
kubectl rollout undo deployment/user-service -n smart-invest
```

---

### Q14.4: 数据库密码轮换后服务全部断连

#### 中文

**场景**: DBA 轮换了 RDS master password → 所有服务 CrashLoopBackOff (exit 1: DB 连不上)。

**止血**:
```bash
# 1. 立即把新密码更新到 Vault / K8s Secret
kubectl create secret generic db-secret --from-literal=password='<new-pwd>' \
  -n smart-invest --dry-run=client -o yaml | kubectl apply -f -

# 2. 滚动重启所有依赖 DB 的服务 (让它们读取新 Secret)
kubectl rollout restart deployment -n smart-invest -l app.kubernetes.io/instance=smart-invest

# 3. 如果不想全重启 → 只重启连 DB 的服务
kubectl rollout restart deployment user-service fund-service order-service \
  -n smart-invest
```

**预防**: 
- 用 Vault Dynamic Secrets → 密码自动轮换,应用自动发现
- 或者用 AWS Secrets Manager + Secret CSI Driver → Pod 自动重新 mount 新密码

---

## 附录 A: 排查万能公式 (背下来)
## Appendix A: Universal Troubleshooting Formula

### 中文

```
1. kubectl get pods -n <ns>                    # 状态快照
2. kubectl describe pod <name> -n <ns>          # Events (80% 答案在这里)
3. kubectl logs <name> -n <ns> --tail=200       # 当前日志
4. kubectl logs <name> -n <ns> --previous       # 上次崩溃日志
5. kubectl get events -n <ns> --sort-by='.lastTimestamp'  # 全命名空间 Events
6. kubectl rollout history deploy/<name> -n <ns>          # 部署历史
7. curl / nslookup / dig                          # 网络/DNS 测试
```

**心法**: 别猜,先看 Events。K8s 的设计哲学就是把诊断信息直接写在 Events 里。

### English

```
1. kubectl get pods -n <ns>                    # Status snapshot
2. kubectl describe pod <name> -n <ns>          # Events (80% of answers)
3. kubectl logs <name> -n <ns> --tail=200       # Current logs
4. kubectl logs <name> -n <ns> --previous       # Previous crash logs
5. kubectl get events -n <ns> --sort-by='.lastTimestamp'
6. kubectl rollout history deploy/<name> -n <ns>
7. curl / nslookup / dig
```

**Mantra**: Don't guess — read Events first. K8s was designed to surface diagnostics in Events.

---

## 附录 B: 你同事强调的面试高频词汇
## Appendix B: High-Frequency Interview Vocabulary

| 英文 | 中文 | 何时用 |
|------|------|--------|
| **triage** | 分诊/初步判断 | 描述第 1 分钟的处理 |
| **rollback / undo** | 回滚 | 止血的第一选择 |
| **describe** | explain | 不要只说 get,要 "describe the pod to read Events" |
| **--previous** | 上次 (崩溃日志) | 证明你上过生产环境的信号词 |
| **selector vs labels** | 选择器与标签匹配 | Service 不通的根本原因 |
| **idempotent** | 幂等 | K8s 每个操作都幂等——失败了重试也不会有副作用 |
| **reconcile** | 调和/协调 | 控制器的 reconcile loop——watch event → compare → act |
| **desired state** | 期望状态 | 你声明 replicas:3,controller 保证实际=3 |
| **watch** | 监听 | Controller watch etcd 的方式,不是轮询 |

---

> **参考文档**: [Kubernetes_Core_Principles_Guide.md](Kubernetes_Core_Principles_Guide.md) (Pod 诞生流程) | [Istio_Service_Mesh_Guide.md](Istio_Service_Mesh_Guide.md) | [Hydsoft_DevOps_Interview_QA_Bilingual.md](Hydsoft_DevOps_Interview_QA_Bilingual.md) | smart-invest 项目 infra/ + scripts/ 实战代码
