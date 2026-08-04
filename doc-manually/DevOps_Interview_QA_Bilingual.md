# DevOps 工程师面试题集（中英双语）

# DevOps Engineer Interview Questions (Bilingual)

> 基于 Hydsoft Technology DevOps 岗位 JD、前同事实际工作内容及面试重点提示整理
> Based on Hydsoft Technology DevOps JD, former colleague's actual work scope, and interview focus tips

---

## 一、Jenkins Pipeline 实操 / Jenkins Pipeline Hands-on

### Q1: Jenkins Pipeline 有哪两种模式？它们的区别是什么？

Jenkins Pipeline 有两种定义模式：**Declarative Pipeline（声明式）** 和 **Scripted Pipeline（脚本式）**。

| | Declarative | Scripted |
|---|---|---|
| 语法 | 结构化、受约束的 DSL，必须在 `pipeline {}` 块内 | 基于 Groovy 的灵活脚本，在 `node {}` 块内 |
| 入门难度 | 更简单，适合大多数场景 | 更灵活，但需要 Groovy 知识 |
| 代码校验 | 启动时解析并报错 | 运行时才报错 |
| 代码复用 | 不支持循环/条件逻辑内嵌 stage（需用 script 块转义） | 原生支持 Groovy 逻辑 |
| 蓝海视图 | stage 自动展示 | 需手动标记 |
| 适用场景 | 标准化 CI/CD 流水线 | 复杂自定义逻辑 |

**Declarative 示例：**
```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
        stage('Test') {
            steps {
                sh 'mvn test'
            }
        }
    }
    post {
        failure { emailext body: 'Failed', subject: 'Build Failed', to: 'team@example.com' }
    }
}
```

**Scripted 示例：**
```groovy
node {
    stage('Build') {
        sh 'mvn clean package'
    }
    stage('Test') {
        sh 'mvn test'
    }
}
```

---

### Q1: What are the two modes of Jenkins Pipeline? What are the differences?

There are two definition modes: **Declarative Pipeline** and **Scripted Pipeline**.

| | Declarative | Scripted |
|---|---|---|
| Syntax | Structured, constrained DSL inside `pipeline {}` | Flexible Groovy-based script inside `node {}` |
| Learning curve | Easier, suits most scenarios | More flexible, requires Groovy knowledge |
| Error detection | Fails at parse time (startup) | Fails at runtime |
| Code reuse | No native loops/conditionals in stages (need `script {}` escape) | Native Groovy logic support |
| Blue Ocean | Stages auto-displayed | Manual markup needed |
| Use case | Standardized CI/CD pipelines | Complex custom logic |

**Declarative example:**
```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
        stage('Test') {
            steps {
                sh 'mvn test'
            }
        }
    }
    post {
        failure { emailext body: 'Failed', subject: 'Build Failed', to: 'team@example.com' }
    }
}
```

**Scripted example:**
```groovy
node {
    stage('Build') {
        sh 'mvn clean package'
    }
    stage('Test') {
        sh 'mvn test'
    }
}
```

---

### Q2: 什么是 Jenkins Shared Library？你在前公司是怎样使用的？

**答案：**
Jenkins Shared Library 是将可复用的流水线代码（Groovy 脚本）集中存放在一个 Git 仓库中，供多个 Jenkins Pipeline 引用的机制。

在前公司（HSBC 项目）中，我引入了开源的 Jenkinsfile DSL，创建了可复用的 CI/CD stage。具体做法：

1. 在原有 stage（git-clone、maven-build、push-to-nexus）基础上，新增了 Sonar Scan、IQ Scan、Checkmarx Scan、docker-build、deploy-by-ansible-core、alarm suppression、JMeter test 等 stage。
2. 将这些 stage 封装在 Shared Library 中，开发者只需写一个 JSON 文件声明式地调用。
3. 在 Shared Library 基础上做了二次开发，以参数化方式支持多环境部署（DEV/UAT/PRD），大幅减少开发团队工作量。

```
// vars/myPipeline.groovy - Shared Library 中的全局变量
def call(Map config) {
    pipeline {
        agent any
        stages {
            stage('Git Clone') { steps { gitClone(config.repoUrl) } }
            stage('Build')     { steps { mavenBuild(config.javaVersion) } }
            stage('Sonar Scan'){ steps { sonarScan(config.sonarProject) } }
            stage('Deploy')    { steps { ansibleDeploy(config.environment) } }
        }
    }
}
```

---

### Q2: What is Jenkins Shared Library? How did you use it in your previous company?

**Answer:**
A Jenkins Shared Library centralizes reusable pipeline code (Groovy scripts) in a Git repository that multiple pipelines can reference.

At HSBC, I introduced the open-source Jenkinsfile DSL and created reusable CI/CD stages:

1. On top of existing stages (git-clone, maven-build, push-to-nexus), I added Sonar Scan, IQ Scan, Checkmarx Scan, docker-build, deploy-by-ansible-core, alarm suppression, and JMeter test stages.
2. Packaged these stages into a Shared Library so developers only needed to write a JSON file to call them declaratively.
3. Extended the Shared Library with parameterized multi-environment deployment support (DEV/UAT/PRD), significantly reducing team workload.

```
// vars/myPipeline.groovy - global variable in Shared Library
def call(Map config) {
    pipeline {
        agent any
        stages {
            stage('Git Clone') { steps { gitClone(config.repoUrl) } }
            stage('Build')     { steps { mavenBuild(config.javaVersion) } }
            stage('Sonar Scan'){ steps { sonarScan(config.sonarProject) } }
            stage('Deploy')    { steps { ansibleDeploy(config.environment) } }
        }
    }
}
```

---

### Q3: 什么是 CI/CD Pipeline 的 single-trunk 模式？和 GitFlow / Feature Branch 有什么区别？

**答案：**
Single-trunk（单主干）是指所有开发者直接向一个主干分支（通常是 main/master）提交代码的分支策略。

**对比：**

| | Single-Trunk | GitFlow | Feature Branch |
|---|---|---|---|
| 分支数量 | 极少（通常只有 main） | 多（main/develop/feature/release/hotfix） | 中等（main + feature branches） |
| 合并频率 | 每天多次 | 每个 release 合并一次 | 每个 feature 完成后合并 |
| 冲突概率 | 低（小步快跑） | 高（长时间隔离） | 中等 |
| CI/CD 复杂度 | 简单（一条主干流水线） | 复杂（多条流水线） | 中等 |
| 发布策略 | 增量发布，feature flag 控制 | 版本发布 | 可与两者结合 |

**在前公司的实践（SAP 项目）：**
- 单主干 Azure DevOps Pipeline：所有代码合入 main → 自动触发 CIT → SIT → 手动审批 → UAT deploy → NFR deploy → PRD 走单独 release pipeline
- PR merge 到 main 后自动构建完整镜像并推送 ECR
- 通过 feature flag 和按环境的 values 级联实现多区域差异化，而非代码分支

---

### Q3: What is the single-trunk CI/CD model? How does it differ from GitFlow / Feature Branch?

**Answer:**
Single-trunk means all developers commit directly to one main branch (typically main/master).

**Comparison:**

| | Single-Trunk | GitFlow | Feature Branch |
|---|---|---|---|
| Branch count | Very few (usually just main) | Many (main/develop/feature/release/hotfix) | Moderate (main + features) |
| Merge frequency | Multiple times daily | Once per release | After each feature |
| Conflict probability | Low (small, frequent commits) | High (long-lived isolation) | Moderate |
| CI/CD complexity | Simple (one trunk pipeline) | Complex (multiple pipelines) | Moderate |
| Release strategy | Incremental, feature flag gated | Versioned releases | Works with either |

**My practice (SAP project):**
- Single-trunk Azure DevOps Pipeline: all code → main → auto CIT → SIT → manual approval → UAT deploy → NFR deploy → PRD via separate release pipeline
- Full image build + push to ECR on PR merge to main
- Multi-region differentiation via feature flags and per-environment values cascade, not code branches

---

### Q4: 请描述一个典型的 CI/CD Pipeline 中有哪些 stage，以及每个 stage 做什么？

**答案（以前公司 HSBC 项目为例）：**

1. **Git Clone** — 拉取源码，checkout 到目标分支/commit
2. **Maven Build / NPM Build** — 编译源码，运行单元测试，打包 artifact
3. **SonarQube Scan** — 静态代码分析，检查代码质量门禁（coverage、bugs、code smells）
4. **IQ Scan / Checkmarx Scan** — 安全检查，扫描第三方依赖漏洞和 SAST
5. **Docker Build** — Multi-stage build，生产精简镜像（如 Amazon Corretto + jlink）
6. **Push to ECR / Nexus** — 推送镜像到容器仓库，推送 jar 到制品仓库
7. **Deploy by Ansible / Helm** — 自动化部署到目标环境
8. **JMeter Test / Karate Test** — 性能测试、集成测试、E2E 测试
9. **Promote & Release** — 晋级到生产环境（PreProd → Change Request → 多区域并行发布）
10. **Post Actions** — 构建成功/失败通知、日志归档、告警抑制

