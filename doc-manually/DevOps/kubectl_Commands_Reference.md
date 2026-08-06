# kubectl 常用命令速查手册
# kubectl Common Commands Reference

> 以 smart-invest 项目为上下文，namespace 为 `smart-invest`。
> All examples use the smart-invest project (namespace: `smart-invest`).

---

## 零、基础概念 / Basic Concepts

### kubectl 命令的通式 / General Command Pattern

```bash
kubectl <action> <resource-type> [resource-name] [flags]
```

| 组件 | 说明 | 示例 |
|------|------|------|
| `<action>` | 你要做什么 | `get`, `describe`, `logs`, `exec`, `apply`, `delete` |
| `<resource-type>` | 操作哪种 K8s 资源 | `pod`, `deployment`, `service`, `ingress`, `configmap` |
| `[resource-name]` | 具体哪个资源（省略则列出所有） | `user-service-7d4f8c9b6-xk2lm` |
| `[flags]` | 额外选项 | `-n`, `-o`, `--tail`, `--previous` |

### 最常用的全局 flags / Most Common Global Flags

| flag | 全称 | 作用 | 示例 |
|------|------|------|------|
| `-n` | `--namespace` | 指定 namespace（不指定则用当前 context 的默认 ns） | `-n smart-invest` |
| `-o` | `--output` | 输出格式 | `-o wide`, `-o yaml`, `-o json` |
| `-w` | `--watch` | 持续监听变化（实时刷新，Ctrl+C 退出） | `-w` |
| `-l` | `--selector` | 按 label 过滤 | `-l app=user-service` |
| `--all-namespaces` | `-A` | 所有 namespace | `-A` |
| `-f` | `--filename` | 从 YAML 文件创建/应用资源 | `-f deployment.yaml` |
| `-k` | `--kustomize` | 用 Kustomize 目录 | `-k ./overlays/dev` |

---

## 一、Pod 相关 / Pod Operations

### 1. `kubectl get pods` — 列出 Pod

```bash
kubectl get pods [flags]
```

| flag | 作用 | 示例 |
|------|------|------|
| `-n` | 指定 namespace | `-n smart-invest` |
| `-A` | 所有 namespace | `-A` |
| `-o wide` | 输出更宽（含节点名、Pod IP） | `-o wide` |
| `-o yaml` | 完整 YAML 输出 | `-o yaml` |
| `-o json` | 完整 JSON 输出 | `-o json` |
| `-w` | 实时 watch 变化 | `-w` |
| `-l` | 按 label 过滤 | `-l app=user-service` |
| `--sort-by` | 按字段排序 | `--sort-by=.status.startTime` |
| `--field-selector` | 按字段过滤 | `--field-selector=status.phase=Running` |

**输出列含义：**
```
NAME                    READY   STATUS    RESTARTS   AGE
user-service-abc123     1/1     Running   0          2d
```
| 列 | 含义 |
|----|------|
| READY | `就绪容器数/总容器数`，`0/1` 表示 Readiness Probe 没通过 |
| STATUS | `Running`/`Pending`/`CrashLoopBackOff`/`ImagePullBackOff`/`Error`/`Completed` |
| RESTARTS | 重启次数——数字一直在涨 = 有问题！ |
| AGE | Pod 运行时长 |

**我的项目实际用法：**
```bash
# 日常巡检
kubectl get pods -n smart-invest -o wide

# 只看非 Running 的（排查用）
kubectl get pods -n smart-invest | grep -v Running

# 持续监控
kubectl get pods -n smart-invest -w
```

---

### 2. `kubectl describe pod` — Pod 详情 + 事件（排查首选！）

```bash
kubectl describe pod <pod-name> [flags]
```

| flag | 作用 |
|------|------|
| `-n` | 指定 namespace |

**输出包含的关键信息：**
| 段落 | 看什么 |
|------|--------|
| **Status** | Phase（Running/Pending/Failed）、Reason、Exit Code |
| **Containers → State** | 当前容器状态及原因（OOMKilled、Error、CrashLoopBackOff） |
| **Events** | **最关键的排查区域！** 记录 Pod 生命周期中的所有事件：拉镜像成功/失败、调度到哪个节点、容器启动/崩溃、探针失败 |

**Events 示例解读：**
```
Events:
  Type     Reason     Message
  ----     ------     -------
  Normal   Pulling    Pulling image "gongchengship/smart-invest-user-service:v1"
  Normal   Pulled     Successfully pulled image
  Warning  BackOff    Back-off restarting failed container ← 容器启动后崩溃
```

---

### 3. `kubectl logs` — 查看容器日志

