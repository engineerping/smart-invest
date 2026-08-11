1.waht happened:
➜  /Users/gcsp/coding/claude_code_workspace/smart-invest/infrastructure/helm/umbrella git:(master) ✗  ➜
helm upgrade --install smart-invest . \
>  --namespace smart-invest --create-namespace \
>  --atomic --timeout 1200s
Release "smart-invest" does not exist. Installing it now.
Error: release smart-invest failed, and has been uninstalled due to atomic being set: failed pre-install: 1 error occurred:
* job smart-invest-rabbitmq-ready-check failed: BackoffLimitExceeded

1.1. what did I do:
1.1.1:
➜  /Users/gcsp  ➜
kubectl -n smart-invest get pods -w
NAME                                      READY   STATUS    RESTARTS   AGE
smart-invest-rabbitmq-ready-check-7v7hc   0/1     Error     0          5m15s
smart-invest-rabbitmq-ready-check-g7b86   0/1     Error     0          2m55s
smart-invest-rabbitmq-ready-check-jkll9   0/1     Error     0          7m31s
smart-invest-rabbitmq-ready-check-mcgpm   1/1     Running   0          14s
smart-invest-rabbitmq-ready-check-mcgpm   0/1     Error     0          2m1s
smart-invest-rabbitmq-ready-check-mcgpm   0/1     Error     0          2m2s
smart-invest-rabbitmq-ready-check-mcgpm   0/1     Error     0          2m3s

1.1.2.
```
➜  /Users/gcsp  ➜
kubectl -n smart-invest logs job/smart-invest-rabbitmq-ready-check
Found 4 pods, using pod/smart-invest-rabbitmq-ready-check-jkll9
>>> 等待 RabbitMQ 就绪...
nc: bad address 'rabbitmq'
⏳ 第 1 次检查：RabbitMQ 还未就绪，5 秒后重试...
nc: bad address 'rabbitmq'
⏳ 第 2 次检查：RabbitMQ 还未就绪，5 秒后重试...
nc: bad address 'rabbitmq'
```

这会打印 Job 创建的最后一个 Pod 的日志。因为 Hook 的 Pod 都是同一个 Job 创建的，查 Job 日志就能看到里面的 nc: bad address 'rabbitmq' 错误。
如果 Job 已经删了（--atomic 失败会回滚清理），也可以直接查某个 Pod：

```
➜  /Users/gcsp  ➜
kubectl -n smart-invest logs smart-invest-rabbitmq-ready-check-jkll9
>>> 等待 RabbitMQ 就绪...
nc: bad address 'rabbitmq'
⏳ 第 1 次检查：RabbitMQ 还未就绪，5 秒后重试...
nc: bad address 'rabbitmq'
⏳ 第 2 次检查：RabbitMQ 还未就绪，5 秒后重试...
nc: bad address 'rabbitmq'
⏳ 第 3 次检查：RabbitMQ 还未就绪，5 秒后重试...
nc: bad address 'rabbitmq'
```

1.3. root cause

 告诉 Helm："这个资源不是普通的 K8S 资源，是 Hook"    
 pre-install：helm install 时执行    
 pre-upgrade：helm upgrade 时也执行

 ─── "helm.sh/hook-weight": "5" ───    
 Hook 执行顺序（数字越小越先执行）。


1.4. how does it got fixed

1.4.1.
/Users/gcsp/coding/claude_code_workspace/smart-invest/infrastructure/helm/umbrella/templates/rabbitmq-ready-hook.yaml
```
-    "helm.sh/hook": pre-install,pre-upgrade
+    "helm.sh/hook": post-install,post-upgrade
```

1.4.2.
/Users/gcsp/coding/claude_code_workspace/smart-invest/infrastructure/helm/umbrella/templates/rabbitmq-ready-hook.yaml:58
spec:
# ─── backoffLimit: 重试次数 ───
# 3 次重试如果都失败 → Hook 失败 → helm install 失败

```
-    backoffLimit: 3
+    backoffLimit: 5
```