---

### Q4: Describe the stages in a typical CI/CD pipeline and what each does.

**Answer (based on HSBC project):**

1. **Git Clone** — Pull source code, checkout target branch/commit
2. **Maven Build / NPM Build** — Compile source, run unit tests, package artifact
3. **SonarQube Scan** — Static code analysis, check quality gates (coverage, bugs, code smells)
4. **IQ Scan / Checkmarx Scan** — Security scanning: third-party dependency vulnerabilities + SAST
5. **Docker Build** — Multi-stage build, produce slim runtime image (e.g., Amazon Corretto + jlink)
6. **Push to ECR / Nexus** — Push image to container registry, push jar to artifact repository
7. **Deploy by Ansible / Helm** — Automated deployment to target environment
8. **JMeter Test / Karate Test** — Performance, integration, and E2E testing
9. **Promote & Release** — Promote to production (PreProd → Change Request → multi-region parallel release)
10. **Post Actions** — Build success/failure notifications, log archival, alarm suppression

---

### Q5: 什么是 Blue-Green Deployment 和 Canary Deployment？你如何实现 Canary Deployment？

**答案：**

**Blue-Green：** 维护两套完全相同的生产环境（Blue=当前版本，Green=新版本）。部署新版本到 Green → 验证通过 → 一键切换流量到 Green。回滚只需切回 Blue。缺点：需要双倍资源。

**Canary（金丝雀发布）：** 将新版本部署到生产环境，但只分配少量流量（如 5%），验证无异常后逐步增大比例（25% → 50% → 100%）。优点：资源开销小，问题影响范围可控。

**在前公司的实现（基于 Istio Service Mesh）：**
1. 配置 VirtualService 的 weight 字段：`weight: 5`（新版本 5% 流量）
2. 监控 CloudWatch Metrics（错误率、响应时间）
3. 确认无异常后，Jenkins Groovy 脚本通过 `kubectl patch virtualservice` 动态调整 weight：25 → 50 → 100
4. 如果检测到异常（错误率 > 阈值），自动回滚至 `weight: 0`（全部流量回旧版本）

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts:
  - my-service
  http:
  - route:
    - destination:
        host: my-service
        subset: v1
      weight: 95
    - destination:
        host: my-service
        subset: v2
      weight: 5
```

---

### Q5: What are Blue-Green Deployment and Canary Deployment? How did you implement Canary Deployment?

**Answer:**

**Blue-Green:** Maintain two identical production environments (Blue = current, Green = new). Deploy to Green → validate → switch all traffic to Green. Rollback means switching back to Blue. Downside: needs double the resources.

**Canary:** Deploy the new version to production but route only a small percentage of traffic (e.g., 5%). If no anomalies, gradually increase to 25% → 50% → 100%. Advantages: low resource overhead, limited blast radius.

**My implementation (based on Istio Service Mesh):**
1. Configure VirtualService weight field: `weight: 5` (5% to new version)
2. Monitor CloudWatch Metrics (error rate, response time)
3. When healthy, Jenkins Groovy scripts dynamically adjust weight via `kubectl patch virtualservice`: 25 → 50 → 100
4. On anomaly detection (error rate > threshold), auto-rollback to `weight: 0` (all traffic back to old version)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts:
  - my-service
  http:
  - route:
    - destination:
        host: my-service
        subset: v1
      weight: 95
    - destination:
        host: my-service
        subset: v2
      weight: 5
```

---

## 二、Kubernetes 实操 / Kubernetes Hands-on

### Q6: Pod 反复 CrashLoopBackOff，你的排查步骤是什么？

**答案——标准排查流程：**

**Step 1: 查看 Pod 状态和事件**
```bash
kubectl describe pod <pod-name> -n <namespace>
```
重点关注 Events 区域：OOMKilled（内存不足）、ImagePullBackOff（镜像拉取失败）、Liveness probe failed。

**Step 2: 查看容器日志**
```bash
kubectl logs <pod-name> -n <namespace> --previous  # 看上一次崩溃的日志
kubectl logs <pod-name> -n <namespace> --tail=200   # 看当前日志
```

**Step 3: 常见原因及解决方案**

| 现象 | 可能原因 | 解决方案 |
|---|---|---|
| OOMKilled | 内存 limit 太小 | 增大 memory limit 或修复内存泄漏 |
| Error: ImagePullBackOff | 镜像不存在或权限不足 | 检查 image tag、imagePullSecrets |
| CrashLoopBackOff + exit code 1 | 应用启动报错 | 查看应用日志，检查配置文件/环境变量 |
| CrashLoopBackOff + exit code 137 | OOM，被内核 kill | 增大 memory limit |
| CrashLoopBackOff + exit code 143 | 收到 SIGTERM | 检查 preStop hook 或 terminationGracePeriod |
| Liveness probe failed | 健康检查配置不当 | 调大 initialDelaySeconds 和 failureThreshold |

**Step 4: 深入 Pod 内部排查**
```bash
# 如果 Pod 能短暂启动
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# JVM 应用排查
kubectl exec <pod-name> -- jstack 1       # 查看线程堆栈
kubectl exec <pod-name> -- jmap -heap 1   # 查看堆内存
```

**Step 5: 检查依赖服务**
- 数据库是否可达（telnet/nc）
- ConfigMap/Secret 是否正确挂载
- ServiceAccount 权限是否足够

---

### Q6: A Pod is repeatedly CrashLoopBackOff — what is your troubleshooting process?

**Answer — Standard troubleshooting flow:**

**Step 1: Check Pod status and events**
```bash
kubectl describe pod <pod-name> -n <namespace>
```
Focus on Events: OOMKilled, ImagePullBackOff, Liveness probe failed.

**Step 2: Check container logs**
```bash
kubectl logs <pod-name> -n <namespace> --previous  # logs from previous crash
kubectl logs <pod-name> -n <namespace> --tail=200   # current logs
```

**Step 3: Common causes and fixes**

| Symptom | Likely cause | Resolution |
|---|---|---|
| OOMKilled | Memory limit too low | Increase memory limit or fix memory leak |
| ImagePullBackOff | Image doesn't exist or lacks pull permission | Check image tag, imagePullSecrets |
| CrashLoopBackOff + exit 1 | Application startup error | Check app logs, config files, env vars |
| CrashLoopBackOff + exit 137 | OOM killed by kernel | Increase memory limit |
| CrashLoopBackOff + exit 143 | Received SIGTERM | Check preStop hook or terminationGracePeriod |
| Liveness probe failed | Misconfigured health check | Increase initialDelaySeconds and failureThreshold |

**Step 4: Debug inside the Pod**
```bash
# If the Pod starts briefly
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# JVM application debugging
kubectl exec <pod-name> -- jstack 1
kubectl exec <pod-name> -- jmap -heap 1
```

**Step 5: Check dependencies**
- Can the Pod reach the database? (telnet/nc)
- Are ConfigMaps/Secrets correctly mounted?
- Does the ServiceAccount have sufficient permissions?

---

### Q7: 一个 Service 访问不通，你如何排查？

**答案——从外到内逐层排查：**

**Layer 1: Service 定义本身**
```bash
kubectl get svc <svc-name> -n <namespace> -o yaml
```
检查 selector 是否匹配 Pod 的 labels。

**Layer 2: Endpoints 是否为空**
```bash
kubectl get endpoints <svc-name> -n <namespace>
```
如果 `<none>`，说明 selector 没有匹配到任何 Pod。检查：
- Pod 的 labels 是否与 Service selector 一致
- Pod 是否 Ready（Readiness Probe 是否通过）

**Layer 3: Pod 是否 Ready**
```bash
kubectl get pods -n <namespace> -o wide
```
如果 Pod 状态不是 Running 或 READY 为 0/1，回到 Q6 排查 Pod 本身。

**Layer 4: 网络策略是否阻断**
```bash
kubectl get networkpolicies -n <namespace>
```
检查是否有 NetworkPolicy 禁止了该流量。

**Layer 5: DNS 是否正常**
```bash
kubectl exec -it <debug-pod> -- nslookup <svc-name>.<namespace>.svc.cluster.local
```
如果 DNS 解析失败，检查 CoreDNS Pod 是否正常。

**Layer 6: 从另一个 Pod 测试连通性**
```bash
kubectl run debug --image=nicolaka/netshoot -it --rm -- /bin/bash
curl http://<svc-name>:<port>/health
telnet <svc-name> <port>
```

**Layer 7: 如果是外部访问不通（Ingress/NodePort/LoadBalancer）**
- 检查 Ingress Controller 是否运行正常
- 检查 Ingress 资源的 host/path/backend 配置
- 检查外部 LoadBalancer 是否分配了 IP
- 检查防火墙/安全组是否放行端口

---

### Q7: A Service is unreachable — how do you troubleshoot?

**Answer — Layer-by-layer from outside in:**

**Layer 1: Service definition**
```bash
kubectl get svc <svc-name> -n <namespace> -o yaml
```
Check if the selector matches Pod labels.