```bash
kubectl logs <pod-name> [flags]
```

| flag | 作用 | 示例 |
|------|------|------|
| `-n` | 指定 namespace | `-n smart-invest` |
| `-c` | 指定容器名（Pod 有多个容器时必选） | `-c user-service` |
| `--tail` | 只看最后 N 行 | `--tail=200` |
| `-f` | 实时 tail（类似 `tail -f`，Ctrl+C 退出） | `-f` |
| `--previous` | **看上一次崩溃的容器日志（面试考点！）** | `--previous` |
| `--since` | 只看最近一段时间的日志 | `--since=5m` |
| `--timestamps` | 显示时间戳 | `--timestamps` |

**我的项目实际用法：**
```bash
# 查看当前日志
kubectl logs user-service-abc123 -n smart-invest --tail=200

# 查看上一次崩溃的日志（Pod 反复重启时必用！）
kubectl logs user-service-abc123 -n smart-invest --previous

# 实时追踪
kubectl logs -f user-service-abc123 -n smart-invest

# 补充：deployment 级别的日志（会自动选一个 Pod）
kubectl logs deployment/user-service -n smart-invest --tail=100
```

**面试核心：** 面试官必问 "--previous" 参数。Pod CrashLoopBackOff 时，当前容器可能刚启动还没报错，上一次崩溃的日志才有关键信息。

---

### 4. `kubectl exec` — 进入容器执行命令

```bash
kubectl exec [flags] <pod-name> -- <command>
```

| flag | 作用 | 示例 |
|------|------|------|
| `-n` | 指定 namespace | `-n smart-invest` |
| `-c` | 指定容器名 | `-c user-service` |
| `-it` | `-i`(stdin) + `-t`(tty)，交互式终端，进容器必加 | `-it` |
| `--` | 分隔 kubectl 参数和容器内命令（必须！） | `-- /bin/sh` |

**我的项目实际用法：**
```bash
# 进入容器
kubectl exec -it user-service-abc123 -n smart-invest -- /bin/sh

# 执行单条命令（不进入）
kubectl exec user-service-abc123 -n smart-invest -- cat /app/application.yml

# JVM 排查（如果 Pod 能短暂起来）
kubectl exec user-service-abc123 -n smart-invest -- jstack 1
kubectl exec user-service-abc123 -n smart-invest -- jmap -heap 1
```

**面试注意：** 面试官会问 "Pod 起不来时能 exec 进去吗？" → 不能！Pod 必须处于 Running 状态才能 exec。Pod 起不来时只能用 `kubectl logs --previous` + `kubectl describe pod`。

---

### 5. `kubectl top pod` — 查看 Pod 资源用量

```bash
kubectl top pod [pod-name] [flags]
```

| flag | 作用 |
|------|------|
| `-n` | 指定 namespace |
| `-A` | 所有 namespace |
| `--containers` | 显示每个容器的用量 |
| `-l` | 按 label 过滤 |

**用途：** 快速看哪个 Pod 吃 CPU/内存多，判断是否需要扩容或排查内存泄漏。

```bash
kubectl top pod -n smart-invest
kubectl top pod -n smart-invest --containers
```

---

## 二、Deployment 相关 / Deployment Operations

### 6. `kubectl get deployments` — 列出 Deployment

```bash
kubectl get deployments [flags]
```

| flag | 作用 |
|------|------|
| `-n` | 指定 namespace |
| `-A` | 所有 namespace |
| `-o wide` | 含镜像信息 |

**输出列含义：**
```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
user-service   1/1     1            1           5d
```
| 列 | 含义 |
|----|------|
| READY | `就绪副本数/期望副本数` |
| UP-TO-DATE | 已更新到最新版本的副本数 |
| AVAILABLE | 可用的副本数 |

---

### 7. `kubectl describe deployment` — Deployment 详情

```bash
kubectl describe deployment <deploy-name> [flags]
```

**输出关注点：**
- **Selector** — 匹配哪些 Pod
- **Replicas** — 期望/当前/就绪/可用副本数
- **Pod Template** — 镜像、端口、探针、环境变量、资源限制
- **Conditions** — Available / Progressing 状态
- **Events** — 扩容/缩容/滚动更新事件

---

### 8. `kubectl rollout` — 管理滚动更新和回滚

```bash
kubectl rollout <subcommand> deployment/<deploy-name> [flags]
```

