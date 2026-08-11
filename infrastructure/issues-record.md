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