**Layer 2: Endpoints — are they empty?**
```bash
kubectl get endpoints <svc-name> -n <namespace>
```
If `<none>`, the selector matched no Pods. Check:
- Do Pod labels match the Service selector?
- Are Pods Ready (is the Readiness Probe passing)?

**Layer 3: Are Pods Ready?**
```bash
kubectl get pods -n <namespace> -o wide
```
If not Running or READY is 0/1, return to Q6 and troubleshoot the Pod.

**Layer 4: NetworkPolicy blocking traffic?**
```bash
kubectl get networkpolicies -n <namespace>
```
Check if any NetworkPolicy denies this traffic.

**Layer 5: Is DNS working?**
```bash
kubectl exec -it <debug-pod> -- nslookup <svc-name>.<namespace>.svc.cluster.local
```
If DNS resolution fails, check CoreDNS Pods.

**Layer 6: Test connectivity from another Pod**
```bash
kubectl run debug --image=nicolaka/netshoot -it --rm -- /bin/bash
curl http://<svc-name>:<port>/health
telnet <svc-name> <port>
```

**Layer 7: External access (Ingress/NodePort/LoadBalancer)**
- Is the Ingress Controller running?
- Check Ingress resource host/path/backend configuration
- Has the external LoadBalancer been assigned an IP?
- Are firewall/security group rules allowing the port?

---

### Q8: 线上 SAP ERP 服务起不来了，你怎么排查？

**答案——面向 SAP 及其托管 Kubernetes 环境的排查思路：**

**Step 1: 快速分诊（Triage）**
- 确认影响范围：是所有 region 还是单个 region？是所有用户还是部分用户？
- 确认时间窗口：出问题前是否有变更（部署、配置变更、基础设施变更）？
- 查看告警：Dynatrace / CloudWatch / Prometheus 是否有异常指标？

**Step 2: Kyma / K8s 层面排查**
```bash
# 检查 Pod 状态
kubectl get pods -n <sap-namespace>

# 查看最近事件
kubectl get events -n <sap-namespace> --sort-by='.lastTimestamp' | tail -50

# 检查 Deployment 状态和 ReplicaSet 历史
kubectl describe deployment <deployment-name> -n <sap-namespace>
kubectl rollout history deployment <deployment-name> -n <sap-namespace>

# 如果是最新部署导致的问题，立即回滚
kubectl rollout undo deployment <deployment-name> -n <sap-namespace> --to-revision=<N>
```

**Step 3: 基础设施排查**
```bash
# 检查节点状态
kubectl get nodes
kubectl describe node <node-name>

# 检查 istio sidecar 是否正常
kubectl get pods -n <namespace> -o jsonpath='{.items[*].spec.containers[*].name}'

# 检查 Kyma 级资源
kubectl get serviceinstances -n <namespace>
kubectl get virtualservices -n <namespace>
```

**Step 4: 应用层面排查**
- 检查 Vault 中的 secret/证书是否过期
- 检查数据库连接是否正常（Aurora / HANA 是否可达）
- 检查消息队列积压（SAP Event Mesh / MQ）
- 检查是否有级联故障（下游服务不可用导致上游超时）

**Step 5: 快速的临时代码修复**
如果根因是代码 bug 且回滚不可行：
```bash
# 修改 ConfigMap 或环境变量暂时绕过问题
kubectl edit configmap <config-name> -n <namespace>
kubectl rollout restart deployment <deployment-name> -n <namespace>
```

**Step 6: 事后复盘（Post-Incident Review）**
- 记录问题时间线
- 更新监控/告警规则，缩短 MTTD（Mean Time To Detect）
- 如果是部署引入的问题，强化 Canary Release 或变更审批流程

---

### Q8: A production SAP ERP service won't start — how do you troubleshoot?

**Answer — A SAP-oriented, managed-Kubernetes troubleshooting approach:**

**Step 1: Rapid Triage**
- Scope of impact: all regions or single region? All users or partial?
- Time window: any recent changes (deployment, config change, infra change)?
- Check alerts: Dynatrace / CloudWatch / Prometheus — any anomalies?

**Step 2: Kyma / K8s layer**
```bash
# Check Pod status
kubectl get pods -n <sap-namespace>

# Recent events
kubectl get events -n <sap-namespace> --sort-by='.lastTimestamp' | tail -50

# Deployment status and ReplicaSet history
kubectl describe deployment <deployment-name> -n <sap-namespace>
kubectl rollout history deployment <deployment-name> -n <sap-namespace>

# If caused by the latest deployment, rollback immediately
kubectl rollout undo deployment <deployment-name> -n <sap-namespace> --to-revision=<N>
```

**Step 3: Infrastructure triage**
```bash
# Node status
kubectl get nodes
kubectl describe node <node-name>

# Istio sidecar health
kubectl get pods -n <namespace> -o jsonpath='{.items[*].spec.containers[*].name}'

# Kyma-level resources
kubectl get serviceinstances -n <namespace>
kubectl get virtualservices -n <namespace>
```

**Step 4: Application layer**
- Are Vault secrets/certificates expired?
- Is the database reachable? (Aurora / HANA connectivity)
- Is there a message queue backlog? (SAP Event Mesh / MQ)
- Is there a cascading failure? (downstream service down → upstream timeout)

**Step 5: Quick tactical fix**
If the root cause is a code bug and rollback isn't feasible:
```bash
# Tweak ConfigMap or env vars as a temporary workaround
kubectl edit configmap <config-name> -n <namespace>
kubectl rollout restart deployment <deployment-name> -n <namespace>
```

**Step 6: Post-Incident Review**
- Document the incident timeline
- Update monitoring/alerting rules to reduce MTTD
- If deployment-introduced, strengthen Canary Release or change approval process

---

### Q9: 请解释 Readiness Probe 和 Liveness Probe 的区别。如何正确配置？

**答案：**

| | Readiness Probe | Liveness Probe |
|---|---|---|
| 目的 | 判断 Pod 是否可以接收流量 | 判断 Pod 是否需要重启 |
| 失败后果 | Pod 从 Service Endpoint 移除，不接收流量 | kubelet 杀掉容器并重启 |
| 检查内容 | 外部依赖是否就绪（DB、Redis、MQ 连接） | 应用自身是否健康（无死锁、无僵死） |
| 配置重点 | initialDelaySeconds 要覆盖依赖初始化时间 | initialDelaySeconds 不要过于激进 |

**正确配置示例：**
```yaml
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 60    # 给应用充足的启动时间
  periodSeconds: 10
  failureThreshold: 3        # 连续失败 3 次才重启（容忍短暂抖动）
  timeoutSeconds: 5

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 5
  failureThreshold: 3        # 连续失败 3 次才摘除流量
  successThreshold: 1
  timeoutSeconds: 3
```

**常见错误：**
- Liveness Probe 的 initialDelaySeconds 太小 → 应用还没启动完就被 kill → CrashLoopBackOff
- Readiness Probe 没有检查外部依赖 → Pod 显示 Ready 但数据库不通 → 请求 5xx

---

### Q9: Explain the difference between Readiness Probe and Liveness Probe. How do you configure them properly?

**Answer:**

| | Readiness Probe | Liveness Probe |
|---|---|---|
| Purpose | Is the Pod ready to receive traffic? | Does the Pod need to be restarted? |
| On failure | Pod removed from Service Endpoint | kubelet kills and restarts the container |
| Checks | External dependencies ready? (DB, Redis, MQ) | App itself healthy? (no deadlocks, not stuck) |
| Key config | initialDelaySeconds must cover dependency init | initialDelaySeconds must not be too aggressive |

**Correct configuration example:**
```yaml
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 60    # Give app enough startup time
  periodSeconds: 10
  failureThreshold: 3        # Tolerate transient hiccups
  timeoutSeconds: 5

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 5
  failureThreshold: 3        # 3 consecutive failures before removing from endpoint
  successThreshold: 1
  timeoutSeconds: 3
```

**Common mistakes:**
- Liveness Probe `initialDelaySeconds` too small → app killed before startup completes → CrashLoopBackOff
- Readiness Probe doesn't check external dependencies → Pod shows Ready but DB is unreachable → 5xx errors

---

### Q10: HPA（Horizontal Pod Autoscaler）是怎样工作的？你在项目中怎么配置的？

**答案：**

HPA 根据观察到的 CPU/内存使用率（或自定义指标）自动调整 Deployment/StatefulSet 的副本数。

**工作原理公式：**
```
desiredReplicas = ceil(currentReplicas × (currentMetricValue / desiredMetricValue))
```
例如：当前 3 个 Pod，CPU 使用率 85%，目标 70% → `ceil(3 × 85/70)` = `ceil(3.64)` = 4 个 Pod。

**在前公司的配置：**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-service
  minReplicas: 2                 # 最少 2 个 Pod（高可用）
  maxReplicas: 5                 # 最多 5 个 Pod
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70   # CPU > 70% 时扩容
  behavior:                      # 控制扩缩容速度
    scaleDown:
      stabilizationWindowSeconds: 300   # 缩容前等 5 分钟
      policies:
      - type: Percent
        value: 50               # 每次最多缩 50%
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0     # 扩容立即生效
      policies:
      - type: Percent
        value: 100              # 每次最多翻倍
        periodSeconds: 15