| 子命令 | 作用 | 示例 |
|--------|------|------|
| `status` | 查看滚动更新进度 | `kubectl rollout status deployment/user-service -n smart-invest` |
| `history` | 查看部署历史（列出所有 revision） | `kubectl rollout history deployment/user-service -n smart-invest` |
| `undo` | 回滚到上一个版本 | `kubectl rollout undo deployment/user-service -n smart-invest` |
| `undo --to-revision` | 回滚到指定版本 | `kubectl rollout undo deployment/user-service -n smart-invest --to-revision=2` |
| `restart` | 重启所有 Pod（滚动重启） | `kubectl rollout restart deployment/user-service -n smart-invest` |
| `pause` | 暂停滚动更新 | `kubectl rollout pause deployment/user-service -n smart-invest` |
| `resume` | 恢复滚动更新 | `kubectl rollout resume deployment/user-service -n smart-invest` |

**kubectl rollout vs helm rollback 的区别：**

| | `kubectl rollout undo` | `helm rollback` |
|---|---|---|
| 粒度 | 回滚单个 Deployment | 回滚整个 Helm Release（所有资源） |
| 历史 | K8s ReplicaSet 历史 | Helm Release 历史 |
| 适用 | 快速的 Pod 层面回滚 | 完整的应用版本回滚 |

---

### 9. `kubectl scale` — 扩缩容

```bash
kubectl scale deployment/<deploy-name> --replicas=<N> [flags]
```

| flag | 作用 |
|------|------|
| `-n` | 指定 namespace |
| `--replicas` | 目标副本数 |

```bash
# 手动扩容到 3 个 Pod
kubectl scale deployment/user-service -n smart-invest --replicas=3

# 缩容到 1 个
kubectl scale deployment/user-service -n smart-invest --replicas=1
```

---

## 三、Service 相关 / Service Operations

### 10. `kubectl get svc` — 列出 Service

```bash
kubectl get svc [flags]
```

| flag | 作用 |
|------|------|
| `-n` | 指定 namespace |
| `-A` | 所有 namespace |
| `-o wide` | 含 Selector |

**输出列含义：**
```
NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
user-service   ClusterIP   10.43.120.88    <none>        8081/TCP   5d
```
| 列 | 含义 |
|----|------|
| TYPE | ClusterIP（集群内部）/ NodePort（节点端口）/ LoadBalancer（云 LB） |
| CLUSTER-IP | 集群内部 IP（其他 Pod 通过这个 IP 或 DNS 访问） |
| PORT(S) | `Service端口:Pod端口/协议` |

---

### 11. `kubectl get endpoints` — 检查 Service 后端 Pod（排查关键！）

```bash
kubectl get endpoints <svc-name> [flags]
```

| flag | 作用 |
|------|------|
| `-n` | 指定 namespace |

**输出解读：**
```
NAME           ENDPOINTS           AGE
user-service   10.42.0.15:8081     5d
```
- 有 IP:Port → Service 正常，有后端 Pod
- `<none>` → **问题！** Service 没有匹配到任何 Ready Pod。原因可能是：
  - Pod labels 和 Service selector 不匹配
  - Readiness Probe 没通过，Pod 被摘除
  - 没有 Pod 在运行

**这是排查 "Service 不通" 最常见的原因，面试必问！**

---

### 12. `kubectl describe svc` — Service 详情

```bash
kubectl describe svc <svc-name> [flags]
```

**关注点：** Selector、Type、Port、Endpoints（确认不为空）、Session Affinity。

---

## 四、配置与密钥 / ConfigMaps & Secrets

### 13. `kubectl get configmap` / `kubectl describe configmap`

```bash
kubectl get configmap [flags]
kubectl describe configmap <name> [flags]
kubectl get configmap <name> -o yaml
```

**用途：** 查看应用的环境变量配置，排查 "配置不对导致 Pod 起不来"。

---

### 14. `kubectl get secrets`

```bash
kubectl get secrets [flags]
kubectl describe secret <name> [flags]
kubectl get secret <name> -o jsonpath='{.data.SPRING_DATASOURCE_PASSWORD}' | base64 -d
```

**用途：** 确认 Secret 是否存在、内容是否正确（注意要先 base64 解码）。

**我的项目中的 Secret：** [secret.yaml](infrastructure/helm-charts/umbrella/templates/secret.yaml) 定义了 `smart-invest-secrets` — 包含数据库密码、JWT Secret、RabbitMQ 密码。

---

## 五、网络排查 / Network Troubleshooting

### 15. `kubectl get ingress` — 检查外部流量入口

```bash
kubectl get ingress [flags]
kubectl describe ingress <name> [flags]
```

**我的项目中的 Ingress：** [ingress.yaml](infrastructure/helm-charts/umbrella/templates/ingress.yaml)
```
/    → frontend:80
/api → api-gateway:8080
```

