# Helm Deployment Issues Record

---

## 0. Recommended Monitoring Commands During Deployment
```
# helm upgrade --install 执行期间几乎不输出细节，建议另开终端窗口同时监控：

➜  /Users/gcsp/coding/claude_code_workspace/smart-invest/infrastructure/helm/umbrella git:(master) ✗  ➜
helm upgrade --install smart-invest . \
 --namespace smart-invest --create-namespace \
 --atomic --timeout 1200s
```


```bash
# 窗口 2：实时观察 Pod 状态变化（最常用）
kubectl -n smart-invest get pods -w

# 窗口 3：实时观察 K8S 事件流（比 pod watch 更细粒度，能看到调度失败、拉镜像失败等）
kubectl -n smart-invest get events -w --sort-by='.lastTimestamp'

# 窗口 4：观察 Node 资源使用（确认是不是 CPU/内存不够导致 Pod 调度不上）
watch kubectl top nodes
```

这样四窗口一排，相当于 K8S 版的"活动监视器"，不用干等 `--atomic` 超时。

---

## 1. Issue 1: pre-install Hook DNS Resolution Failure

### 1.1. Symptom
```
➜  /Users/gcsp/coding/claude_code_workspace/smart-invest/infrastructure/helm/umbrella git:(master) ✗  ➜
helm upgrade --install smart-invest . \
 --namespace smart-invest --create-namespace \
 --atomic --timeout 1200s
Release "smart-invest" does not exist. Installing it now.
Error: release smart-invest failed, and has been uninstalled due to atomic being set: failed pre-install: 1 error occurred:
* job smart-invest-rabbitmq-ready-check failed: BackoffLimitExceeded
```

### 1.2. Investigation

```bash
# 看 Pod 状态
➜  /Users/gcsp  ➜
kubectl -n smart-invest get pods -w
NAME                                      READY   STATUS    RESTARTS   AGE
smart-invest-rabbitmq-ready-check-7v7hc   0/1     Error     0          5m15s
smart-invest-rabbitmq-ready-check-g7b86   0/1     Error     0          2m55s
smart-invest-rabbitmq-ready-check-jkll9   0/1     Error     0          7m31s
smart-invest-rabbitmq-ready-check-mcgpm   1/1     Running   0          14s
smart-invest-rabbitmq-ready-check-mcgpm   0/1     Error     0          2m1s

# 查 Job 日志定位报错
➜  /Users/gcsp  ➜
kubectl -n smart-invest logs job/smart-invest-rabbitmq-ready-check
>>> 等待 RabbitMQ 就绪...
nc: bad address 'rabbitmq'
⏳ 第 1 次检查：RabbitMQ 还未就绪，5 秒后重试...
nc: bad address 'rabbitmq'
⏳ 第 2 次检查：RabbitMQ 还未就绪，5 秒后重试...
```

如果 Job 已被 `--atomic` 回滚清理，也可以直接查 Pod 日志：
```bash
kubectl -n smart-invest logs smart-invest-rabbitmq-ready-check-jkll9
```

### 1.3. Root Cause

Hook 注解写的是 `"helm.sh/hook": pre-install,pre-upgrade`，意味着这个 Hook Job 在**所有资源（包括 RabbitMQ 的 Service 和 Deployment）创建之前**就执行了。

此时 `rabbitmq` 这个 K8S Service 根本不存在，CoreDNS 无法解析，`nc -z rabbitmq 5672` 必然报 `bad address`。

```
Helm install 流程：
  ① 渲染所有模板
  ② 执行 pre-install hooks        ← rabbitmq-ready-check 在这里跑
  ③ 创建所有 K8S 资源             ← rabbitmq Service 在这里才诞生
```

Hook 在 ② 尝试连接 ③ 才创建的东西，永远连不上。

### 1.4. Fix

**File:** `infrastructure/helm/umbrella/templates/rabbitmq-ready-hook.yaml`