```

**配合 PDB（PodDisruptionBudget）使用：**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-service-pdb
spec:
  minAvailable: 1                # 至少保持 1 个 Pod 存活
  selector:
    matchLabels:
      app: my-service
```
防止节点维护或 Cluster Autoscaler 缩容时服务中断。

---

### Q10: How does HPA (Horizontal Pod Autoscaler) work? How did you configure it in your project?

**Answer:**

HPA automatically scales the number of Pods in a Deployment/StatefulSet based on observed CPU/memory utilization (or custom metrics).

**Formula:**
```
desiredReplicas = ceil(currentReplicas × (currentMetricValue / desiredMetricValue))
```
Example: 3 Pods, CPU 85%, target 70% → `ceil(3 × 85/70)` = `ceil(3.64)` = 4 Pods.

**Configuration from my previous project:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-service
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:                      # Control scaling velocity
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
```

**Combined with PDB (PodDisruptionBudget):**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-service-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: my-service
```
Prevents service disruption during node maintenance or Cluster Autoscaler scale-down.

---

### Q11: 什么是 Helm Chart？Values 级联（Values Cascade）是怎么工作的？

**答案：**

Helm 是 Kubernetes 的包管理工具，Helm Chart 是一组描述 K8s 资源的模板文件 + values 文件。

**Values 级联（覆盖优先级，从低到高）：**
1. Chart 内置 `values.yaml`（默认值）
2. 父 Chart 的 `values.yaml`（Subchart 被父 Chart 覆盖）
3. 环境级 values 文件：`values-dev.yaml` / `values-uat.yaml` / `values-prd.yaml`
4. `helm install -f custom.yaml`（命令行指定）
5. `helm install --set key=value`（命令行设置，最高优先级）

**在前公司的实践（多区域级联）：**
```
planning-collaboration/
├── Chart.yaml
├── values.yaml                    # 基础默认值（公共部分）
├── values-us20.yaml               # US20 区域覆盖：域名、证书、副本数
├── values-eu20.yaml               # EU20 区域覆盖
├── values-in30.yaml               # IN30 区域覆盖
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    └── hpa.yaml
```
每个区域的 values 文件只覆盖差异部分（domain、messaging prefix、scaling profile、feature flags），基础 chart 保持统一。接入新区域只需新建一个 values 文件。

---

### Q11: What is a Helm Chart? How does the Values Cascade work?

**Answer:**

Helm is the package manager for Kubernetes. A Helm Chart is a collection of templated YAML files + values files that describe K8s resources.

**Values cascade (override priority, lowest to highest):**
1. Chart's built-in `values.yaml` (defaults)
2. Parent chart's `values.yaml` (subcharts overridden by parent)
3. Environment-level files: `values-dev.yaml` / `values-uat.yaml` / `values-prd.yaml`
4. `helm install -f custom.yaml` (command-line file)
5. `helm install --set key=value` (command-line, highest priority)

**My practice (multi-region cascade):**
```
planning-collaboration/
├── Chart.yaml
├── values.yaml                    # Base defaults (common config)
├── values-us20.yaml               # US20 overrides: domain, cert, replicas
├── values-eu20.yaml               # EU20 overrides
├── values-in30.yaml               # IN30 overrides
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    └── hpa.yaml
```
Each region's values file overrides only the differences (domain, messaging prefix, scaling profile, feature flags). The base chart stays unified. Onboarding a new region requires only a new values file.

---

### Q12: Pod 优雅停机（Graceful Shutdown）怎么实现？

**答案：**

优雅停机确保 Pod 在接收 SIGTERM 后，完成正在处理的请求再退出，避免 5xx 错误。

**完整的三段式配置：**

**1. Spring Boot 应用层面：**
```yaml
spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s   # 给 30 秒完成正在处理的请求
server:
  shutdown: graceful                   # 启用优雅关闭
```

**2. K8s Deployment 层面：**
```yaml
spec:
  terminationGracePeriodSeconds: 45   # K8s 最多等 45 秒，之后强制 SIGKILL
  containers:
  - name: app
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - |
            curl -X POST http://localhost:8080/actuator/shutdown  # 触发 Spring 优雅关闭
            sleep 5    # 等待 Istio Sidecar 排空流量
```

**时间关系：**
```
terminationGracePeriodSeconds (45s)
├── preStop 执行 (curl shutdown + sleep 5 = ~6s)
├── SIGTERM 发送给主容器
│   └── Spring graceful shutdown (30s timeout-per-shutdown-phase)
├── SIGTERM 发送给 Istio sidecar
│   └── Sidecar 排空剩余请求
└── 45s 到期 → SIGKILL（强制杀死仍未退出的进程）
```

**关键选择：** `terminationGracePeriodSeconds > preStop时间 + Spring关闭时间`，否则 Pod 会被强制 kill。

---

### Q12: How do you implement Pod Graceful Shutdown?

**Answer:**

Graceful shutdown ensures the Pod finishes in-flight requests before exiting after receiving SIGTERM, preventing 5xx errors.

**Complete three-layer configuration:**

**1. Spring Boot application layer:**
```yaml
spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
server:
  shutdown: graceful
```

**2. K8s Deployment layer:**
```yaml
spec:
  terminationGracePeriodSeconds: 45
  containers:
  - name: app
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - |
            curl -X POST http://localhost:8080/actuator/shutdown
            sleep 5    # Wait for Istio sidecar to drain
```

**Timeline:**
```
terminationGracePeriodSeconds (45s)
├── preStop executes (curl shutdown + sleep 5 ≈ 6s)
├── SIGTERM → main container
│   └── Spring graceful shutdown (30s timeout)
├── SIGTERM → Istio sidecar
│   └── Sidecar drains remaining requests
└── 45s elapsed → SIGKILL (force kills any remaining processes)
```

**Key rule:** `terminationGracePeriodSeconds > preStop time + Spring shutdown time`, otherwise the Pod gets force-killed.

---

## 三、GitOps & ArgoCD / GitOps & ArgoCD

### Q13: 什么是 GitOps？你如何实践 GitOps？

**答案：**

GitOps 是一种运维模式，将 Git 仓库作为声明式基础设施和应用程序的单一事实来源（Single Source of Truth）。

**核心原则：**
1. **声明式描述** — 所有基础设施和应用配置以声明式 YAML 存储在 Git 中
2. **版本化与不可变** — 每次变更都是 Git commit，可审计、可回滚
3. **自动同步** — Git 仓库变更自动应用到目标集群
4. **持续协调** — 持续对比期望状态（Git）和实际状态（集群），自动修正漂移

**在前公司的实践：**

**Push-based（CI/CD 驱动）：** Jenkins/Azure Pipeline 执行 `kubectl apply` 或 `helm upgrade`，将变更推送到集群。

**Pull-based（Agent 驱动，ArgoCD）：** ArgoCD 监控 Git 仓库变更，自动拉取并应用到集群。

**具体实践（SAP 项目）：**
- Helm chart + values 级联存储在 Git 仓库中
- 每个环境一个目录，包含该环境的 values 文件和部署配置
- PR merge 到 main → Pipeline 自动执行 `helm upgrade` 或 ArgoCD 自动同步
- GitOps 后渲染器（post-renderer）为每个 manifest 打上 PR/构建/模板来源标记 → 告警可直接追溯到变更

---

### Q13: What is GitOps? How do you practice it?

**Answer:**

GitOps is an operational model where Git repositories serve as the single source of truth for declarative infrastructure and applications.

**Core principles:**
1. **Declarative** — All infra and app config stored as declarative YAML in Git
2. **Versioned & immutable** — Every change is a Git commit, auditable and rollback-able
3. **Automated sync** — Git changes automatically applied to target clusters
4. **Continuous reconciliation** — Constantly compare desired state (Git) vs actual state (cluster), auto-correct drift

**My practice:**

**Push-based (CI/CD driven):** Jenkins/Azure Pipeline runs `kubectl apply` or `helm upgrade` to push changes to the cluster.

**Pull-based (Agent-driven, ArgoCD):** ArgoCD watches the Git repo and auto-pulls + applies changes to the cluster.

**Concrete practice (SAP project):**
- Helm chart + regional values cascade stored in Git
- Per-environment directory with values files and deployment config
- PR merge to main → Pipeline auto-runs `helm upgrade` or ArgoCD auto-syncs
- GitOps post-renderer stamps every manifest with PR/build/template provenance → alerts trace directly back to the change that introduced the issue

---

### Q14: ArgoCD 的核心概念是什么？和 Jenkins Pipeline 部署有什么区别？

**答案：**

**ArgoCD 核心概念：**

| 概念 | 说明 |
|---|---|
| Application | 一个 K8s 资源组（可以是 Helm Chart、Kustomize、或纯 YAML 目录） |
| Project | Application 的逻辑分组，控制权限和允许的目标集群/namespace |
| Source | Git 仓库 URL + 路径 + branch/tag |
| Destination | 目标集群 + namespace |
| Sync Policy | 自动同步（Auto-sync）还是手动同步 |