---

### 16. `kubectl get networkpolicies` — 检查网络策略

```bash
kubectl get networkpolicies [flags]
kubectl describe networkpolicy <name> [flags]
```

**用途：** 如果 Service 有 Endpoints 但还是不通，检查是否有 NetworkPolicy 阻断了流量。

---

### 17. `kubectl run` 临时调试 Pod — 网络排查神器

```bash
kubectl run <临时名字> --image=<镜像> -it --rm -- [命令] [flags]
```

| flag | 作用 |
|------|------|
| `-n` | 指定 namespace |
| `-it` | 交互式终端 |
| `--rm` | 退出后自动删除（不留垃圾 Pod） |
| `--image` | 用什么镜像（推荐 `nicolaka/netshoot`，自带网络工具全家桶） |
| `--restart` | Never（只跑一次）/ OnFailure / Always |

```bash
# 创建临时 Pod 做网络排查
kubectl run debug --image=nicolaka/netshoot -it --rm -n smart-invest -- /bin/bash

# 在 debug Pod 里测试：
nslookup user-service.smart-invest.svc.cluster.local   # DNS 解析
curl -v http://user-service:8081/actuator/health       # HTTP 连通
telnet order-service 8083                              # TCP 端口测试
ping 10.42.0.15                                        # ICMP
traceroute fund-service.smart-invest.svc.cluster.local # 路由追踪
```

---

## 六、资源管理 / Resource Management

### 18. `kubectl apply` — 声明式创建/更新资源

```bash
kubectl apply -f <file-or-dir> [flags]
```

| flag | 作用 |
|------|------|
| `-f` | 指定文件或目录 | `-f deployment.yaml` |
| `-k` | Kustomize 目录 | `-k ./overlays/dev` |
| `--dry-run=client` | 本地验证（不提交到集群） | `--dry-run=client` |
| `--dry-run=server` | 服务端验证（提交到 API Server 但不持久化） | `--dry-run=server` |

---

### 19. `kubectl delete` — 删除资源

```bash
kubectl delete <resource-type> <name> [flags]
```

| flag | 作用 |
|------|------|
| `-n` | 指定 namespace |
| `-f` | 从文件删除 | `-f deployment.yaml` |
| `--grace-period` | 优雅删除等待秒数（0 = 立刻强制） | `--grace-period=30` |
| `--force` | 强制删除 | `--force` |
| `-l` | 按 label 删除 | `-l app=user-service` |

---

### 20. `kubectl edit` — 直接编辑集群中的资源

```bash
kubectl edit <resource-type> <name> [flags]
```

**用途：** 紧急情况下直接在线改 ConfigMap / Deployment 配置（生产环境慎用，建议改 Git 后走 CI/CD）。

```bash
kubectl edit configmap user-config -n smart-invest
kubectl edit deployment user-service -n smart-invest
```

---

## 七、节点与集群 / Nodes & Cluster

### 21. `kubectl get nodes` — 节点状态

```bash
kubectl get nodes [flags]
```

| flag | 作用 |
|------|------|
| `-o wide` | 含节点 IP、OS、内核版本、容器运行时 |
| `--show-labels` | 显示节点 labels |

**STATUS 列：** `Ready` = 正常，`NotReady` = 有问题，`SchedulingDisabled` = 被 cordon 了。

---

### 22. `kubectl describe node` — 节点详情

```bash
kubectl describe node <node-name>
```

**关注点：**
- **Conditions** — MemoryPressure / DiskPressure / PIDPressure / Ready
- **Allocated resources** — 已分配 vs 总容量（CPU/内存的 requests 和 limits）
- **Events** — 节点级别的异常事件

---

### 23. `kubectl cordon` / `kubectl drain` — 节点维护

| 命令 | 作用 |
|------|------|
| `kubectl cordon <node>` | 标记节点为不可调度（新 Pod 不会调度到这，已有 Pod 不受影响） |
| `kubectl uncordon <node>` | 恢复节点为可调度 |
| `kubectl drain <node> --ignore-daemonsets` | 驱逐节点上所有 Pod（用于节点维护前迁移工作负载） |

---

## 八、事件与审计 / Events & Auditing

### 24. `kubectl get events` — 查看集群事件（排查神器）

```bash
kubectl get events [flags]
```

| flag | 作用 | 示例 |
|------|------|------|
| `-n` | 指定 namespace | `-n smart-invest` |
| `-A` | 所有 namespace | `-A` |
| `--sort-by` | 排序 | `--sort-by='.lastTimestamp'` |
| `-w` | 实时监听事件 | `-w` |