```diff
-    "helm.sh/hook": pre-install,pre-upgrade
+    "helm.sh/hook": post-install,post-upgrade
```

```diff
-    backoffLimit: 3
+    backoffLimit: 5
```

`post-install` 在所有 K8S 资源创建之后才执行，此时 rabbitmq Service 已存在，DNS 可解析。

---

## 2. Issue 2: Deprecated Ingress Annotation + Hook Job Residue

### 2.1. Symptom
```
➜  /Users/gcsp/coding/claude_code_workspace/smart-invest/infrastructure/helm/umbrella git:(master) ✗  ➜
helm upgrade --install smart-invest . \
 --namespace smart-invest --create-namespace \
 --atomic --timeout 1200s
Release "smart-invest" does not exist. Installing it now.
I0811 21:07:31.651891   40746 warnings.go:107] "Warning: annotation \"kubernetes.io/ingress.class\" is deprecated, please use 'spec.ingressClassName' instead"
Error: release smart-invest failed, and has been uninstalled due to atomic being set: failed post-install: warning: Hook post-install smart-invest/templates/rabbitmq-ready-hook.yaml failed: 1 error occurred:
	* jobs.batch "smart-invest-rabbitmq-ready-check" already exists
```

### 2.2. Investigation

错误信息很直接——`jobs.batch "smart-invest-rabbitmq-ready-check" already exists`——说明集群里已经有一个同名的 Job。但需要确认**这个 Job 为什么还在、是不是上一轮残留的、以及它的 Pod 内部发生了什么**。

| 步骤 | 命令 | 为什么用 |
|------|------|---------|
| 第一步 | `kubectl get all` | 一次性看所有残留资源，从 AGE 判断是上一轮的 |
| 第二步 | `kubectl describe job` | 看 Job 完整事件时间线——所有 Pod 都 Error → BackoffLimitExceeded |
| 第三步 | `kubectl logs job/` | 确认 Pod 内部报错内容和 Issue 1 一致，证实是残留的旧 Job |


**第一步：列出所有资源，确认 Job 是否真的残留**

```bash
➜  kubectl -n smart-invest get all
NAME                                          READY   STATUS   RESTARTS   AGE
pod/smart-invest-rabbitmq-ready-check-7v7hc   0/1     Error    0          28m
pod/smart-invest-rabbitmq-ready-check-g7b86   0/1     Error    0          26m
pod/smart-invest-rabbitmq-ready-check-jkll9   0/1     Error    0          30m
pod/smart-invest-rabbitmq-ready-check-mcgpm   0/1     Error    0          23m

NAME                                          STATUS   COMPLETIONS   DURATION   AGE
job.batch/smart-invest-rabbitmq-ready-check   Failed   0/1           30m        30m
```

> **为什么用 `kubectl get all`？** 上一轮 `--atomic` 回滚后 namespace 可能被清理过，用 `get all` 一次性看到所有残留资源（Pod、Job、Service 等）。如果 Job 还在，时间戳（AGE）会告诉你它是上一轮遗留的。

**第二步：describe Job 看事件历史**

```bash
➜  kubectl -n smart-invest describe job smart-invest-rabbitmq-ready-check
Events:
  Type     Reason                Age   From            Message
  ----     ------                ----  ----            -------
  Normal   SuccessfulCreate      30m   job-controller  Created pod: smart-invest-rabbitmq-ready-check-jkll9
  Normal   SuccessfulCreate      28m   job-controller  Created pod: smart-invest-rabbitmq-ready-check-7v7hc
  Normal   SuccessfulCreate      26m   job-controller  Created pod: smart-invest-rabbitmq-ready-check-g7b86
  Normal   SuccessfulCreate      23m   job-controller  Created pod: smart-invest-rabbitmq-ready-check-mcgpm
  Warning  BackoffLimitExceeded  21m   job-controller  Job has reached the specified backoff limit
```