**ArgoCD vs Jenkins Pipeline 部署：**

| | Jenkins Pipeline | ArgoCD |
|---|---|---|
| 模式 | Push（Pipeline 推送变更到集群） | Pull（Agent 拉取 Git 变更到集群） |
| 集群访问 | Jenkins 需要集群凭据和网络连通性 | ArgoCD 在集群内运行，无需外部凭据 |
| 状态感知 | 无——只管推，不知道集群实际状态 | 持续协调——自动检测并修正 drift |
| 回滚 | 需要手动执行 rollout undo 或重新部署旧版本 | Git revert → 自动同步，操作简单 |
| UI | 蓝海视图（有限） | 丰富的应用状态 UI、diff 视图、资源树 |
| 适用场景 | 复杂 CI/CD 流程（多 stage、多工具链） | 纯部署/同步场景，适合多集群管理 |

**最佳实践：** CI（Jenkins/ADO）做构建和测试 → 产出镜像 → 更新 GitOps 仓库中的镜像 tag → ArgoCD 自动同步到集群。

---

### Q14: What are the core concepts of ArgoCD? How does it differ from Jenkins Pipeline deployment?

**Answer:**

**ArgoCD core concepts:**

| Concept | Description |
|---|---|
| Application | A group of K8s resources (Helm Chart, Kustomize, or raw YAML) |
| Project | Logical grouping of Applications; controls permissions and allowed targets |
| Source | Git repo URL + path + branch/tag |
| Destination | Target cluster + namespace |
| Sync Policy | Auto-sync or manual sync |

**ArgoCD vs Jenkins Pipeline:**

| | Jenkins Pipeline | ArgoCD |
|---|---|---|
| Model | Push | Pull |
| Cluster access | Jenkins needs cluster creds and network | ArgoCD runs inside cluster, no external creds needed |
| State awareness | None — just pushes, doesn't know actual state | Continuous reconciliation — detects and corrects drift |
| Rollback | Manual rollout undo or redeploy old version | Git revert → auto-sync, simple |
| UI | Blue Ocean (limited) | Rich app state UI, diff view, resource tree |
| Use case | Complex CI/CD flows (multi-stage, multi-toolchain) | Pure deploy/sync, ideal for multi-cluster management |

**Best practice:** CI (Jenkins/ADO) handles build + test → produces image → updates image tag in GitOps repo → ArgoCD auto-syncs to cluster.

---

## 四、Docker & 镜像优化 / Docker & Image Optimization

### Q15: 什么是 Multi-stage Build？为什么用它？

**答案：**

Multi-stage Build 允许在单个 Dockerfile 中使用多个 FROM 语句，每个阶段可以使用不同的基础镜像，最终只将所需的产物复制到最终镜像中。

**优点：**
- 最终镜像体积小（不包含编译工具链、源代码、构建依赖）
- 安全性更高（攻击面减少）
- 构建缓存利用更好

**在前公司的实践（Spring Boot 微服务）：**
```dockerfile
# Stage 1: Build
FROM maven:3.9-amazoncorretto-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline    # 缓存依赖
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Runtime
FROM amazoncorretto:21-alpine
WORKDIR /app
RUN jlink --add-modules java.base,java.sql,java.naming,java.management \
          --strip-debug --no-man-pages --no-header-files \
          --output /opt/jre-minimal    # 用 jlink 创建精简 JRE
ENV JAVA_HOME=/opt/jre-minimal
COPY --from=builder /app/target/*.jar app.jar
USER 1001                             # 不以 root 运行
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```
Build 阶段用 Maven 镜像（~500MB），Runtime 阶段仅保留精简 JRE（~40MB）+ jar（~50MB），最终镜像 ~100MB。

---

### Q15: What is Multi-stage Build? Why use it?

**Answer:**

Multi-stage Build allows multiple FROM statements in a single Dockerfile; each stage can use a different base image, and only the needed artifacts are copied to the final image.

**Benefits:**
- Smaller final image (no build toolchain, source code, build dependencies)
- Better security (reduced attack surface)
- Better build cache utilization

**My practice (Spring Boot microservice):**
```dockerfile
# Stage 1: Build
FROM maven:3.9-amazoncorretto-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Runtime
FROM amazoncorretto:21-alpine
WORKDIR /app
RUN jlink --add-modules java.base,java.sql,java.naming,java.management \
          --strip-debug --no-man-pages --no-header-files \
          --output /opt/jre-minimal    # Slim JRE with jlink
ENV JAVA_HOME=/opt/jre-minimal
COPY --from=builder /app/target/*.jar app.jar
USER 1001
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```
Build stage uses Maven image (~500MB), Runtime stage keeps only slim JRE (~40MB) + jar (~50MB) → final image ~100MB.

---

## 五、云基础设施 & IaC / Cloud Infrastructure & IaC

### Q16: 什么是 Terraform？它的核心工作流程是怎样的？

**答案：**

Terraform 是 HashiCorp 开发的基础设施即代码（IaC）工具，使用声明式语言 HCL（HashiCorp Configuration Language）描述和管理云资源。

**核心工作流程：**
```
terraform init       → 初始化工作目录，下载 provider 插件
terraform plan       → 预览变更（对比当前状态和期望状态）
terraform apply      → 执行变更，创建/修改/删除资源
terraform destroy    → 销毁所有管理的资源
```

**State 文件（terraform.tfstate）：**
- 记录 Terraform 管理的资源与实际云资源的映射关系
- 存放在远程后端（S3 + DynamoDB 锁）以实现团队协作
- **绝不能**手动编辑

**在前公司的实践：**
- 编写了全量 AWS 基础设施的 Terraform Module：VPC、EKS、Aurora PostgreSQL Multi-AZ、ElastiCache Redis、DocumentDB、Amazon MQ、S3、CloudFront + WAF、ACM、Route53、KMS、Secrets Manager、IAM + IRSA、AppConfig、监控栈（Prometheus + Grafana + X-Ray）
- 通过 `terraform.tfvars` 按 DEV/UAT/PRD 三套环境参数化
- State 文件存储在 S3，DynamoDB 做状态锁

---

### Q16: What is Terraform? What is its core workflow?

**Answer:**

Terraform is HashiCorp's Infrastructure as Code (IaC) tool that uses the declarative HCL language to describe and manage cloud resources.

**Core workflow:**
```
terraform init       → Initialize working directory, download providers
terraform plan       → Preview changes (diff current vs desired state)
terraform apply      → Execute changes: create/modify/destroy resources
terraform destroy    → Destroy all managed resources
```

**State file (terraform.tfstate):**
- Maps Terraform-managed resources to actual cloud resources
- Stored remotely (S3 + DynamoDB lock) for team collaboration
- **Never** edit manually

**My practice:**
- Wrote full AWS infrastructure Terraform Modules: VPC, EKS, Aurora PostgreSQL Multi-AZ, ElastiCache Redis, DocumentDB, Amazon MQ, S3, CloudFront + WAF, ACM, Route53, KMS, Secrets Manager, IAM + IRSA, AppConfig, monitoring stack (Prometheus + Grafana + X-Ray)
- Parameterized by DEV/UAT/PRD via `terraform.tfvars`
- State in S3, locking via DynamoDB

---

### Q17: VPC 三层子网是怎么设计的？为什么这样做？

**答案：**

三层子网隔离的核心思想是：根据资源对公网暴露的需求，将它们分层部署，并通过 Security Group 控制层间流量。

```
Internet ──→ [Public Subnet]  ──→ [Private Subnet]  ──→ [Database Subnet]
                NLB / Kong            EKS Workers           Aurora / Redis / MQ
                公网可达              经 NAT 访问外网         无公网访问
                                       ↑                    ↑
                                      Security Group       Security Group
                                      (仅允许 Public 入站)   (仅允许 Private 入站)
```

| 层级 | 部署内容 | 公网访问 | 出站方式 |
|---|---|---|---|
| Public | NLB / Kong Ingress / Bastion | 是（公网可达） | Internet Gateway |
| Private | EKS Worker Node / 应用 Pod | 否 | NAT Gateway |
| Database | Aurora / Redis / MQ | 否 | 无（连 NAT 都没有） |

**Security Group 遵循 Least Privilege：**
- Public → Private: 仅允许 443（HTTPS）
- Private → Database: 仅允许 5432（PostgreSQL）、6379（Redis）
- 禁止 Public → Database 直连
- 禁止 Database → Internet 出站

---

### Q17: How is a three-tier VPC subnet designed? Why?

**Answer:**

The core idea of three-tier subnet isolation: layer resources based on their need for public internet exposure, and use Security Groups to control east-west traffic between layers.

```
Internet ──→ [Public Subnet]  ──→ [Private Subnet]  ──→ [Database Subnet]
                NLB / Kong            EKS Workers           Aurora / Redis / MQ
                Internet-facing       NAT Gateway outbound   No internet
                                       ↑                    ↑
                                      Security Group       Security Group
                                      (only allow Public)   (only allow Private)
```