**最实用的排查命令（按时间倒序，只看最后 50 条）：**
```bash
kubectl get events -n smart-invest --sort-by='.lastTimestamp' | tail -50
```

---

## 九、上下文与配置 / Context & Config

### 25. `kubectl config` — 管理 kubeconfig

| 命令 | 作用 |
|------|------|
| `kubectl config view` | 查看当前 kubeconfig 内容 |
| `kubectl config get-contexts` | 列出所有可用的 context（集群+用户+namespace 组合） |
| `kubectl config current-context` | 显示当前使用的 context |
| `kubectl config use-context <name>` | 切换到指定 context |
| `kubectl config set-context --current --namespace=<ns>` | 切换当前 context 的默认 namespace |

---

## 十、输出格式化 / Output Formatting

### 26. `-o` 参数详解

| 值 | 作用 | 示例 |
|----|------|------|
| `wide` | 显示额外列（IP、节点名） | `kubectl get pods -o wide` |
| `yaml` | 完整 YAML 输出 | `kubectl get deployment user-service -o yaml` |
| `json` | 完整 JSON 输出 | `kubectl get pod user-service-abc123 -o json` |
| `jsonpath` | 提取特定字段 | 见下方 |
| `name` | 只输出资源名 | `kubectl get pods -o name` |
| `custom-columns` | 自定义列 | `kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase` |

**jsonpath 提取字段（面试加分项）：**
```bash
# 获取所有 Pod 的镜像
kubectl get pods -n smart-invest -o jsonpath='{.items[*].spec.containers[*].image}'

# 获取 Pod 的内网 IP
kubectl get pods -n smart-invest -o jsonpath='{.items[*].status.podIP}'

# 获取 Secret 的某个 key 的值（自动解码）
kubectl get secret smart-invest-secrets -n smart-invest \
  -o jsonpath='{.data.SPRING_DATASOURCE_PASSWORD}' | base64 -d
```

---

## 十一、完整排查流程 / Complete Troubleshooting Flows

### 场景 A：Pod CrashLoopBackOff

```bash
# Step 1: 看 Pod 状态
kubectl get pods -n smart-invest

# Step 2: 看 Events（OOM? 镜像拉取失败? 探针挂了?）
kubectl describe pod <bad-pod> -n smart-invest

# Step 3: 看日志——包括上次崩溃的
kubectl logs <bad-pod> -n smart-invest --tail=200
kubectl logs <bad-pod> -n smart-invest --previous

# Step 4: 检查配置
kubectl get configmap -n smart-invest
kubectl get secret -n smart-invest
kubectl describe deployment/<svc> -n smart-invest

# Step 5: 如果临时绕过
kubectl edit configmap <name> -n smart-invest
kubectl rollout restart deployment/<svc> -n smart-invest
```

### 场景 B：Service 访问不通

```bash
# Step 1: Service 存在吗?
kubectl get svc -n smart-invest

# Step 2: 有 Endpoints 吗?（最关键！<none> 就是问题）
kubectl get endpoints <svc> -n smart-invest

# Step 3: Pod Ready?
kubectl get pods -n smart-invest | grep <svc>

# Step 4: DNS 能解析吗?
kubectl run test-dns --image=busybox -it --rm -- \
  nslookup user-service.smart-invest.svc.cluster.local

# Step 5: 网络策略
kubectl get networkpolicies -n smart-invest

# Step 6: 实测连通
kubectl run test-conn --image=nicolaka/netshoot -it --rm -- \
  curl -v http://user-service:8081/actuator/health
```

### 场景 C：最近的部署出了问题需要回滚

```bash
# Step 1: 确认哪个 deploy 有问题
kubectl get pods -n smart-invest

# Step 2: 看部署历史
kubectl rollout history deployment/user-service -n smart-invest

# Step 3: 回滚
kubectl rollout undo deployment/user-service -n smart-invest --to-revision=2

# Step 4: 确认恢复
kubectl rollout status deployment/user-service -n smart-invest
kubectl get pods -n smart-invest
```

---

> **面试重点：**
> 1. `--previous` 参数是排查 CrashLoopBackOff 的关键——面试官一定会问到
> 2. Service 不通→先看 Endpoints——90% 的问题出在这
> 3. 排查顺序：`get` → `describe` → `logs --previous` → `exec`（如果 Pod 能起来）
> 4. 临时排查 Pod 用 `kubectl run debug --image=nicolaka/netshoot -it --rm`
> 5. `jsonpath` 提取字段是体现熟练度的加分项