> **为什么用 `describe`？** `get pods` 只能看到 Pod 列表，`describe job` 能看到这个 Job **完整的事件时间线**——什么时候创建了哪些 Pod、什么时候达到重试上限。这里 4 个 Pod 全部 Error，最后 `BackoffLimitExceeded`，说明是 Issue 1 修复前的那一轮留下的失败 Job。

**第三步：查 Pod 日志确认具体报错**

```bash
➜  kubectl -n smart-invest logs job/smart-invest-rabbitmq-ready-check
>>> 等待 RabbitMQ 就绪...
nc: bad address 'rabbitmq'
⏳ 第 1 次检查：RabbitMQ 还未就绪，5 秒后重试...
...
❌ RabbitMQ 120 秒后仍未就绪，部署中止
```

> **为什么用 `logs`？** `describe` 告诉你 Job 失败了，`logs` 告诉你**为什么**失败。这里确认了日志内容和 Issue 1 完全一致（`bad address`），证实这就是上一轮修复前的残留 Job。

### 2.3. Root Cause

这次报错包含两个独立问题：

**Issue A: Deprecated Ingress Annotation**

`kubernetes.io/ingress.class` 注解已被 K8S 废弃（deprecated），应改用 `spec.ingressClassName` 字段。

> **怎么发现的？** Helm 直接在输出中打印了 warning：`Warning: annotation "kubernetes.io/ingress.class" is deprecated`。K8S 在 Helm 渲染模板时通过 `warnings.go` 检测到废弃 API 用法并输出。不需要额外排查——Helm 自己告诉你的。

**Issue B: Hook Job Residue**

上一轮 `--atomic` 回滚时没有清理失败的 Hook Job。`hook-delete-policy: hook-succeeded` 只在**成功**时删除，失败的 Job 会残留在集群中。下一轮 `helm install` 再次创建同名 Job 时，K8S 发现 `jobs.batch "smart-invest-rabbitmq-ready-check" already exists`，直接报错。

### 2.4. Fix

**Issue A:** `infrastructure/helm/umbrella/templates/ingress.yaml`

```diff
  annotations:
-   kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.middlewares: ""

  spec:
+   ingressClassName: traefik
```

**Issue B:** Manually delete the leftover failed Job

```bash
kubectl -n smart-invest delete job smart-invest-rabbitmq-ready-check
```

> **Lesson:** `hook-delete-policy: hook-succeeded` does not clean up failed Hooks. When using `--atomic` (which auto-rolls back on failure), leftover Hook Jobs can block subsequent installs. Consider adding `before-hook-creation` policy:
> ```yaml
> "helm.sh/hook-delete-policy": hook-succeeded,before-hook-creation
> ```
> 这样每次创建新 Hook 前会先删掉旧的，避免 "already exists" 错误。

---

## 3. Issue 3: Same "already exists" Error After Fix — Why Code Fixes Aren't Enough

### 3.1. Symptom
```
➜  /Users/gcsp/coding/claude_code_workspace/smart-invest/infrastructure/helm/umbrella git:(master)  ➜
helm upgrade --install smart-invest . \
 --namespace smart-invest --create-namespace \
 --atomic --timeout 1200s
Release "smart-invest" does not exist. Installing it now.
Error: release smart-invest failed, and has been uninstalled due to atomic being set: failed post-install: warning: Hook post-install smart-invest/templates/rabbitmq-ready-hook.yaml failed: 1 error occurred:
	* jobs.batch "smart-invest-rabbitmq-ready-check" already exists
```

明明代码已经修好了（Issue 1 的 `pre-install`→`post-install`、Issue 2 的 `ingressClassName`），为什么还是同一个错误？

### 3.2. 通俗解释：代码修好了，为什么还报错？

用一个 Java 程序员熟悉的场景来类比：