| Tier | Resources | Internet inbound | Outbound via |
|---|---|---|---|
| Public | NLB / Kong Ingress / Bastion | Yes | Internet Gateway |
| Private | EKS Worker Nodes / App Pods | No | NAT Gateway |
| Database | Aurora / Redis / MQ | No | None (not even NAT) |

**Security Groups — Least Privilege:**
- Public → Private: only 443 (HTTPS)
- Private → Database: only 5432 (PostgreSQL), 6379 (Redis)
- Forbid Public → Database direct
- Forbid Database → Internet egress

---

## 六、可观测性 / Observability

### Q18: 什么是"三个支柱"（Three Pillars of Observability）？你在项目中如何搭建？

**答案：**

可观测性三大支柱：

| | Logging（日志） | Metrics（指标） | Tracing（追踪） |
|---|---|---|---|
| 回答的问题 | 发生了什么事件？ | 系统的数值表现如何？ | 一个请求经过了哪些服务？ |
| 数据粒度 | 事件级别（离散） | 聚合数值 | 请求级别（跨服务） |
| 工具（前公司） | ELK Stack / Cloud Logging | Prometheus + Grafana / CloudWatch | AWS X-Ray |

**在前公司的搭建实践（SAP 项目）：**

**1. Metrics——Prometheus + Grafana**
- 为微服务编写 ServiceMonitor CRD，让 Prometheus 自动抓取 JVM 指标
- 配置 Istio Telemetry API 开启服务网格级指标采集（请求量、成功率、延迟分布）
- 编写 Grafana Dashboard JSON 模板并纳入 Git 管理（Dashboard as Code）
- 三大核心面板：微服务 Golden Signals 大盘、数据库连接池水位面板、MQ 消息积压面板

**2. Tracing——AWS X-Ray**
- 引入 `aws-xray-recorder-sdk-spring` 依赖
- 配合 Istio EnvoyFilter 自动传播 `x-amzn-trace-id` 跨服务传递
- X-Ray Service Map 可视化调用拓扑与延迟热力图，精准定位跨服务调用瓶颈

**3. Logging——ELK / Cloud Logging**
- 应用日志输出到 stdout → K8s 采集 → ELK 索引
- CI/CD 日志和版本控制数据也用 ELK 采集，用于事故根因分析

---

### Q18: What are the Three Pillars of Observability? How did you set them up?

**Answer:**

The three pillars:

| | Logging | Metrics | Tracing |
|---|---|---|---|
| Answers | What happened? | How is the system performing numerically? | Which services did this request touch? |
| Granularity | Event-level (discrete) | Aggregated values | Request-level (cross-service) |
| Tools (prior work) | ELK / Cloud Logging | Prometheus + Grafana / CloudWatch | AWS X-Ray |

**My practice (SAP project):**

**1. Metrics — Prometheus + Grafana**
- Wrote ServiceMonitor CRDs for microservices; Prometheus auto-scrapes JVM metrics
- Configured Istio Telemetry API for service-mesh-level metrics (request volume, success rate, latency distribution) — zero business code changes
- Grafana Dashboard JSON templates under Git (Dashboard as Code)
- Three core dashboards: Golden Signals, DB Connection Pool, MQ Backlog

**2. Tracing — AWS X-Ray**
- Added `aws-xray-recorder-sdk-spring` dependency
- Istio EnvoyFilter auto-propagates `x-amzn-trace-id` across services
- X-Ray Service Map visualizes call topology + latency heatmap → pinpoint cross-service bottlenecks

**3. Logging — ELK / Cloud Logging**
- App logs → stdout → K8s collection → ELK indexing
- CI/CD logs + version control data also indexed in ELK for root cause analysis

---

### Q19: 你提到了 GitOps 后渲染器（post-renderer）为 manifest 打标签，这如何帮助缩短 MTTD？

**答案：**

MTTD（Mean Time To Detect）是指从问题发生到被检测到的平均时间。

**问题场景：** 一次部署引入了一个 bug，K8s 集群中的 Pod 开始报错，告警触发。但从告警中你只能看到 "Pod 报错"，不知道是哪个变更引入的。

**后渲染器的做法：** 在部署时，GitOps 管线的 post-renderer（Kustomize transformer 或 Helm post-renderer）自动为每个 manifest 注入 annotations：

```yaml
metadata:
  annotations:
    gitops.io/commit-sha: "a3f8d2c..."       # 引入这个部署的 Git commit
    gitops.io/pr-number: "1847"               # 关联的 PR
    gitops.io/template-version: "v2.3.1"      # 使用的模板版本
    gitops.io/deployed-at: "2026-07-23T14:30:00Z"
    gitops.io/pipeline-run: "build-38291"
```

**效果：**
当告警触发时，运维人员可以直接从告警中的 Pod annotation 追溯到：
1. 是哪个 PR / commit 引入的（`gitops.io/pr-number`）
2. 是哪个 Pipeline Run 部署的（`gitops.io/pipeline-run`）
3. 用的是哪个版本的 Helm Chart 模板（`gitops.io/template-version`）

不需要查 CI/CD 系统日志、Git 历史、多系统切换——告警报出来直接定位变更来源。MTTD 从「小时级」降低到「分钟级」。

---

### Q19: You mentioned the GitOps post-renderer stamps labels on manifests. How does this reduce MTTD?

**Answer:**

MTTD (Mean Time To Detect) is the average time from issue occurrence to detection.

**Problem:** A deployment introduces a bug; Pods start erroring; alerts fire. But all you see is "Pod is erroring" — you don't know which change caused it.

**Post-renderer approach:** During deployment, the GitOps pipeline's post-renderer (Kustomize transformer or Helm post-renderer) auto-injects annotations into every manifest:

```yaml
metadata:
  annotations:
    gitops.io/commit-sha: "a3f8d2c..."       # Git commit that introduced this deploy
    gitops.io/pr-number: "1847"               # Related PR
    gitops.io/template-version: "v2.3.1"      # Template version used
    gitops.io/deployed-at: "2026-07-23T14:30:00Z"
    gitops.io/pipeline-run: "build-38291"
```

**Result:**
When an alert fires, the operator can trace directly from the Pod's annotations to:
1. Which PR/commit introduced it (`gitops.io/pr-number`)
2. Which pipeline run deployed it (`gitops.io/pipeline-run`)
3. Which Helm chart template version was used (`gitops.io/template-version`)

No need to search CI/CD logs, Git history, or switch between systems — the alert points directly to the change source. MTTD drops from hours to minutes.

---

## 七、HashiCorp Vault / HashiCorp Vault

### Q20: HashiCorp Vault 在你的项目中扮演什么角色？你如何集成它？

**答案：**

Vault 是集中式密钥管理工具，用于安全存储和分发 secrets（API 密钥、数据库密码、kubeconfig、证书）。

**在前公司的实践：**

**1. 统一密钥获取流程**
- 应用 Pipeline 和 GitOps Pipeline 都通过 Vault 获取 secrets
- 标准化了 secret-fetching workflow：kubeconfigs、GitHub tokens、artifactory credentials
- 接入新 region 只需添加一个 Vault path mapping，应用和 GitOps 两条流水线自动复用

**2. 集成方式（K8s Auth Method）**
```bash
# Pipeline 中获取 secret
export KUBECONFIG=$(vault read -field=kubeconfig secret/regions/us20/kubeconfig)
export ARTIFACTORY_TOKEN=$(vault read -field=token secret/shared/artifactory)
```

```yaml
# K8s 中通过 Vault Sidecar Injector 注入 secret
apiVersion: v1
kind: Pod
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "my-app"
    vault.hashicorp.com/agent-inject-secret-db-creds: "database/creds/my-app"
```

**3. 关键原则**
- secrets **绝不**硬编码在代码或 Helm values 中
- secrets **绝不**以明文存储在 Git 中
- 所有 secret 引用通过 Vault path，支持动态轮转

---

### Q20: What role does HashiCorp Vault play in your project? How do you integrate it?

**Answer:**

Vault is a centralized secrets management tool for securely storing and distributing secrets (API keys, database passwords, kubeconfigs, certificates).

**My practice:**

**1. Unified secret-fetching workflow**
- Both application pipeline and GitOps pipeline fetch secrets from Vault
- Standardized workflow for kubeconfigs, GitHub tokens, artifactory credentials
- Onboarding a new region: add one Vault path mapping → both pipelines auto-reuse it

**2. Integration methods (K8s Auth Method)**
```bash
# In pipeline
export KUBECONFIG=$(vault read -field=kubeconfig secret/regions/us20/kubeconfig)
export ARTIFACTORY_TOKEN=$(vault read -field=token secret/shared/artifactory)
```

```yaml
# In K8s via Vault Sidecar Injector
apiVersion: v1
kind: Pod
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "my-app"
    vault.hashicorp.com/agent-inject-secret-db-creds: "database/creds/my-app"
```

**3. Key principles**
- Secrets **never** hardcoded in code or Helm values
- Secrets **never** stored in plaintext in Git
- All secret references via Vault paths, supporting dynamic rotation

---

## 八、安全与合规 / Security & Compliance

### Q21: 你如何在 CI/CD Pipeline 中集成安全扫描？有哪些门禁？

**答案：**

在前公司（SAP 项目），我们运维了 SAP Piper 合规链路，包含以下扫描门禁：

| 扫描工具 | 扫描内容 | 阶段 |
|---|---|---|
| SonarQube | 静态代码分析（bugs, code smells, coverage） | Commit / PR 阶段 |
| CodeQL | GitHub 语义代码分析，发现安全漏洞 | PR 阶段 |
| Checkmarx One | SAST（静态应用安全测试） | 构建阶段 |
| Black Duck | SCA（软件成分分析），开源依赖漏洞扫描 | 构建阶段 |
| PPMS | SAP 内部合规检查（开源许可证合规） | 构建阶段 |
| Cumulus | SAP 内部安全检查 | Release 前阶段 |

**Pipeline 中的位置：**
```
Git Push → PR → CodeQL + SonarQube
       ↓
   PR Merge → Build → Checkmarx + Black Duck + PPMS
       ↓
   Promote → Cumulus → Approve → Release
```

**关键实践：**
- **Fail fast**：尽早发现问题（CodeQL/SonarQube 在 PR 阶段就阻断）
- **Don't work around**：当共享合规步骤存在不足时，修复上游模板库，而不是在每个仓库中绕过
- 帮助兄弟团队（sales-order、fulfillment、manufacturing 等）配置相同的安全门禁

---

### Q21: How do you integrate security scanning into CI/CD Pipelines? What gates do you use?

**Answer:**

At the SAP project, we operated the SAP Piper compliance chain with these gates:

| Tool | What it scans | Stage |
|---|---|---|
| SonarQube | Static code analysis (bugs, code smells, coverage) | Commit / PR |
| CodeQL | GitHub semantic code analysis for vulnerabilities | PR |
| Checkmarx One | SAST (Static Application Security Testing) | Build |
| Black Duck | SCA (Software Composition Analysis), open-source vulns | Build |
| PPMS | SAP internal compliance (open-source license compliance) | Build |
| Cumulus | SAP internal security check | Pre-release |

**Position in the pipeline:**
```
Git Push → PR → CodeQL + SonarQube
       ↓
   PR Merge → Build → Checkmarx + Black Duck + PPMS
       ↓
   Promote → Cumulus → Approve → Release
```

**Key practices:**
- **Fail fast**: Catch issues early (CodeQL/SonarQube blocks at PR stage)
- **Don't work around**: When shared compliance steps are insufficient, fix upstream in the template library, not per repo
- Help sibling teams (sales-order, fulfillment, manufacturing, etc.) configure the same gates

---

## 九、网络与操作系统 / Networking & OS

### Q22: 一个 Web 应用从用户输入 URL 到页面加载完成，经历了哪些步骤？

**答案：**

1. **DNS 解析** — 浏览器查询 DNS，将域名解析为 IP 地址。先查本地缓存 → 递归查询（Root → TLD → 权威 DNS）→ 返回 A/AAAA 记录。
2. **TCP 三次握手** — 客户端发送 SYN → 服务器回复 SYN+ACK → 客户端回复 ACK，连接建立。
3. **TLS 握手（HTTPS）** — 客户端 Hello → 服务器证书 → 密钥交换 → 加密通道建立。
4. **HTTP 请求** — 浏览器发送 HTTP 请求（GET/POST + Headers + Body）。
5. **负载均衡** — 请求到达云服务商的 Load Balancer（如 NLB/ALB）。LB 根据算法（轮询/最少连接）选择后端服务器。
6. **Ingress Controller** — 在 K8s 中，请求到达 Ingress Controller（如 Kong/Nginx），根据 Host/Path 规则路由到对应的 K8s Service。
7. **K8s Service → Pod** — Service 通过 kube-proxy（iptables/IPVS）将流量转发到后端 Pod。
8. **应用处理** — Pod 内的应用处理请求，可能查询数据库、缓存、消息队列。
9. **响应返回** — 原路返回响应（Pod → Service → Ingress → LB → 浏览器）。
10. **浏览器渲染** — 浏览器解析 HTML、CSS、JavaScript，渲染页面。

**排查问题时的关键检查点：**
- DNS：`nslookup <domain>` / `dig <domain>`
- TCP：`telnet <ip> <port>` / `nc -zv <ip> <port>`
- TLS：`openssl s_client -connect <domain>:443` 检查证书是否过期
- HTTP：`curl -v https://<domain>` 查看响应状态码和 headers
- K8s Ingress：`kubectl describe ingress` 查看路由规则
- K8s Service：`kubectl get endpoints` 确认有后端 Pod

---

### Q22: Walk through what happens from entering a URL in the browser to page load.

**Answer:**

1. **DNS resolution** — Browser resolves domain to IP. Local cache → recursive query (Root → TLD → authoritative) → returns A/AAAA record.
2. **TCP three-way handshake** — Client SYN → Server SYN+ACK → Client ACK; connection established.
3. **TLS handshake (HTTPS)** — Client Hello → Server cert → key exchange → encrypted channel.
4. **HTTP request** — Browser sends HTTP request (GET/POST + Headers + Body).
5. **Load balancing** — Request hits cloud Load Balancer (NLB/ALB). LB selects backend server by algorithm (round-robin/least-connections).
6. **Ingress Controller** — In K8s, request reaches Ingress Controller (Kong/Nginx), routed to the correct K8s Service by Host/Path rules.
7. **K8s Service → Pod** — Service uses kube-proxy (iptables/IPVS) to forward traffic to backend Pod.
8. **Application processing** — Pod processes request, possibly querying DB, cache, MQ.
9. **Response return** — Response returns the same path (Pod → Service → Ingress → LB → Browser).
10. **Browser rendering** — Browser parses HTML, CSS, JavaScript, renders the page.

**Key troubleshooting checkpoints:**
- DNS: `nslookup <domain>` / `dig <domain>`
- TCP: `telnet <ip> <port>` / `nc -zv <ip> <port>`
- TLS: `openssl s_client -connect <domain>:443` — check certificate expiry
- HTTP: `curl -v https://<domain>` — check response status and headers
- K8s Ingress: `kubectl describe ingress` — routing rules
- K8s Service: `kubectl get endpoints` — confirm backend Pods exist

---

## 十、综合场景 / Scenario-Based Questions

### Q23: 凌晨 3 点收到 P1 告警——生产环境服务全部 5xx。你怎么办？

**答案：**

**黄金 10 分钟（On-Call 响应流程）：**

**0-2 分钟：确认和分诊**
- 确认告警（是真的生产事故还是误报）
- 打开 Dynatrace / Grafana，确认错误率、响应时间等指标
- 通知相关人员（Slack/WeCom/电话）

**2-5 分钟：快速定位**
```bash
# 是否有最近的部署？
kubectl rollout history deployment/<service> -n prod
kubectl describe deployment/<service> -n prod | grep -A5 "Events"

# Pod 状态如何？
kubectl get pods -n prod | grep -v Running
kubectl describe pod <failing-pod> -n prod

# 日志有什么异常？
kubectl logs <failing-pod> -n prod --tail=100 --previous
```

**5-8 分钟：尝试快速恢复**
- 如果是最新部署引起 → 立即回滚：`kubectl rollout undo deployment/<service> -n prod`
- 如果是基础设施问题（节点故障、网络问题）→ 检查节点状态，必要时驱逐 Pod
- 如果是外部依赖故障（数据库、MQ）→ 确认依赖是否恢复，必要时切换到备用端点

**8-10 分钟：如仍未恢复**
- 升级（escalate）给更资深的同事或 EU/US 班次
- 写清楚交接上下文：什么时间发生了什么、排查了哪些、当前状态是什么
- 持续的 P1 告警 → 考虑启动正式的 Incident Response 流程

**事后（Post-Incident）：**
- 编写 Post-Incident Review（PIR）：时间线、根因、修复措施、预防措施
- 更新监控/告警规则
- 如果是部署引入的，强化 Canary 策略或审批流程

---

### Q23: It's 3 AM and you get a P1 alert — production services are all returning 5xx. What do you do?

**Answer:**

**Golden 10 minutes (On-Call response flow):**

**0-2 min: Confirm & triage**
- Verify the alert (real incident or false alarm?)
- Open Dynatrace / Grafana, confirm error rate, response time
- Notify relevant people (Slack/WeCom/phone)

**2-5 min: Rapid diagnosis**
```bash
# Any recent deployments?
kubectl rollout history deployment/<service> -n prod
kubectl describe deployment/<service> -n prod | grep -A5 "Events"

# Pod status?
kubectl get pods -n prod | grep -v Running
kubectl describe pod <failing-pod> -n prod

# Logs?
kubectl logs <failing-pod> -n prod --tail=100 --previous
```

**5-8 min: Attempt rapid recovery**
- If caused by latest deployment → rollback immediately: `kubectl rollout undo deployment/<service> -n prod`
- If infra issue (node failure, network) → check node status, evict Pods if needed
- If external dependency failure (DB, MQ) → confirm if dependency is recovering, switch to failover endpoint if available