```
想象你有一个 Spring Boot 应用，启动时依赖数据库。

你改了 DataSourceConfig.java（相当于我们改 Helm 模板），
但你部署前忘记重启数据库（相当于我们没清理集群里的残留 Job）。

你觉得代码改了，重新 mvn package 再 java -jar 就行——
但数据库没变，它里面还留着上一次失败的锁表记录。

Helm 的情况也类似：
  - 模板文件是「源代码」—— 你改了，本地的 .yaml 是最新的
  - K8S 集群是「运行时状态」—— 你本地代码改了，集群里的脏数据还在
  - helm upgrade 不是删了重建，它是把源代码「apply」到集群
  - 同名资源已存在 → K8S 拒绝创建 → 就像 INSERT 遇到 duplicate key
```

**核心概念：Helm 的代码 ≠ K8S 集群的状态**

| Java 世界 | Helm 世界 |
|-----------|-----------|
| 源代码（`.java` 文件） | 模板文件（`templates/*.yaml`） |
| 编译产物（`.jar`） | Chart 渲染结果 |
| 运行时（JVM 进程） | K8S 集群中的资源（Pod、Job、Service...） |
| `DROP TABLE` / `DELETE` | `kubectl delete job xxx` |
| 数据库 migration 脚本 | `kubectl apply` / `helm upgrade` |

你改了 `.java`，不 `DROP TABLE` 脏数据，启动还是报错。同样，你改了模板，不删集群里的残留 Job，`helm upgrade` 还是报 `already exists`。

### 3.3. Root Cause

上一轮 `helm install` 失败后，`--atomic` 触发了自动回滚（rollback）。但是：

- `--atomic` 回滚的是 **Helm Release**（Helm 自己的记录），不是 K8S 资源
- Hook Job 上有 `"helm.sh/hook-delete-policy": hook-succeeded`，意思是 **只在成功时才删**
- 失败的 Job → 不会被删 → 残留在集群中
- 下一轮 `helm install` 尝试创建同名 Job → K8S API Server 返回 409 Conflict → `already exists`

```
第一轮：
  helm install → 创建 Job "abc" → Job 失败 → --atomic 回滚 Release
  → Release 删了，但 Job "abc" 留在集群里！

第二轮：
  helm install → 又尝试创建 Job "abc" → K8S: "这名字已经有人用！" → 报错
```

这就好比你执行 `DROP DATABASE` 时有个表没删干净，第二次 `CREATE DATABASE` 就报 `database already exists`。

### 3.4. Fix

**短期（手动急救）：**

```bash
kubectl -n smart-invest delete job smart-invest-rabbitmq-ready-check
```

**长期（从源头杜绝）：**

在 `rabbitmq-ready-hook.yaml` 的 `hook-delete-policy` 中加上 `before-hook-creation`：

```diff
-    "helm.sh/hook-delete-policy": hook-succeeded
+    "helm.sh/hook-delete-policy": hook-succeeded,before-hook-creation
```

这样每次 Helm 创建新的 Hook Job 之前，会**先删掉同名的旧 Job**，不会再撞名字。相当于每次 `INSERT` 前自动执行 `DELETE WHERE name = ?`。

### 3.5. Key Takeaway for Helm Beginners

> **改完模板 ≠ 部署成功。集群里的脏数据不会自动消失。**
>
> 排查问题时，先区分是「模板写错了」还是「集群里有脏东西」：
> - `helm template .` 可以本地渲染看看有没有语法错误
> - `kubectl get all -n <ns>` 可以看集群里有什么残留资源
> - 两者都可能是报错的来源，别只盯着代码

---

## 4. Deployment Success: Reading the Output and Next Steps

### 4.1. The Successful Output

```
➜  /Users/gcsp/coding/claude_code_workspace/smart-invest/infrastructure/helm/umbrella git:(master) ✗  ➜
helm upgrade --install smart-invest . \
 --namespace smart-invest --create-namespace \
 --atomic --timeout 1200s
Release "smart-invest" does not exist. Installing it now.
NAME: smart-invest
LAST DEPLOYED: Tue Aug 11 21:41:25 2026
NAMESPACE: smart-invest
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

### 4.2. What Each Field Means

| 字段 | 值 | 含义 |
|------|-----|------|
| **NAME** | `smart-invest` | Release 名称——Helm 给这次部署起的名字。之后所有操作（升级、回滚、删除）都用这个名字引用 |
| **LAST DEPLOYED** | `Tue Aug 11 21:41:25 2026` | 部署完成时间——之后可以拿这个时间戳去日志系统里定位 |
| **NAMESPACE** | `smart-invest` | 所有资源都在这个 K8S namespace 下，和其他项目隔离 |
| **STATUS** | `deployed` | **最重要的字段**——`deployed` = 成功，`failed` = 看日志。Helm 认为 Release 的所有步骤都通过了 |
| **REVISION** | `1` | 版本号——每次 `helm upgrade` 会 +1。`helm rollback smart-invest 0` 可以回到这个版本 |
| **TEST SUITE** | `None` | 没有定义 Helm test（`helm test smart-invest` 会跑测试 Pod）。你的 Chart 里目前没有测试资源，所以显示 None |

### 4.3. What "STATUS: deployed" Actually Means

"deployed" ≠ "一切正常运行"。它只说明：

- ✅ Helm 模板渲染成功（语法没错误）
- ✅ 所有 K8S 资源创建成功（没有 "already exists" 之类的冲突）
- ✅ Hook Job 执行成功（rabbitmq-ready-check 通过了）
- ❌ **不代表** Pod 都在健康运行——Pod 可能还在拉镜像、可能在 CrashLoopBackOff

> **类比 Spring Boot：** `STATUS: deployed` 相当于 `ApplicationStartedEvent`——应用启动流程走了，不代表业务逻辑没 bug。你还是得看 Pod 实际状态。

### 4.4. Immediate Next Steps After Successful Deploy

**第一步：验证 Pod 是否真的在跑（最重要！）**

```bash
kubectl -n smart-invest get pods
```

期望看到所有 Pod `STATUS` 都是 `Running`，`READY` 列的容器数都达标（如 `1/1`）。

如果有些是 `CrashLoopBackOff` 或 `ImagePullBackOff`，马上看日志：

```bash
kubectl -n smart-invest logs <pod-name>
```

**第二步：验证 Service 是否暴露了端口**

```bash
kubectl -n smart-invest get svc
```

确认各 Service 的 `CLUSTER-IP` 已分配，端口映射正确。

**第三步：验证 Ingress 是否生效**

```bash
kubectl -n smart-invest get ingress
```

如果配置了 Ingress + Traefik，确认 `ADDRESS` 字段已经分配了 IP。

**第四步：在浏览器里打开应用**

如果是 K3S 集群 + NodePort/LoadBalancer：

```bash
# 找到 Traefik 的 NodePort 或 EXTERNAL-IP
kubectl -n kube-system get svc traefik
```

然后浏览器访问 `http://<EC2-公网IP>:<端口>`。

**第五步：持续关注一段时间**

```bash
kubectl -n smart-invest get pods -w
```

刚部署完是最容易出问题的时候——镜像拉取、健康检查、资源分配都在这个阶段。盯一会儿，确认所有 Pod 稳定在 `Running`。

### 4.5. Useful Follow-up Commands Cheat Sheet

```bash
# 看 Helm Release 历史（每次 install/upgrade 一个版本）
helm -n smart-invest history smart-invest

# 看 Helm 渲染出来的实际 K8S YAML（debug 用）
helm -n smart-invest get manifest smart-invest | less

# 看 Release 当前的 values（含默认值）
helm -n smart-invest get values smart-invest

# 如果要回滚到上一个版本
helm -n smart-invest rollback smart-invest

# 如果要全部删掉重装
helm -n smart-invest uninstall smart-invest
```

---