**8-10 min: If still not recovered**
- Escalate to senior colleagues or EU/US shift
- Hand off with clean context: what happened when, what was checked, current state
- Persistent P1 → consider formal Incident Response process

**Post-Incident:**
- Write Post-Incident Review (PIR): timeline, root cause, fix, prevention
- Update monitoring/alerting rules
- If deployment-introduced, strengthen Canary strategy or approval process

---

### Q24: 面试官问："你在前公司的 CI/CD 体系中，最有成就感的一件事是什么？"

**建议回答（参考前同事实际工作内容）：**

**方案一——Jenkins Shared Library 推广：**
"在 HSBC 项目中，我引入了 Jenkinsfile DSL Shared Library，将原本每个团队各写各的 Pipeline 代码（有的 500+ 行 Shell 脚本）标准化为 JSON 声明式调用。开发者不再需要学 Groovy，只需写一个 JSON 文件描述 pipeline 行为。这不仅减少了 80% 的 Pipeline 代码量，更重要的是统一了所有项目的构建、扫描、部署流程——当安全团队要求全员加入新的合规扫描时，我只需在 Shared Library 中改动一处，所有项目自动生效。"

**方案二——多区域环境的快速接入：**
"在 SAP 项目中，接入一个新区域（如 SA31）的部署在过去需要一周的时间。我重构了 GitOps 基础设施：标准化了 Helm values 级联、Vault path 映射，使得接入新区域的工作简化为三步：新建一个 values 文件 + 新建 Vault path mapping + Azure DevOps 加一个 stage。将接入时间从一周缩短到半天。后来我 even 把整个流程自动化了——新区域接入完全由模板生成器驱动。"

**方案三——变更追踪降低 MTTD：**
"我在 GitOps 流水线中实现了 post-renderer，为每个部署到集群的 manifest 自动注入变更来源 annotations（PR number、commit SHA、pipeline run ID）。以前生产出问题，Ops 团队需要 30 分钟以上去排查"是哪个部署引入的"，现在一看告警就能直接从 Pod metadata 定位到具体的 PR——MTTD 从 30+ 分钟降到 2 分钟。这个改动后来被推广到所有 SBNC 服务。"

---

### Q24: Interviewer asks: "What are you most proud of in your CI/CD work at your previous company?"

**Suggested answers:**

**Option 1 — Jenkins Shared Library promotion:**
"At HSBC, I introduced the Jenkinsfile DSL Shared Library, standardizing what had been individual teams writing their own Pipeline code (some were 500+ line Shell scripts) into JSON-based declarative invocations. Developers no longer needed to learn Groovy — they just wrote a JSON file. This reduced Pipeline code volume by 80%. More importantly, it unified the build, scan, and deploy workflows across all projects. When the security team mandated a new compliance scan for everyone, I only needed to change one place in the Shared Library and all projects picked it up automatically."

**Option 2 — Multi-region rapid onboarding:**
"At the SAP project, onboarding a new region (e.g., SA31) used to take a week. I refactored the GitOps infrastructure: standardized the Helm values cascade and Vault path mappings, reducing new region onboarding to three steps: create a values file + add a Vault path mapping + add an Azure DevOps stage. Onboarding time dropped from a week to half a day. Later I automated the entire flow — new region onboarding is now entirely template-generator driven."

**Option 3 — Change traceability reducing MTTD:**
"I implemented a post-renderer in the GitOps pipeline that auto-injects change-source annotations (PR number, commit SHA, pipeline run ID) into every manifest deployed to the cluster. Previously when production had issues, the Ops team needed 30+ minutes to figure out 'which deployment introduced this.' Now they can trace from the alert directly to the specific PR via Pod metadata — MTTD dropped from 30+ minutes to 2 minutes. This change was later adopted across all SBNC services."

---

### Q25: 你如何看待 On-Call？如何处理夜班？

**答案：**

**我对 On-Call 的态度：**
- On-Call 是 DevOps 岗位的核心职责之一，不是额外的负担。代码是我们写的，基础设施是我们管理的，我们就应该对它负责。
- On-Call 的目标不是"永远不响"，而是"响了能快速处理"和"逐步减少告警"。

**我的 On-Call 经验（前公司 HSBC 项目）：**
- 之前我参与了 On-Call Night Shift 轮值，配置了基于 XMatters 的分级告警体系：
  - P1（生产中断）：电话 + 短信，10 分钟响应
  - P2（性能降级）：企业微信，30 分钟响应
- 按 SOP 处理生产告警并维护值班日志供事后复盘

**处理方式：**
1. 确认告警：是真的故障还是误报
2. 分诊：影响范围——所有用户还是部分？哪个 region？
3. 快速恢复优先：先回滚/重启，恢复服务，再慢慢排查根因
4. 如果超过自己的能力/时间窗口（比如深度数据库问题），及时升级给更合适的人，写清楚上下文
5. 事后写复盘：根因是什么、怎么防止再次发生

**我会如何改进：**
- 降低告警噪音：调整阈值，减少误报
- 通过 GitOps 变更追踪缩短 MTTD（定位到具体 PR/commit）
- 建立 Runbook（操作手册），让常见问题的处理流程标准化

---

### Q25: What's your view on On-Call? How do you handle night shifts?

**Answer:**

**My attitude toward On-Call:**
- On-Call is a core responsibility of DevOps, not an extra burden. We write the code, we manage the infrastructure — we should own it.
- The goal of On-Call isn't "never get paged," but "handle pages quickly" and "gradually reduce alert volume."

**My On-Call experience (HSBC project):**
- I participated in On-Call Night Shift rotations and configured a tiered alert system based on XMatters:
  - P1 (production outage): phone + SMS, 10-minute response
  - P2 (performance degradation): WeCom, 30-minute response
- Handled production alerts following SOP and maintained duty logs for post-incident review

**My approach:**
1. Confirm: real incident or false alarm?
2. Triage: blast radius — all users or partial? Which region?
3. Prioritize rapid recovery: rollback/restart to restore service first, then deep-dive root cause later
4. If beyond my capacity/time window (e.g., deep database issue), escalate promptly to the right person with clean context
5. Post-incident: write a review — root cause, prevention measures

**How I'd improve:**
- Reduce alert noise: tune thresholds, cut false positives
- Shorten MTTD via GitOps change traceability (pinpoint to specific PR/commit)
- Build Runbooks to standardize common incident responses

---

## 附录 / Appendix

### 常用 Kubernetes 排错命令速查 / Common K8s Troubleshooting Commands

```bash
# Pod 相关
kubectl get pods -n <ns> -o wide                    # Pod 列表 + 节点信息
kubectl describe pod <pod> -n <ns>                   # Pod 详情 + Events
kubectl logs <pod> -n <ns> --tail=100                # 当前日志
kubectl logs <pod> -n <ns> --previous                # 上一次崩溃日志
kubectl exec -it <pod> -n <ns> -- /bin/sh            # 进入容器
kubectl top pod <pod> -n <ns>                        # CPU/内存使用

# Deployment 相关
kubectl describe deployment <deploy> -n <ns>         # 部署详情
kubectl rollout history deployment/<deploy> -n <ns>  # 部署历史
kubectl rollout undo deployment/<deploy> -n <ns>     # 回滚
kubectl rollout restart deployment/<deploy> -n <ns>  # 重启

# Service 相关
kubectl get svc -n <ns>                              # Service 列表
kubectl get endpoints <svc> -n <ns>                  # 检查后端 Pod
kubectl describe svc <svc> -n <ns>                   # Service 详情

# 网络排查
kubectl get networkpolicies -n <ns>                  # 网络策略
kubectl run debug --image=nicolaka/netshoot -it --rm -- /bin/bash   # 临时排查 Pod
nslookup <svc>.<ns>.svc.cluster.local                # DNS 解析
curl -v http://<svc>:<port>/health                   # HTTP 连通测试

# 事件
kubectl get events -n <ns> --sort-by='.lastTimestamp' | tail -50    # 最近事件

# 节点
kubectl get nodes -o wide                             # 节点列表
kubectl describe node <node>                          # 节点详情
kubectl cordon <node>                                 # 停止调度
kubectl drain <node> --ignore-daemonsets               # 驱逐 Pod
```

---

> **最后提示：** 面试时要展现的关键特质——
> 1. 遇到生产问题第一反应是"恢复服务"而不是"找原因"
> 2. 能用 kubectl 命令行描述问题的每一步排查
> 3. 了解自己搭建的体系的"为什么"——为什么用 Canary 而不是 Blue-Green、为什么 values 要级联而不是一个文件打天下
> 4. 有跨时区协作经验，了解如何与 EU/US 班次做高效上下文交接
>
> **Final tip:** Key traits to demonstrate in the interview —
> 1. Your first instinct during a production incident is "restore service," not "find root cause"
> 2. You can describe every troubleshooting step with kubectl commands
> 3. You understand the "why" behind your architecture choices — why Canary over Blue-Green, why values cascade instead of one flat file
> 4. You have cross-timezone collaboration experience and know how to hand off clean context to EU/US shifts
