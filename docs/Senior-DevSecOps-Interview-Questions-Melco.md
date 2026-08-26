# 高级 DevSecOps 工程师 面试题集（中英双语）

# Senior DevSecOps Engineer — Interview Question Bank (Bilingual)

> 针对 **Melco (澳门新濠) — Senior DevSecOps Engineer** JD，结合 **Smart Invest 项目**（AWS + K3S + Terraform + Helm + Spring Cloud 微服务）量身定制。
> Tailored for the **Melco Senior DevSecOps Engineer** JD, grounded in the **Smart Invest** project (AWS + K3S + Terraform + Helm + Spring Cloud microservices).

---

## 使用方法 / How to Use

每道题包含四部分：中文题干 → 英文题干 → 中文答案 → 英文答案，并附「项目映射」说明如何用 Smart Invest 的真实细节作答。
Each question has: Chinese prompt → English prompt → Chinese answer → English answer, plus a **Project mapping** note on how to answer using real Smart Invest details.

回答时优先讲**你的项目怎么做的、为什么这么选**，再扩展到通用最佳实践——这正是 Senior 岗位要的「全局思维 + 落地经验」。
When answering, lead with *what you did in your project and why*, then generalize to best practices — this is exactly the "holistic thinking + hands-on experience" a Senior role wants.

---

## 目录 / Table of Contents

1. CI/CD 与 GitOps
2. 基础设施即代码 (IaC / Terraform)
3. Kubernetes 与 Helm
4. 容器与镜像
5. 云与网络 (AWS / VPC / 服务网格)
6. DevSecOps 安全
7. 监控、可观测性与告警
8. 可靠性与故障排查 (SRE / RCA)
9. 脚本与自动化 (Python / Bash / Go / Ansible)
10. 行为与软技能

---

## 一、CI/CD 与 GitOps

### Q1. 描述你设计的一条完整的 CI/CD 流水线，从代码提交到生产上线经历了哪些阶段？

**EN:** Describe a complete CI/CD pipeline you designed — what stages does it go through from code commit to production?

**答（中文）：**
一条标准的云原生 Java 流水线分六个阶段：① 开发者提交代码（commit / 打 tag）→ ② 编译打包（`mvn clean package` 产出 jar）→ ③ 构建镜像（Dockerfile 多阶段构建）→ ④ 推送镜像到私有仓库（Harbor / ECR / ACR）→ ⑤ 更新部署清单中的镜像版本号 → ⑥ 执行 `kubectl apply` 触发滚动更新。
关键设计点：**只有 Deployment 的 `image` 字段会变，Service 从来不更新**——Service 的职责是稳定的负载均衡和固定域名，靠 Label Selector 自动发现新 Pod。最后用 `kubectl rollout status --timeout=2m` 做金标验证，失败即回滚。

**Answer (EN):**
A standard cloud-native Java pipeline has six stages: ① developer commits code (commit/tag) → ② compile/package (`mvn clean package` produces a jar) → ③ build image (multi-stage Dockerfile) → ④ push to a private registry (Harbor/ECR/ACR) → ⑤ update the image tag in the deployment manifest → ⑥ `kubectl apply` triggers a rolling update.
Key design point: **only the Deployment's `image` field changes; Service is never updated** — Service's job is stable load balancing and a fixed DNS name, and it auto-discovers new Pods via label selectors. Finish with `kubectl rollout status --timeout=2m` as a golden check; fail and roll back.

**项目映射：** Smart Invest 用 GitHub Actions（规划中）+ 脚本化部署；我写过一套 `scripts/deploy.sh`、`build-images.sh`、`build-amd64.sh` 的编排，以及 `gitlab-ci.yml` 六阶段范例。

---

### Q2. 什么是 GitOps？Push 模式和 Pull 模式有什么区别？为什么大厂更倾向 ArgoCD 的 Pull 模式？

**EN:** What is GitOps? What's the difference between push and pull models, and why do larger orgs prefer ArgoCD's pull model?

**答（中文）：**
GitOps 的核心是把 **Git 仓库当作唯一的真实状态源（single source of truth）**：集群的期望状态由 Git 里的 YAML 声明，自动化工具持续把集群对账到该状态。

- **Push 模式**：CI 工具（Jenkins/GitLab）直接拿着 `kubectl` 去改集群——CI 工具需要握有集群的高权限凭证，且「谁改的、改了什么」不完全可审计。
- **Pull 模式**：集群里跑一个 **ArgoCD**（或 Flux），它盯着配置仓库，一旦发现 Git 里镜像版本变了，就自己把集群更新到一致。优点：① CI 不再需要集群写权限，攻击面更小；② Git 提交历史天然就是审计日志；③ 删掉某个 Deployment，ArgoCD 会立刻重建，实现**持续对账（reconciliation）**防漂移。

**Answer (EN):**
GitOps means treating **Git as the single source of truth**: the cluster's desired state is declared in YAML in Git, and automation continuously reconciles the cluster to that state.

- **Push model**: the CI tool (Jenkins/GitLab) runs `kubectl` directly against the cluster — it needs high-privilege credentials, and "who changed what" isn't fully auditable.
- **Pull model**: an **ArgoCD** (or Flux) agent runs inside the cluster, watches the config repo, and self-updates the cluster when the image tag changes. Benefits: ① CI no longer needs cluster write access (smaller attack surface); ② Git commit history is the audit log; ③ deleting a Deployment causes ArgoCD to recreate it — continuous **reconciliation** prevents drift.

**项目映射：** JD 明确要求 ArgoCD。我可以讲：Smart Invest 目前是脚本 push 部署，但我理解 GitOps 的价值，并能说明迁移到 ArgoCD 的路径（代码仓管镜像、独立配置仓管 YAML、ArgoCD 拉取）。

---

### Q3. 如何做金丝雀发布（Canary）和蓝绿部署（Blue-Green）？在 K8s 里各用什么机制实现？

**EN:** How do you implement canary and blue-green deployments? What K8s mechanisms back each?

**答（中文）：**

- **蓝绿部署**：同时跑两套完整环境（蓝=旧、绿=新），流量一次性切换到绿，出问题立刻切回。K8s 里用两个 Deployment + 切换 Service 的 selector，或在 Service Mesh 里切权重。缺点是瞬时需要双倍资源。
- **金丝雀发布**：新版本先接 1%~10% 流量，观察错误率/延迟，逐步放大到 100%。实现方式：① **Ingress 权重**（如 Nginx Ingress / Traefik 的 canary annotation）；② **Service Mesh**（Istio VirtualService 的 `weight` 字段，可精确到 1%，还能做流量镜像 `mirror` 和故障注入 `fault`）；③ **Argo Rollouts** 做声明式渐进交付。
- 关键配套：灰度期间必须有**可观测性**（对比新旧版本的 P99 延迟、错误率），否则灰度就是盲发。

**Answer (EN):**

- **Blue-green**: run two full environments (blue=old, green=new), switch all traffic to green at once, switch back instantly on failure. In K8s: two Deployments + flip the Service selector, or flip weights in a service mesh. Down side: 2× resources at cutover.
- **Canary**: route 1%–10% of traffic to the new version, watch error rate/latency, ramp to 100%. Implementations: ① **Ingress weights** (Nginx Ingress / Traefik canary annotations); ② **Service Mesh** (Istio VirtualService `weight`, precise to 1%, plus `mirror` for traffic mirroring and `fault` for fault injection); ③ **Argo Rollouts** for declarative progressive delivery.
- Essential companion: **observability** during the rollout (compare old vs new P99 latency and error rate) — otherwise a canary is flying blind.

**项目映射：** 我深入评估过 Istio，VirtualService 的 `weight` 能做金丝雀、`mirror` 做流量镜像、`fault` 做故障注入；但因项目是 2vCPU/4GB 的单节点 K3S、单版本部署，权衡后选了 Traefik + Spring Cloud Gateway 的更轻方案。

---

### Q4. 一个流水线跑了 8 分钟，你觉得慢，怎么定位并优化？

**EN:** A pipeline takes 8 minutes and you want it faster. How do you find and fix the bottleneck?

**答（中文）：**
先**测量再优化**：给每个 stage/job 加耗时埋点（GitLab/Jenkins 自带 timing 视图），找出占比最大的阶段。常见优化：

- **依赖缓存**：Maven `dependency:go-offline` + 缓存 `~/.m2`，npm 缓存 `node_modules`——利用 Docker layer 缓存，`pom.xml`/`package.json` 不变就不重下依赖。
- **并行化**：把互不依赖的 job 并行（多服务同时 build），用 matrix build。
- **多阶段构建瘦身**：把 jar 打进 `openjdk-slim`，只 COPY 产物，镜像体积缩 80%，push/pull 都快。
- **缓存测试**：只跑变更相关的测试，或分单元/集成测试两段，集成测试后置。
- **更快的构建工具**：前端 Vite/esbuild，后端 Maven 并行构建 `-T 1C`。
- **镜像加速**：用更近的 registry、layer 复用。

**Answer (EN):**
Measure before optimizing: add per-stage timing (GitLab/Jenkins timing views) and find the dominant stage. Common fixes:

- **Dependency caching**: Maven `dependency:go-offline` + cache `~/.m2`, npm cache `node_modules` — leverage Docker layer caching so dependencies aren't re-downloaded when `pom.xml`/`package.json` is unchanged.
- **Parallelize**: run independent jobs concurrently (build multiple services at once), use matrix builds.
- **Slim images via multi-stage build**: copy only the jar into `openjdk-slim`; image shrinks ~80%, so push/pull is faster.
- **Cache tests**: run only changed-scope tests, or split unit vs integration (integration later).
- **Faster build tools**: Vite/esbuild on frontend, Maven parallel `-T 1C` on backend.
- **Registry proximity** and layer reuse.

**项目映射：** 我的 `build-images.sh` 用多阶段构建 + Alpine 精简镜像；`build-amd64.sh` 处理 arm64→amd64 跨架构构建。

---

## 二、基础设施即代码 (IaC / Terraform)

### Q5. 你的 Terraform 项目是怎么组织目录结构的？为什么要用 live/modules 分层？

**EN:** How do you structure a Terraform project, and why split live/ from modules/?

**答（中文）：**
我用 **live/modules 模式**：

- `modules/`：可复用模块（如 networking、compute、iam、cdn），每个模块封装一类资源，有独立的 `variables.tf`/`outputs.tf`，**不带任何环境专属值**。
- `live/`：环境实例（如 `live/prod`），通过 `module` 块调用模块并传入该环境的具体参数（`terraform.tfvars`）。

好处：① **复用**——多环境（prod/staging）共享同一套模块，改逻辑改一处；② **清晰**——模块是「能力」，live 是「配置」，职责分离；③ **团队协作**——不同人维护模块 vs 环境配置不互相踩；④ **环境隔离**——每个 live 目录独立 state，避免一个环境污染另一个。

**Answer (EN):**
I use the **live/modules pattern**:

- `modules/`: reusable modules (networking, compute, iam, cdn), each encapsulating one resource family with its own `variables.tf`/`outputs.tf` and **no environment-specific values**.
- `live/`: environment instances (e.g. `live/prod`) that call modules via `module` blocks with that environment's values (`terraform.tfvars`).

Benefits: ① **reuse** — prod/staging share modules, change logic once; ② **clarity** — modules are "capability", live is "configuration"; ③ **team collaboration** — people maintain modules vs env configs without stepping on each other; ④ **isolation** — each live dir has its own state, so one env can't pollute another.

**项目映射：** Smart Invest 的 `infrastructure/terraform/` 正是 live/prod + modules/{networking,compute,iam,cdn} 结构，四个模块分别管安全组/VPC 查询、EC2+EIP、IAM 角色、S3+CloudFront+WAF。

---

### Q6. Terraform state 为什么不能只放在本地？你通常怎么管理 state 和 lock？

**EN:** Why shouldn't Terraform state live only locally? How do you manage state and locking?

**答（中文）：**
State 是 Terraform 的「现实快照」：它记录了资源 ID 和属性与真实云资源的映射。放本地有三个致命问题：① **团队协作冲突**——两个人同时 `apply` 会互相覆盖、状态分裂；② **丢失风险**——本地文件没了，Terraform 无法感知已有资源，会重建导致资源漂移甚至误删；③ **敏感信息泄露**——state 里可能含明文密钥/密码。

标准做法：**Remote backend + 锁**。用 S3（或 GCS/Azure Storage）存 state 文件，开启版本控制（可回滚），配合 DynamoDB（或等价的锁服务）做 **state locking**，保证同一时刻只有一个人能 `apply`。还要配合 CI 里的 `terraform plan` 在 PR 阶段跑，`apply` 只在合并后跑。

**Answer (EN):**
State is Terraform's "snapshot of reality": it maps resource IDs/attributes to real cloud resources. Local-only state has three fatal problems: ① **team conflicts** — two simultaneous `apply`s overwrite each other and fork state; ② **loss risk** — losing the file means Terraform can't see existing resources, causing drift or accidental recreation; ③ **secrets exposure** — state can contain plaintext secrets/passwords.

Standard: **remote backend + lock**. Store state in S3 (or GCS/Azure Storage) with versioning for rollback, paired with DynamoDB (or an equivalent lock service) for **state locking** so only one `apply` runs at a time. Also run `terraform plan` in the PR stage, `apply` only after merge.

---

### Q7. Terraform 里怎么安全地管理密钥（如 DB 密码）？能不能明文写进 `variables.tf` 或 state？

**EN:** How do you manage secrets (e.g. DB passwords) in Terraform safely? Can they go in `variables.tf` or state?

**答（中文）：**
**绝不能**明文写进代码或 `terraform.tfvars`（会进 Git）或 output（会进 state）。正确分层：

- **Secret 来源**：从 AWS Secrets Manager / SSM Parameter Store / Vault 读取，用 `data` source 动态获取，Terraform 代码里只有引用、没有明文。
- **敏感标记**：变量声明 `sensitive = true`，避免在 plan/apply 输出里打印明文；output 也标 `sensitive`。
- **最小权限**：运行 Terraform 的 CI 用临时凭证（OIDC / Instance Profile），不要用长期 Access Key。
- **state 加密**：S3 backend 开服务端加密（SSE-KMS）。
- **兜底**：即便 state 里不可避免含敏感引用，也要限制谁能读 backend。

**Answer (EN):**
**Never** put secrets in plaintext in code or `terraform.tfvars` (goes to Git) or outputs (goes to state). Layered approach:

- **Secret source**: read from AWS Secrets Manager / SSM Parameter Store / Vault via `data` sources — the code holds references, not plaintext.
- **Sensitive flag**: mark variables `sensitive = true` so plan/apply output redacts them; mark outputs sensitive too.
- **Least privilege**: the CI running Terraform uses short-lived credentials (OIDC / Instance Profile), not long-lived Access Keys.
- **Encrypt state**: S3 backend with server-side encryption (SSE-KMS).
- **Last resort**: restrict who can read the backend even if state holds sensitive references.

**项目映射：** Smart Invest 用 **IAM Instance Profile** 而非 Access Key（EC2 自动拿临时凭证），Secrets Manager 已预留并绑定策略，Helm 里 DB 密码走 K8s Secret。

---

### Q8. 什么是 Terraform drift（漂移）？怎么检测和修复？

**EN:** What is Terraform drift? How do you detect and fix it?

**答（中文）：**
Drift 指**真实云资源状态与 state/代码声明不一致**——例如有人手动在控制台改了安全组、删了某条规则。`terraform plan` 会把当前 state 与真实资源对比，若被手动改动，plan 会显示要「改回去」的 diff。检测手段：① 定期跑 `terraform plan`（CI 定时任务）或 `terraform refresh`；② 用 AWS Config / Cloud Custodian 这类合规工具兜底。修复：以代码为真源，`terraform apply` 把资源对齐回声明状态；若改动是合理的，就先把改动写进代码再 apply（避免「代码正确化」反复拉扯）。

**Answer (EN):**
Drift means **the real cloud resources no longer match the state/code declaration** — e.g. someone manually edited a security group or deleted a rule in the console. `terraform plan` compares state against real resources and, if something was hand-changed, shows a diff to "change it back". Detection: ① scheduled `terraform plan` (CI cron) or `terraform refresh`; ② backstop with AWS Config / Cloud Custodian compliance tools. Fix: treat code as the source of truth and `terraform apply` to reconcile; if the change was intentional, codify it first then apply (avoid endless "code corrects itself" tug-of-war).

---

## 三、Kubernetes 与 Helm

### Q9. K3S 和 EKS 的区别是什么？你在生产环境会怎么选？

**EN:** What's the difference between K3S and EKS, and how would you choose for production?

**答（中文）：**

- **EKS**：AWS 托管的完整 K8s，控制面由 AWS 负责（高可用、自动升级），多 AZ、自动扩缩，适合大规模、多团队、要求 SLA 的生产场景；代价是控制面单独收费（$73+/月）+ 运维复杂度。
- **K3S**：轻量级 K8s 发行版，单二进制，内置 Traefik + CoreDNS，资源占用极低（几百 MB），可跑在单节点或边缘设备上；控制面自己管，适合小规模、成本敏感、边缘场景。
- **选型原则**：按规模、SLA、成本、团队运维能力权衡。**大规模 + 高可用 SLA → EKS；成本敏感 + 中小规模 + 单区域 → K3S/自建**。

**Answer (EN):**

- **EKS**: AWS-managed full Kubernetes; AWS runs the control plane (HA, auto-upgrades), multi-AZ, auto-scaling; suited for large-scale, multi-team, SLA-bound production. Cost: control plane alone is ~$73+/mo plus operational complexity.
- **K3S**: a lightweight K8s distribution — single binary, bundled Traefik + CoreDNS, hundreds of MB of RAM, runs on a single node or edge devices; you manage the control plane. Good for small scale, cost-sensitive, and edge scenarios.
- **Choosing**: weigh scale, SLA, cost, and team ops capability. **Large scale + HA SLA → EKS; cost-sensitive + small/medium + single region → K3S/self-managed.**

**项目映射：** Smart Invest 明确做了这个取舍——单 EC2 (t3.medium) + K3S，成本约 $35/月 vs EKS 控制面单独 $73+/月；中间件（PostgreSQL/RabbitMQ）也自托管而非买 RDS/AmazonMQ，零托管服务费。

---

### Q10. Deployment 和 StatefulSet 有什么区别？为什么 PostgreSQL 一定要用 StatefulSet？

**EN:** What's the difference between Deployment and StatefulSet? Why must PostgreSQL use a StatefulSet?

**答（中文）：**

- **Deployment**：无状态应用的默认选择，Pod 可互换、无身份，通常配 ReplicaSet 做滚动更新；适合 API 服务、Worker 等。
- **StatefulSet**：为有状态应用设计，给每个 Pod 一个**稳定且唯一**的身份（`postgresql-0`、`postgresql-1`）和**稳定的网络标识**（Headless Service + 有序 DNS），并配合 **PVC 持久化**，Pod 重启/重调度后数据不丢，且**有序地**创建/更新/删除（0→1→2）。

PostgreSQL 必须用 StatefulSet 的原因：① **数据持久化**——每个实例绑一个专属 PVC，Pod 漂移到别的节点卷还跟着；② **主从/集群需要稳定身份**——副本要知道「谁是 0、谁是 1」来做复制和选主；③ **有序扩缩容和滚动更新**，避免同时宕库。

**Answer (EN):**

- **Deployment**: default for stateless apps; Pods are interchangeable and identity-free, usually backed by a ReplicaSet for rolling updates. Good for API services and workers.
- **StatefulSet**: designed for stateful apps; gives each Pod a **stable, unique identity** (`postgresql-0`, `postgresql-1`) and a **stable network identity** (Headless Service + ordered DNS), plus **PVC persistence** so data survives restarts/rescheduling, with **ordered** create/update/delete (0→1→2).

PostgreSQL needs StatefulSet because: ① **persistence** — each instance gets a dedicated PVC that follows the Pod across nodes; ② **replication/HA needs stable identity** — replicas must know "who is 0, who is 1" to replicate and elect a leader; ③ **ordered scaling and rolling updates** avoid taking the whole DB down at once.

**项目映射：** Smart Invest 的 `postgresql` chart 正是 StatefulSet + Headless Service + PVC；RabbitMQ 用 Deployment + 单 PVC。这是我在 JD「container orchestration」要求下的直接落地。补充：RabbitMQ 用 Deployment + 单 PVC 是**单实例**的成本取舍——Deployment 引用的是固定的 `claimName: rabbitmq-data`，副本数一旦 >1，多个实例会共享同一个 RWO PVC，数据直接损坏。要 RabbitMQ/Redis 集群 HA，须换 StatefulSet + Headless Service + volumeClaimTemplates（集群节点靠稳定 hostname 互相发现、每节点独享 PVC；Redis Sentinel/Cluster 同理）。Redis 在项目里同为 Deployment + 可选 PVC（`persistence.enabled`），纯缓存时可关掉 PVC。

---

### Q11. Service 和 Ingress 分别解决什么问题？你的项目里流量是怎么从外网到达微服务的？

**EN:** What problems do Service and Ingress solve? How does traffic reach your microservices from the internet?

**答（中文）：**

- **Service**：集群内部的**稳定抽象**——Pod IP 会变，Service 提供固定 ClusterIP 和稳定 DNS（`postgresql.smart-invest.svc.cluster.local`），通过 Label Selector + kube-proxy 做负载均衡，解决「服务发现 + 内部负载均衡」。
- **Ingress**：集群**对外的统一入口**——把外部 HTTP(S) 流量按 Host/Path 路由到内部 Service，可做 TLS 终结、限流、灰度。

我的项目流量路径：**外网 → CloudFront CDN → WAF → S3（静态资源）/ EC2 → K3S Traefik Ingress → 按 `/api/*` 路由到 Spring Cloud Gateway (8080) → 网关按 JWT 校验 + 路由分发到 user/fund/order 服务**。这里有两层路由：Traefik 做外层 L7 入口，Spring Cloud Gateway 做内层 API 网关（认证、限流、聚合）。

**Answer (EN):**

- **Service**: a **stable abstraction inside the cluster** — Pod IPs change, but a Service gives a fixed ClusterIP and stable DNS (`postgresql.smart-invest.svc.cluster.local`), load-balancing across Pods via label selectors + kube-proxy. It solves service discovery + internal load balancing.
- **Ingress**: a **single external entry point** — routes external HTTP(S) traffic to internal Services by Host/Path, and can do TLS termination, rate limiting, and canary.

My project's traffic path: **internet → CloudFront CDN → WAF → S3 (static) / EC2 → K3S Traefik Ingress → route `/api/*` to Spring Cloud Gateway (8080) → JWT validation + route to user/fund/order services**. Two routing layers: Traefik as the outer L7 entry, Spring Cloud Gateway as the inner API gateway (auth, rate limiting, aggregation).

---

### Q12. Helm 的 Umbrella Chart 是什么？为什么用它来部署整个系统？

**EN:** What is a Helm Umbrella Chart, and why use it to deploy a whole system?

**答（中文）：**
Umbrella Chart 是一个**聚合 Chart**：它自己不直接定义工作负载，而是在 `Chart.yaml` 里 `dependencies` 声明多个子 Chart，一条 `helm install` 就把所有组件（9 个：6 微服务 + PostgreSQL + RabbitMQ + Redis）一起装起来。
好处：① **一键部署**——单命令拉起整个系统；② **版本独立管理**——每个子 Chart 有独立 version，可单独升级某个服务而不动其他；③ **统一配置覆盖**——在 umbrella 的 `values-prod.yaml` 里集中覆盖所有子 Chart 的参数（副本数、镜像 tag）；④ **依赖编排**——配合 Helm hook（如等待 RabbitMQ 就绪的 pre-install hook）控制启动顺序。

**Answer (EN):**
An Umbrella Chart is an **aggregation chart**: it doesn't define workloads itself, but declares multiple sub-charts under `dependencies` in `Chart.yaml`, so a single `helm install` deploys everything (9 components: 6 microservices + PostgreSQL + RabbitMQ + Redis) at once.
Benefits: ① **one-command deploy** — spin up the whole system with one command; ② **independent versioning** — each sub-chart has its own version, so you can upgrade one service without touching others; ③ **centralized overrides** — `values-prod.yaml` in the umbrella overrides all sub-charts' params (replica count, image tag); ④ **dependency orchestration** — Helm hooks (e.g. a pre-install hook waiting for RabbitMQ readiness) control startup order.

**项目映射：** Smart Invest 的 `infrastructure/helm/umbrella` 正是这样——9 个依赖、`values-prod.yaml`（2 副本 + 1.1.0 镜像 tag）、`rabbitmq-ready-hook.yaml` 预安装钩子、`secret.yaml` 统一 K8s Secret。

---

### Q13. 什么是 Helm hook？你项目里怎么保证 RabbitMQ 就绪后才启动依赖它的服务？

**EN:** What is a Helm hook, and how do you ensure RabbitMQ is ready before dependent services start?

**答（中文）：**
Helm hook 是在 Chart 生命周期特定时点执行的**一次性资源**（`pre-install`/`post-install`/`pre-upgrade` 等），通常是一个 Job，用完后会自动清理。用途：跑迁移、等待依赖就绪、做初始化。
我的做法：写一个 `rabbitmq-ready-hook.yaml` 的 pre-install Job，在安装阶段轮询 RabbitMQ 的 readiness（`curl` 健康检查 / `kubectl wait`），直到它就绪才让 `helm install` 继续装下游服务。这样避免了服务启动时 RabbitMQ 还没起来导致的连接失败和 crash-loop。

**Answer (EN):**
A Helm hook is a **one-shot resource** (a Job) executed at a specific lifecycle point (`pre-install`/`post-install`/`pre-upgrade`), cleaned up after use. Uses: run migrations, wait for dependencies, initialize.
My approach: a `rabbitmq-ready-hook.yaml` pre-install Job that polls RabbitMQ's readiness (`curl` health check / `kubectl wait`) until it's up before `helm install` proceeds to deploy downstream services. This avoids connection failures and crash-loops when services start before RabbitMQ is ready.

---

### Q14. readinessProbe 和 livenessProbe 的区别？配置不当会导致什么问题？

**EN:** What's the difference between readiness and liveness probes? What goes wrong if misconfigured?

**答（中文）：**

- **livenessProbe（存活探针）**：判断「进程是否还活着」。失败 → K8s **重启容器**。用于自救卡死、死锁的进程。配错（比如检查太重、阈值太短）会导致**容器被反复误杀重启**。
- **readinessProbe（就绪探针）**：判断「是否能接流量」。失败 → 把 Pod 从 Service 的 endpoints 里摘除，但**不重启**。用于等应用初始化（DB 连接、缓存预热）。配错会导致**服务永远不在 endpoints 里**（流量进不来）或**没就绪就接流量**（请求 5xx）。
- 关键点：**滚动更新靠 readiness**——新 Pod 就绪探针通过才引入流量；存活探针失败才重启。二者职责不能混。

**Answer (EN):**

- **livenessProbe**: "is the process alive?" On failure → K8s **restarts the container**. Used to self-heal stuck/deadlocked processes. Misconfigured (too heavy a check, too short threshold) → containers are repeatedly killed and restarted.
- **readinessProbe**: "can it serve traffic?" On failure → remove the Pod from the Service's endpoints, but **do not restart**. Used to wait for init (DB connection, cache warm-up). Misconfigured → the service is never in endpoints (no traffic) or serves traffic before ready (5xx).
- Key: **rolling updates rely on readiness** — new Pods get traffic only after readiness passes; liveness failure triggers restart. The two roles must not be mixed.

---

### Q15. Spring Boot 应用在 K8s 里怎么实现优雅停机（graceful shutdown）？为什么需要 preStop 钩子？

**EN:** How do you implement graceful shutdown for a Spring Boot app on K8s, and why do you need a preStop hook?

**答（中文）：**
要**双向配置**：

1. **应用层**：Spring Boot 2.3+ 支持 `server.shutdown: graceful` + `spring.lifecycle.timeout-per-shutdown-phase: 30s`。收到 SIGTERM 后拒绝新请求、等线程池里的存量任务跑完（或到 30s 上限）再退出。
2. **K8s 层**：`preStop` 钩子里 `sleep 15` + `terminationGracePeriodSeconds: 50`（必须 > sleep + Spring 超时）。

**为什么需要 preStop**：K8s 删 Pod 时「从 Service 摘除」和「发 SIGTERM」几乎同时发生，但 Service 摘除的同步有网络延迟——如果 Java 立刻停，而别的服务/Ingress 还没收到摘除通知，新请求就会 `Connection Refused`。preStop 的 15 秒睡眠给集群足够时间完成路由表收敛，之后才真正停进程，实现**零请求丢失**的滚动更新。

**Answer (EN):**
Configure **both sides**:

1. **App layer**: Spring Boot 2.3+ supports `server.shutdown: graceful` + `spring.lifecycle.timeout-per-shutdown-phase: 30s`. On SIGTERM it rejects new requests, drains in-flight tasks (or up to 30s), then exits.
2. **K8s layer**: `preStop` hook runs `sleep 15` + `terminationGracePeriodSeconds: 50` (must exceed sleep + Spring timeout).

**Why preStop**: when K8s deletes a Pod, "remove from Service" and "send SIGTERM" happen almost simultaneously, but the Service removal has propagation delay — if Java stops immediately while other services/Ingress haven't received the removal, new requests hit `Connection Refused`. The 15s sleep gives the cluster time to converge routing, then the process stops — a zero-request-loss rolling update.

**项目映射：** 这是我在 doc-K8S 里完整推演过的主题，还延伸到分布式事务（MQ 消费者先于 HTTP 端口关闭、`@PreDestroy` 注销）的补充思考。

---

## 四、容器与镜像

### Q16. 多阶段构建（multi-stage build）解决什么问题？你项目的镜像怎么瘦身的？

**EN:** What does a multi-stage build solve? How do you slim down your project images?

**答（中文）：**
多阶段构建把「构建环境」和「运行环境」分开：第一阶段用 `maven:3.x`（含 JDK、Maven、源码）编译出 jar，第二阶段 `COPY --from=builder` 只把 jar 拷进 `openjdk:17-slim`（只含 JRE）。最终镜像**不含 Maven、源码、编译中间产物**，体积缩 80%+。
瘦身手段：① 多阶段构建；② 用 slim/alpine 基础镜像；③ `.dockerignore` 排除 target、node_modules、.git；④ 只装运行必需依赖；⑤ 利用 layer 缓存（先 COPY pom 再 COPY src，依赖不变就不重下）。小镜像的收益：更快 push/pull、更快冷启动、更小攻击面（少装东西少漏洞）。

**Answer (EN):**
Multi-stage builds separate the build environment from the runtime: stage 1 uses `maven:3.x` (JDK + Maven + source) to compile a jar; stage 2 `COPY --from=builder` copies only the jar into `openjdk:17-slim` (JRE only). The final image **excludes Maven, source, and build artifacts**, shrinking ~80%+.
Slimming techniques: ① multi-stage; ② slim/alpine base images; ③ `.dockerignore` to exclude target, node_modules, .git; ④ install only runtime deps; ⑤ leverage layer caching (COPY pom before src so unchanged deps aren't re-downloaded). Smaller images → faster push/pull, faster cold start, smaller attack surface (fewer packages = fewer CVEs).

**项目映射：** Smart Invest 前端 Dockerfile 是 node 构建 → nginx + dist 的多阶段构建；后端用 Alpine 精简镜像；`build-amd64.sh` 处理跨架构。

---

### Q17. 如何在 CI/CD 里做镜像安全扫描（image scanning）？发现高危漏洞怎么办？

**EN:** How do you scan images for vulnerabilities in CI/CD? What do you do when a critical CVE is found?

**答（中文）：**
在流水线的「镜像构建后、推送前」加**安全门禁（gate）**：用 **Trivy / Grype / Snyk / Clair** 扫描镜像，按 `severity` 阻断（如 CRITICAL/HIGH 就 fail 掉 job）。同时：① 用 `docker scan` 或 ECR 内置扫描做持续监控；② 签名镜像（Cosign + SBOM）做供应链安全；③ 定期重建基础镜像拉取上游 patch。
发现高危漏洞的处理：① 判断**是否可达/可利用**（漏洞在没被加载的库上可降级）；② 升级基础镜像或依赖版本；③ 无法升级时用 WAF/网络策略/最小权限做补偿控制；④ 把漏洞纳入风险台账，跟踪修复期限。

**Answer (EN):**
Add a **security gate** between "build image" and "push" in the pipeline: scan with **Trivy / Grype / Snyk / Clair** and fail the job on CRITICAL/HIGH severity. Additionally: ① use `docker scan` or ECR built-in scanning for continuous monitoring; ② sign images (Cosign + SBOM) for supply-chain security; ③ rebuild base images periodically to pull upstream patches.
Handling a critical CVE: ① determine **reachability/exploitability** (a vuln in an unloaded library can be downgraded); ② upgrade the base image or dependency; ③ if can't upgrade, apply compensating controls (WAF, network policy, least privilege); ④ track it in a risk register with a remediation deadline.

**项目映射：** 对应 JD「penetration testing coordination + risk assessments」——我可以讲如何把镜像扫描纳入 CI 门禁，并与渗透测试、风险评估形成闭环。

---

## 五、云与网络 (AWS / VPC / 服务网格)

### Q18. 你的项目用了哪些 AWS 服务？为什么这样选型？

**EN:** Which AWS services does your project use, and why these choices?

**答（中文）：**

- **EC2 (t3.medium) + Elastic IP**：运行 K3S 的单节点计算（2vCPU/4GB，可突发），EIP 保证重启 IP 不变（对 CloudFront 回源和 DNS 关键）。
- **S3 + CloudFront**：前端静态资源 + 全球 CDN（450+ 节点、免费 1TB/月），SPA 自定义错误页，OAC 保证 S3 不公开。
- **WAF (Web ACL)**：附加到 CloudFront，SQL 注入/XSS/频率限制。
- **IAM（Role + Instance Profile）**：EC2 用临时凭证访问 SES/ECR/Secrets Manager，**代码里无密钥**。
- **Security Groups**：有状态防火墙，只放行 80/22/6443。
- **CloudWatch**：EC2 指标与告警；**SES**：邮件（预留）；**Secrets Manager**：密钥（预留）。

核心取舍：**成本优先**——自托管 DB/MQ（不用 RDS/AmazonMQ），单 EC2 + K3S（不用 EKS），全程最小权限 + 无硬编码密钥。

**Answer (EN):**

- **EC2 (t3.medium) + Elastic IP**: single-node compute running K3S (2vCPU/4GB, burstable); EIP keeps IP stable across restarts (critical for CloudFront origin and DNS).
- **S3 + CloudFront**: frontend static assets + global CDN (450+ PoPs, 1TB/mo free tier), SPA custom error pages, OAC keeps S3 non-public.
- **WAF (Web ACL)**: attached to CloudFront — SQL injection / XSS / rate limiting.
- **IAM (Role + Instance Profile)**: EC2 gets temporary credentials for SES/ECR/Secrets Manager — **no secrets in code**.
- **Security Groups**: stateful firewall, only 80/22/6443 open.
- **CloudWatch** for metrics/alerts; **SES** for email (reserved); **Secrets Manager** for secrets (reserved).

Core trade-off: **cost-first** — self-hosted DB/MQ (no RDS/AmazonMQ), single EC2 + K3S (no EKS), least-privilege + no hardcoded secrets throughout.

---

### Q19. VPC 里 public subnet 和 private subnet 怎么划分？数据库该放哪一侧？

**EN:** How do you split public and private subnets in a VPC, and where should the database live?

**答（中文）：**

- **Public subnet**：路由表有指向 Internet Gateway (IGW) 的路由，资源有公网 IP，直接暴露互联网——放**入口层**（ALB/NLB、NAT 不需要、堡垒机可选）。
- **Private subnet**：默认无出网、无入网公网直连，通过 **NAT Gateway** 出网（下载补丁、访问外部 API），入站只接受来自内部/ALB 的流量——放**应用层和数据库**。
- **数据库一定放 private subnet**：数据库不需要（也不应该）暴露公网，只允许应用层（同 VPC/安全组）访问；安全组再限制只有应用服务能访问 5432/3306。多层防护：网络隔离（subnet）+ 实例隔离（SG）+ 最小权限。

**Answer (EN):**

- **Public subnet**: route table has a route to an Internet Gateway (IGW); resources have public IPs and are internet-reachable — host the **entry layer** (ALB/NLB, optionally a bastion; NAT is not here).
- **Private subnet**: no direct inbound/outbound internet by default; egress goes through a **NAT Gateway** (patches, external APIs); inbound only from internal/ALB — host the **app tier and database**.
- **Database must be in a private subnet**: it should never be internet-exposed; only the app tier (same VPC/SG) can reach it, and a security group further restricts access to 5432/3306. Defense in depth: subnet isolation + instance isolation (SG) + least privilege.

---

### Q20. 什么是服务网格（Service Mesh）？Istio 的 VirtualService 和 DestinationRule 分别干什么？

**EN:** What is a service mesh? What do Istio's VirtualService and DestinationRule each do?

**答（中文）：**
服务网格把微服务的**治理能力从应用代码下沉到基础设施层**：每个 Pod 旁注入一个 **Envoy sidecar** 代理，统一接管服务间流量的**负载均衡、熔断、重试、超时、限流、mTLS、可观测性**——应用代码回归纯业务。

- **VirtualService（怎么路由）**：等价于 Spring Cloud Gateway 的路由规则。按 Path/Header/权重把请求分流，能做超时 `timeout`、重试 `retries`、金丝雀 `weight`、流量镜像 `mirror`、故障注入 `fault`。
- **DestinationRule（到达后怎么做）**：等价于 Resilience4j 熔断 + Ribbon 负载均衡。定义负载均衡策略（`LEAST_REQUEST`）、连接池、**outlierDetection 熔断**（`consecutive5xxErrors`、`baseEjectionTime` 对应 Hystrix 的 requestVolumeThreshold / sleepWindow）、`subsets` 版本分组。

一句话：VirtualService 管「流量去哪」，DestinationRule 管「流量到达后怎么对待目标」。

**Answer (EN):**
A service mesh pushes microservice **governance out of application code down to the infrastructure layer**: an **Envoy sidecar** is injected next to each Pod and uniformly handles load balancing, circuit breaking, retries, timeouts, rate limiting, mTLS, and observability — app code returns to pure business logic.

- **VirtualService (how to route)**: equivalent to Spring Cloud Gateway routing. Splits traffic by Path/Header/weight; supports `timeout`, `retries`, canary `weight`, `mirror`, and `fault` injection.
- **DestinationRule (what to do on arrival)**: equivalent to Resilience4j circuit breaker + Ribbon load balancing. Defines LB policy (`LEAST_REQUEST`), connection pool, **outlierDetection** circuit breaking (`consecutive5xxErrors`, `baseEjectionTime` map to Hystrix's requestVolumeThreshold / sleepWindow), and `subsets` version groups.

One line: VirtualService controls "where traffic goes", DestinationRule controls "how to treat the target on arrival".

**项目映射：** 我完整评估过 Istio，但权衡后（2核4G、单版本、无金丝雀刚需）选了 Traefik + Spring Cloud Gateway 更轻方案——这是我「全局权衡」能力的直接体现。

---

### Q21. 你为什么给 API 网关用 JWT 而不是 Session？RS256 和 HS256 有什么区别？

**EN:** Why JWT over sessions for your API gateway, and what's RS256 vs HS256?

**答（中文）：**

- **JWT 无状态**：网关/每个服务都能**独立校验**签名（不需要回源查 session 存储），天然适合微服务的横向扩展和负载均衡；Session 需要中心化存储（Redis）且有状态、跨服务共享复杂。
- **RS256（非对称）**：用**私钥签名、公钥验签**。只有认证服务持有私钥（能签发），其他所有服务/网关只拿公钥验签——**验签方无法伪造 token**，权限边界清晰，最适合微服务。JWT RS256 正是我的项目选择。
- **HS256（对称）**：同一个密钥既签名又验签，任何持有密钥的服务都能伪造 token，密钥分发风险高，适合单体内部。

**Answer (EN):**

- **JWT is stateless**: the gateway and every service can **independently verify** the signature (no session-store round-trip), which suits horizontal scaling and load balancing of microservices. Sessions need central storage (Redis), are stateful, and are complex to share across services.
- **RS256 (asymmetric)**: **private key signs, public key verifies**. Only the auth service holds the private key (can issue); every other service/gateway only has the public key — **verifiers can't forge tokens**, giving clean permission boundaries. This is what my project uses.
- **HS256 (symmetric)**: one key both signs and verifies; any service holding it can forge tokens — higher key-distribution risk, fine for monoliths.

---

## 六、DevSecOps 安全

### Q22. 你理解的 DevSecOps 是什么？「左移（shift-left）」安全具体怎么做？

**EN:** What does DevSecOps mean to you? How do you concretely "shift left" on security?

**答（中文）：**
DevSecOps 是把安全从「上线前的最后一关」变成**贯穿全生命周期的内生能力**，让安全成为开发/运维每个人的责任，而不是安全团队的孤岛。
左移的落地：

- **编码阶段**：SAST（静态扫描，如 SonarQube/Semgrep）在 PR 里跑，依赖漏洞扫描（SCA）。
- **构建阶段**：镜像扫描（Trivy/Grype）+ 签名 + SBOM，作为 CI 门禁。
- **IaC 安全**：Terraform `plan` + 合规扫描（Checkov/tfsec）在部署前拦下错误配置。
- **部署阶段**：K8s 安全（Pod Security Standards、NetworkPolicy、RBAC 最小权限、Secret 管理）。
- **运行阶段**：WAF、DAST、漏洞管理、实时告警（Prisma Cloud / 云原生安全平台）。
  原则：**安全左移 = 在问题成本最低的环节发现它**，用自动化门禁而非人工审查。

**Answer (EN):**
DevSecOps makes security an **endogenous capability across the whole lifecycle** instead of a final gate before release — everyone's responsibility, not a siloed security team.
Concrete shift-left:

- **Coding**: SAST (SonarQube/Semgrep) in PRs, dependency vuln scanning (SCA).
- **Build**: image scanning (Trivy/Grype) + signing + SBOM as a CI gate.
- **IaC security**: Terraform `plan` + compliance scanning (Checkov/tfsec) blocks misconfigs before deploy.
- **Deploy**: K8s security (Pod Security Standards, NetworkPolicy, least-privilege RBAC, Secret management).
- **Run**: WAF, DAST, vuln management, real-time alerts (Prisma Cloud / CNAPP).
  Principle: **shift-left = find issues where the fix is cheapest**, using automated gates rather than manual review.

**项目映射：** 项目里的 WAF（SQL 注入/XSS/频率限制）、IAM 最小权限、JWT RS256、Secrets Manager 都是 DevSecOps 的落地；JD 特别点了 Prisma（Prisma Cloud），可以接 CNAPP 概念。

---

### Q23. IAM 最佳实践里，为什么用 Instance Profile / Role 而不是 Access Key？

**EN:** Why use Instance Profile / Role instead of Access Keys in IAM best practices?

**答（中文）：**

- **Access Key 是长期凭证**：静态、不会过期（除非手动轮换）、常被硬编码进代码/配置/镜像 → 一旦泄露就是长期有效的后门，且**无审计上下文**。
- **Role + Instance Profile 是临时凭证**：EC2/容器通过 Instance Profile 自动获取 STS 签发的**短期凭证**（几分钟到几小时自动过期、自动轮换），代码里**零密钥**。好处：① 泄露影响面小（短时）；② 自动轮换无需人工；③ 权限可集中管理（改 Role 即改所有实例）；④ 可追溯（CloudTrail 记录角色是谁、做了什么）。
- 现代更进一步：**OIDC** 让 CI 用短时凭证，彻底告别长期密钥。

**Answer (EN):**

- **Access Keys are long-lived credentials**: static, don't expire (unless manually rotated), often hardcoded into code/config/images → a leak is a long-lived backdoor with **no audit context**.
- **Role + Instance Profile are temporary credentials**: EC2/containers get short-lived STS-issued credentials automatically (auto-expiring, auto-rotating), so there are **zero secrets in code**. Benefits: ① smaller blast radius on leak (short-lived); ② auto-rotation, no manual work; ③ centralized permission management (change the Role, affects all instances); ④ auditable via CloudTrail.
- Modern extension: **OIDC** lets CI use short-lived credentials — eliminate long-lived keys entirely.

**项目映射：** Smart Invest 明确选了 IAM Role（EC2 通过 Instance Profile 拿 SES/ECR/Secrets Manager 的临时凭证），这是我在 JD「security」要求下的真实决策。

---

### Q24. WAF 能防哪些攻击？它和 Network Firewall / Security Group 有什么区别？

**EN:** What attacks does a WAF block, and how does it differ from a Network Firewall / Security Group?

**答（中文）：**

- **WAF（应用层 L7）**：理解 HTTP 语义，防 **SQL 注入、XSS、CSRF、路径穿越、频率限制（DDoS 缓解）**、恶意 bot，用托管规则（如 AWS Managed Rules）+ 自定义规则。它看的是「请求内容」。
- **Security Group（实例层，有状态）**：控制「哪个 IP/端口能不能进这个实例」，只看到 TCP/IP 层（源 IP、端口、协议），不理解 HTTP。
- **Network Firewall / NACL（网络层）**：子网级的无状态/有状态过滤，按 IP/端口/协议规则，做南北向网络隔离。
- 分层关系：**NACL → SG → WAF** 是纵深防御的三层，各管各的 OSI 层。WAF 挡应用攻击，SG/NACL 挡网络攻击。

**Answer (EN):**

- **WAF (L7)**: understands HTTP semantics; blocks **SQL injection, XSS, CSRF, path traversal, rate limiting (DDoS mitigation)**, malicious bots, via managed rules (e.g. AWS Managed Rules) + custom rules. It inspects **request content**.
- **Security Group (instance-level, stateful)**: controls "which IP/port may reach this instance" — only sees TCP/IP (source IP, port, protocol), not HTTP.
- **Network Firewall / NACL (network layer)**: subnet-level stateless/stateful filtering by IP/port/protocol for north-south isolation.
- Layering: **NACL → SG → WAF** is three layers of defense in depth, each at its own OSI layer. WAF blocks app attacks; SG/NACL block network attacks.

**项目映射：** 我的 WAF Web ACL 附加到 CloudFront，做 SQL 注入/XSS/频率限制；Security Group 只放行 80/22/6443。

---

### Q25. 你会怎么协调一次渗透测试（penetration testing）？测试前后的流程是什么？

**EN:** How would you coordinate a penetration test? What's the before/after process?

**答（中文）：**

- **前期（scope + 授权）**：明确测试范围（哪些系统/域名/IP、哪些排除）、测试类型（黑/灰/白盒）、时间窗口、**书面授权**（避免误伤），确认生产环境的监控/告警阈值，避免把正常防护当「攻击」误告警。
- **执行**：与第三方/内部红队协作，提供测试环境或生产低峰窗口，全程监控，区分「测试流量」和「真实攻击」。
- **后期（闭环）**：收到报告 → 按 CVSS/业务影响**定级** → 用漏洞管理流程（Jira）跟踪 → **复测验证修复** → 把根因反哺到 DevSecOps（SAST 规则、WAF 规则、配置基线），做到「修一个、防一类」。

**Answer (EN):**

- **Before (scope + authorization)**: define scope (which systems/domains/IPs, exclusions), test type (black/grey/white box), time window, **written authorization** (avoid collateral damage), confirm monitoring/alert thresholds so normal defenses aren't mistaken for "attacks".
- **During**: work with the third-party/internal red team, provide a test env or low-traffic window, monitor throughout, distinguish test traffic from real attacks.
- **After (closed loop)**: receive report → **prioritize** by CVSS/business impact → track via a vuln-management process (Jira) → **retest to verify fixes** → feed root causes back into DevSecOps (SAST rules, WAF rules, config baselines) — "fix one, prevent a class".

**项目映射：** 这是 JD 明确的「penetration testing coordination + risk assessments」，配合我在 Q17 的镜像扫描、Q22 的左移，形成完整安全闭环。

---

## 七、监控、可观测性与告警

### Q26. 监控（Monitoring）和可观测性（Observability）有什么区别？三大支柱是什么？

**EN:** What's the difference between monitoring and observability? What are the three pillars?

**答（中文）：**

- **监控**：针对**已知问题**，预先定义指标和阈值，出了问题告警（「我预期 CPU 会高，设 80% 告警」）。
- **可观测性**：针对**未知问题**，让你能**主动探查**系统内部状态、回答任意问题（「为什么这个请求慢了」），即使事前没定义过指标。
- 三大支柱：**Metrics（指标）**——聚合数值趋势（Prometheus）；**Logs（日志）**——离散事件（ELK/Loki）；**Traces（链路追踪）**——一次请求跨服务的调用链（Jaeger/SkyWalking/APM）。三者用 trace_id 关联，才能从「慢」定位到「哪个服务的哪次调用」。

**Answer (EN):**

- **Monitoring**: for **known problems** — predefined metrics and thresholds that alert when breached ("I expect CPU to spike, so alert at 80%").
- **Observability**: for **unknown problems** — lets you **actively interrogate** internal state and answer arbitrary questions ("why is this request slow?") even if no metric was predefined.
- Three pillars: **Metrics** — aggregated numeric trends (Prometheus); **Logs** — discrete events (ELK/Loki); **Traces** — a request's call chain across services (Jaeger/SkyWalking/APM). Correlate them via trace_id to go from "slow" to "which service's which call".

**项目映射：** Smart Invest 有 `deploy-monitoring.sh`（Prometheus + Grafana）+ CloudWatch 指标/告警；我研究过 SkyWalking 做分布式链路追踪（对应 JD 的 APM 要求）。

---

### Q27. 生产环境一个 API 突然 P99 延迟飙高，你会怎么排查？

**EN:** A production API's P99 latency suddenly spikes. How do you troubleshoot?

**答（中文）：**
用**系统化排查法**，先定位「慢在哪一层」，再下钻：

1. **看监控面板**：先看是「个别服务慢」还是「全局慢」——网关/服务/DB 的 CPU、内存、错误率、GC 是否同步异常。
2. **链路追踪**：找一个慢请求的 trace_id，看它在哪个 span 耗时最多——是服务内部（业务逻辑/GC）还是下游调用（DB/MQ/第三方）。
3. **分层假设验证**：
   - 依赖层：DB 慢查询（慢日志、连接池耗尽）、网络抖动、下游服务超时。
   - 应用层：GC 频繁（full GC）、线程池打满、缓存失效（缓存击穿/雪崩）。
   - 基础设施层：节点资源争抢、磁盘 IO、网络。
4. **对比时间线**：是不是刚发布了新版本（灰度放量）？→ 回滚或缩小灰度。
5. **下钻工具**：`jstack` 线程 dump、堆 dump、PromQL 查指标、`kubectl top`/`describe` 查资源。

原则：**先用可观测性数据缩小范围，再针对性下钻**，不盲目重启（重启会丢现场）。

**Answer (EN):**
Use a **systematic approach** — first localize "which layer is slow", then drill down:

1. **Look at dashboards**: is it one service or global? Check gateway/service/DB CPU, memory, error rate, GC for correlated anomalies.
2. **Tracing**: take a slow request's trace_id and find which span dominates — internal (business logic/GC) or a downstream call (DB/MQ/third-party).
3. **Layer-by-layer hypothesis**:
   - Dependency: DB slow queries (slow log, connection pool exhaustion), network jitter, downstream timeout.
   - App: GC thrash (full GC), thread pool saturation, cache failure (breakdown/avalanche).
   - Infra: node resource contention, disk IO, network.
4. **Correlate the timeline**: was a new version just deployed (canary ramp)? → roll back or shrink the canary.
5. **Drill-down tools**: `jstack` thread dump, heap dump, PromQL, `kubectl top`/`describe` for resources.

Principle: **narrow with observability data first, then drill down** — don't blindly restart (restart loses the scene).

---

### Q28. 你怎么设计告警（alerting）？怎样避免告警疲劳（alert fatigue）？

**EN:** How do you design alerting? How do you avoid alert fatigue?

**答（中文）：**

- **分层告警**：P0/P1（立即 page，影响用户/收入）→ P2（工单，1 小时内）→ P3（低优先级，工作日处理）。只有真影响用户的才 page。
- **基于 SLO 而非单点阈值**：用错误率、延迟的 **SLO + burn rate（燃烧率）** 告警，比「CPU>80%」这类瞬时阈值更少误报、更能反映用户体验。
- **指标要可行动（actionable）**：每条告警必须附带「这表示什么 + 怎么办」的 runbook；纯噪音指标不告警或降级为趋势图。
- **去重 + 聚合 + 抑制**：同一根因的告警聚合为一条，基础设施告警抑制上层应用告警。
- **持续复盘**：定期 review 告警，删掉从不被响应的告警，把「告警→响应→复盘」形成闭环。

**Answer (EN):**

- **Tiered alerts**: P0/P1 (page immediately, impacts users/revenue) → P2 (ticket, within 1h) → P3 (low, business hours). Only truly user-impacting issues page.
- **SLO-based, not single-point thresholds**: alert on error-rate/latency **SLO + burn rate**, which produces fewer false positives and better reflects UX than instantaneous "CPU > 80%".
- **Actionable alerts**: every alert ships with a runbook ("what this means + what to do"); pure-noise metrics don't alert or become trend charts.
- **Dedup + aggregate + inhibit**: group same-root-cause alerts into one; infrastructure alerts inhibit upstream app alerts.
- **Continuous review**: periodically prune never-responded-to alerts; close the loop "alert → response → retrospective".

---

## 八、可靠性与故障排查 (SRE / RCA)

### Q29. 你的服务是 2 副本，一个 Pod 挂了，用户会感知到吗？怎么做到高可用？

**EN:** Your service runs 2 replicas. If one Pod dies, do users notice? How do you achieve HA?

**答（中文）：**
不会（只要配置正确）：2 副本 + Service 负载均衡 + readiness/liveness 探针，一个 Pod 挂掉后，K8s 自动把它从 endpoints 摘除，流量只打到健康的副本；同时 ReplicaSet 会拉起新 Pod 补回 2 副本。前提：① 服务**无状态**（不依赖本地存储）；② 反亲和（anti-affinity）让两个副本不落到同一节点，否则节点宕机两个副本一起没；③ 探针配置正确能快速摘除故障 Pod。
真正的 HA 还要考虑：多副本 + 跨可用区/节点 + 优雅停机（不丢请求）+ 有状态组件（DB）的主从/备份。

**Answer (EN):**
No (if configured correctly): with 2 replicas + Service load balancing + readiness/liveness probes, when one Pod dies K8s removes it from endpoints and traffic goes only to the healthy replica; the ReplicaSet spins up a replacement to restore 2 replicas. Preconditions: ① the service is **stateless** (no local storage); ② anti-affinity spreads replicas across nodes, otherwise a node failure takes both down; ③ correct probes to remove the failed Pod fast.
Real HA also needs: multi-replica + cross-AZ/node + graceful shutdown (no request loss) + primary/replica & backup for stateful components (DB).

**项目映射：** Smart Invest 所有微服务都是 2 副本（JD 相关，近期 commit 正是「Increase replica count to 2」），中间件用 PVC 持久化。

---

### Q30. Pod 被 `OOMKilled`（Exit Code 137）了，和 Java 报 `OutOfMemoryError` 有什么区别？怎么预防？

**EN:** A Pod is `OOMKilled` (exit 137) vs Java throwing `OutOfMemoryError`. What's the difference and how do you prevent it?

**答（中文）：**
这是**两种完全不同的 OOM**：

- **`OOMKilled` (137)**：**容器总内存（RSS）超过了 K8s 的 `limits.memory`**，宿主机内核 OOM Killer 直接把进程杀掉，Java **连异常都来不及打印**。根因：JVM 内存 ≠ 容器内存，除了堆还有 Metaspace、线程栈、Direct Memory、容器里其他进程。`limits=4Gi` + `-Xmx4g` 时，堆用 3.5G + 非堆 600M = 4.1G 就触线被杀。
- **`OutOfMemoryError: Java heap space`**：**堆内存耗尽**，但总内存没超 limits，所以 Pod 活着，应用内部抛异常。

预防（现代容器自适应范式）：

- 用 **`-XX:MaxRAMPercentage=75.0`**（而非写死 `-Xmx`），让 JVM 感知容器 limits 自动算堆大小，留 25% 给非堆/系统缓冲。
- **`requests == limits`**：避免超卖被宿主机在资源紧张时「优先杀掉实际占用超 requests 的 Pod」。
- 显式限制 **`-XX:MaxDirectMemorySize`**（Netty 直接内存）。
- 配 `-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/app/logs/...`（挂 PVC）便于事后分析。

**Answer (EN):**
These are **two entirely different OOMs**:

- **`OOMKilled` (137)**: the **container's total memory (RSS) exceeded `limits.memory`**, so the host kernel's OOM Killer kills the process — Java **doesn't even get to print the exception**. Root cause: JVM memory ≠ container memory; beyond the heap there's Metaspace, thread stacks, Direct Memory, and other processes in the container. With `limits=4Gi` + `-Xmx4g`, heap at 3.5G + 600M non-heap = 4.1G crosses the line → killed.
- **`OutOfMemoryError: Java heap space`**: the **heap is exhausted**, but total memory is under limits, so the Pod lives and the app throws internally.

Prevention (modern container-aware pattern):

- Use **`-XX:MaxRAMPercentage=75.0`** (not a hardcoded `-Xmx`) so the JVM senses container limits and sizes the heap automatically, leaving 25% for non-heap/system buffer.
- **`requests == limits`**: avoid oversubscription where the host preferentially kills Pods whose actual usage exceeds requests under pressure.
- Explicitly cap **`-XX:MaxDirectMemorySize`** (Netty direct memory).
- Add `-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=...` (mounted PVC) for post-mortem analysis.

---

### Q31. 讲一次你做过的根因分析（RCA）。你的方法论是什么？

**EN:** Walk me through a root cause analysis you've done. What's your methodology?

**答（中文）：**
方法论（组合拳）：**5 Whys + 鱼骨图（因果图）+ 时间线复盘**。
流程：

1. **保护现场 + 止损**：先恢复服务（回滚/切流/重启），保留日志、dump、监控快照。
2. **时间线**：从监控/日志重建「异常从哪一刻开始」，关联变更（部署、配置、流量）。
3. **5 Whys 深挖根因**：从表象（「API 超时」）→ 直接原因（「DB 连接池打满」）→ 根本原因（「新版本泄漏连接」或「无连接池上限」）逐层问为什么。
4. **鱼骨图枚举维度**：人、流程、代码、依赖、基础设施、网络，避免漏维度。
5. **输出 blameless 复盘报告**：只找系统/流程缺陷，不追责个人；给出**防再发的行动项**（加监控、加限流、改代码、加测试），并跟踪到闭环。

关键心态：**blameless + 系统归因**——问题出在流程和系统，不甩锅给人，否则下次没人敢上报。

**Answer (EN):**
Methodology (combined): **5 Whys + fishbone (Ishikawa) + timeline reconstruction**.
Process:

1. **Preserve the scene + mitigate**: restore service first (rollback/cutover/restart), keep logs, dumps, monitoring snapshots.
2. **Timeline**: reconstruct "when did the anomaly start" from monitoring/logs, correlate changes (deploy, config, traffic).
3. **5 Whys**: from symptom ("API timeout") → direct cause ("DB connection pool exhausted") → root cause ("new version leaks connections" or "no pool cap") — ask why layer by layer.
4. **Fishbone over dimensions**: people, process, code, dependencies, infra, network — avoid missing a dimension.
5. **Blameless postmortem**: find only system/process flaws, never blame individuals; produce **preventive action items** (add monitoring, rate limiting, code fix, tests) and track to closure.

Key mindset: **blameless + system attribution** — problems are in process and system, never finger-pointing, or nobody will report next time.

---

## 九、脚本与自动化 (Python / Bash / Go / Ansible)

### Q32. 你会用什么语言写运维脚本？什么场景用 Python、什么场景用 Bash？

**EN:** What language do you use for ops scripts? When Python vs Bash?

**答（中文）：**

- **Bash**：适合**短小的胶水脚本**——管道、文件操作、调用 CLI、编排命令（如我的 `deploy.sh`、`build-images.sh`）。几十行内、纯命令编排，Bash 最快。
- **Python**：适合**有逻辑、要处理数据、跨平台、要调 API**的场景——解析 JSON、调 AWS SDK（boto3）、写复杂的部署/迁移/自动化工具、做告警聚合。可读性、可测试性、生态（boto3/requests）远超 Bash。
- **Go**：适合**高性能、要打包成单一二进制、作为常驻服务或 CLI 工具**分发给团队/CI 的场景（如写一个 k8s operator、一个自定义 CLI）。
- 原则：**逻辑超过 100 行、要处理数据、要复用 → Python/Go；纯命令串联 → Bash**。

**Answer (EN):**

- **Bash**: for **short glue scripts** — pipes, file ops, calling CLIs, orchestrating commands (like my `deploy.sh`, `build-images.sh`). Under ~100 lines of pure command orchestration, Bash is fastest.
- **Python**: for **logic, data processing, cross-platform, API calls** — parse JSON, call the AWS SDK (boto3), write complex deploy/migration/automation tools, aggregate alerts. Readability, testability, and ecosystem (boto3/requests) far exceed Bash.
- **Go**: for **high performance, single-binary distribution, long-running services or CLI tools** shared with teams/CI (e.g. a k8s operator or custom CLI).
- Principle: **>100 lines, data processing, or reuse → Python/Go; pure command chaining → Bash**.

**项目映射：** JD 要求 Python/Bash/Go/Ansible；我的 `scripts/` 目录有完整 Bash 编排（deploy、build、monitoring、cloudwatch），说明我能根据场景选语言。

---

### Q33. Ansible 和 Terraform 都是自动化，它们有什么区别？什么场景用哪个？

**EN:** Both Ansible and Terraform are automation — what's the difference, and when do you use each?

**答（中文）：**

- **Terraform（声明式 IaC，编排）**：描述**期望状态**，管理云基础设施的**生命周期**（创建/更新/删除），自动计算依赖和 diff。它**不做应用内的配置管理**（如装软件、改配置文件、起服务）。state 让它能对账和幂等。
- **Ansible（过程式，配置管理）**：描述**执行步骤**（playbook），擅长在服务器上**安装软件、推送配置文件、执行命令、部署应用**，agentless（SSH）。适合对 Terraform 建好的机器做「开机后的配置」。
- 最佳实践是**两者配合**：Terraform 建资源（VM/网络/安全组）→ Ansible 配机器（装 Docker、调内核、部署服务）。也可以 Terraform + cloud-init / user-data 替代部分 Ansible。

**Answer (EN):**

- **Terraform (declarative IaC, orchestration)**: describes **desired state** and manages the cloud-infrastructure **lifecycle** (create/update/destroy), auto-computing dependencies and diffs. It does **not** do in-app config management (installing software, editing configs, starting services). State gives it reconciliation and idempotency.
- **Ansible (procedural, config management)**: describes **execution steps** (playbooks), good at installing software, pushing config files, running commands, and deploying apps on servers, agentless over SSH. Suited for "post-provisioning configuration" of machines Terraform created.
- Best practice is **combining them**: Terraform provisions resources (VM/network/SG) → Ansible configures machines (install Docker, tune kernel, deploy services). Terraform + cloud-init/user-data can also replace part of Ansible.

**项目映射：** Smart Invest 的 EC2 用 Terraform + user-data（cloud-init）装机，K3S 用 `deploy-k3s.sh` 安装；我能清楚说明何时引入 Ansible 更合适。

---

## 十、行为与软技能

### Q34. 作为 DevSecOps，你怎么在「开发团队」和「运维团队」之间做桥梁？

**EN:** As a DevSecOps engineer, how do you bridge the dev and ops teams?

**答（中文）：**
核心是**消除「开发和运维目标不一致」的对立**：

- **统一目标**：把部署速度、稳定性、安全变成**共同 KPI**，而不是开发追「上线快」、运维追「别出事」互相拉扯。
- **自服务平台**：给开发做**自助交付环境**（一键部署、模板化流水线、自助日志/监控查询），让开发不依赖运维就能发布，运维把精力放在平台能力而非「代操作」。
- **可观测性共享**：开发能看自己服务的指标/日志/trace，出问题自己先定位，而不是丢给运维。
- **左移运维**：把部署、监控、SLO 的配置放进代码仓库（GitOps），开发在 PR 里就能看到影响。
- **软实力**：共情（理解对方痛点）、用数据说话、主动复盘（blameless）、知识分享（mentoring）。

**Answer (EN):**
The core is **removing the goal misalignment between dev and ops**:

- **Align goals**: make deployment velocity, stability, and security **shared KPIs** — not dev chasing "ship fast" vs ops chasing "don't break things".
- **Self-service platform**: give devs a **self-service delivery environment** (one-click deploy, templated pipelines, self-serve log/metrics), so devs ship without depending on ops, and ops focus on platform capability rather than "doing it for them".
- **Shared observability**: devs see their own service's metrics/logs/traces and triage first instead of throwing it over the wall.
- **Shift ops left**: put deploy/monitoring/SLO config in code repos (GitOps), so devs see the impact in a PR.
- **Soft skills**: empathy, data-driven communication, blameless retros, knowledge sharing (mentoring).

**项目映射：** 这正是 JD 的「Act as a bridge between operations and development teams」「self-service application delivery environment」——我可以讲 Smart Invest 如何用 Helm umbrella chart + 脚本做成「一条命令交付」，让开发自助部署。

---

### Q35. 你如何保持技术学习和成长？最近在学什么？

**EN:** How do you keep learning and growing? What have you been studying lately?

**答（中文）：**
我坚持**「做中学 + 系统性笔记 + 输出」**：不只是用工具，而是把一个技术点从「会用」挖到「懂原理、能权衡」。

- **做中学**：用自己的 Smart Invest 项目把 AWS、K3S、Terraform、Helm、Spring Cloud 全链路跑通，遇到问题（跨架构镜像、镜像拉取受限、成本优化）逐个攻克。
- **系统性笔记**：整理 K8s 核心概念、优雅停机/OOM、CI/CD 滚动发布、服务网格等专题笔记，用「心智模型 + 对照法」（如把 Istio 对应到 Hystrix/Ribbon）加速理解。
- **持续输出**：写架构文档（架构设计、部署指南、Istio 指南），倒逼自己讲清楚。
- **关注趋势**：服务网格（Istio）、可观测性（SkyWalking/Prometheus）、GitOps（ArgoCD）、AI 辅助运维。

**Answer (EN):**
I stick to **"learn by doing + systematic notes + output"**: not just using a tool, but digging from "can use it" to "understand the principle and can weigh trade-offs".

- **Learn by doing**: my Smart Invest project runs the full AWS + K3S + Terraform + Helm + Spring Cloud stack end-to-end; I solved real problems (cross-arch images, image-pull restrictions, cost optimization).
- **Systematic notes**: wrote topic notes on K8s core concepts, graceful shutdown/OOM, CI/CD rolling release, and service mesh, using mental models + cross-referencing (mapping Istio to Hystrix/Ribbon).
- **Continuous output**: architecture docs, deployment guides, Istio guides — forcing myself to explain clearly.
- **Trends**: service mesh (Istio), observability (SkyWalking/Prometheus), GitOps (ArgoCD), AI-assisted ops.

**项目映射：** 我的项目仓库里就是这套学习方法的证据（doc-K8S、doc-design、doc-manually 等笔记目录）。

---

### Q36. 一个开发同事坚持「上 Istio 服务网格」，你评估后觉得当前规模不值得，怎么和他沟通？

**EN:** A colleague insists on adopting Istio, but you've evaluated that it's not worth it at your current scale. How do you communicate this?

**答（中文）：**
用**数据 + 共情 + 建设性替代方案**沟通，而不是「否决」：

1. **认可动机**：先肯定他引入 Istio 的诉求（金丝雀、流量管理、可观测性、mTLS）是真实且合理的。
2. **摆数据**：用事实说明成本——当前集群 2vCPU/4GB 已用 70%，Istio sidecar 每个 Pod 额外占资源，叠加后必然 OOM；且当前是单版本部署，没有金丝雀/流量镜像的刚需。
3. **给路径**：不是「永远不用」，而是「分阶段」——先把现有 Traefik + Spring Cloud Gateway 覆盖的核心能力用满，等流量/版本复杂度上来再引入；可以先在本地 `kind`/`minikube` 用 minimal profile 做 PoC，沉淀经验。
4. **求共识**：把决策写成 ADR（架构决策记录），记录「为什么现在不选 + 什么时候重新评估」，让他的诉求被看见、被记录，而不是被驳回。

**Answer (EN):**
Communicate with **data + empathy + a constructive alternative**, not a flat "no":

1. **Acknowledge the motive**: affirm that his goals for Istio (canary, traffic management, observability, mTLS) are real and valid.
2. **Bring data**: show the cost in facts — the current cluster (2vCPU/4GB) is already at 70%, each Istio sidecar adds overhead that would OOM; and it's a single-version deployment with no canary/mirroring need yet.
3. **Give a path**: not "never", but "staged" — first fully exploit Traefik + Spring Cloud Gateway's core capabilities, adopt Istio when traffic/version complexity demands it; PoC locally on `kind`/`minikube` with the minimal profile to build experience.
4. **Seek consensus**: record the decision as an ADR (Architecture Decision Record) — "why not now + when to re-evaluate" — so his proposal is seen and recorded, not rejected.

**项目映射：** 这正是我在 Istio 指南里做的完整评估，最能体现 JD 要的「think holistically」「empathetic, humble, collaborative mindset」。

---

## 面试官可能追问的加分点 / Bonus follow-ups

- 你项目里 CloudFront 回源到 EC2 是怎么保证安全的？（OAC + 自定义 header 回源校验）
- `helm upgrade --atomic` 的作用？（失败自动回滚到上一个 release）
- StatefulSet 扩容顺序和 PVC 的关系？（有序创建，PVC 独立于 Pod 生命周期）
- RabbitMQ/Redis 为什么用 Deployment + 单 PVC 而非 StatefulSet？什么情况要换？（单实例成本取舍够用；要集群 HA 就换 StatefulSet + Headless Service + volumeClaimTemplates，因为集群需稳定 hostname 互相发现 + 每节点独享 PVC）
- 你的 K8s Secret 是怎么管理的？为什么不用明文 ConfigMap？（Secret 用 base64 + etcd 加密 + 最小权限，密码不进 ConfigMap）
- Terraform 的 `terraform.tfvars` 要不要提交到 Git？（含敏感信息的不提交，用变量注入或 secrets manager）
- 你项目里「成本优先」这个决策，如果老板要求上 EKS/RDS，你怎么权衡？（用总拥有成本 + SLA 需求 + 团队运维能力做决策，而非只盯单价）
- 多环境（dev/staging/prod）的 Terraform/Helm 你怎么复用？（modules 复用 + values 分层 + workspace/目录隔离）
- 你会怎么给团队做知识分享（mentoring）？（定期 lunch-and-learn、写 ADR、结对、runbook）

---

## 核心答题心法 / Core Answering Principles

1. **项目先行**：每个技术点先讲「我在 Smart Invest 里怎么做的 + 为什么这么选」，再扩展到通用最佳实践。
2. **讲权衡（trade-off）**：Senior 岗不只要「会」，更要「知道什么时候不用」——成本 vs 规模、K3S vs EKS、Istio vs Traefik 都是你的加分点。
3. **双语自如**：JD 要求粤语 + 英语，面试可能英文进行；把下面的高频关键词中英都记牢。
4. **全局思维（holistic）**：任何问题都往「对系统、对团队、对成本、对安全」的整体影响上靠。

## 高频关键词速记 / Key Terms Quick Reference

| 中文              | English                                  |
| --------------- | ---------------------------------------- |
| 基础设施即代码         | Infrastructure as Code (IaC)             |
| 持续集成/持续部署       | CI/CD                                    |
| 滚动更新 / 金丝雀 / 蓝绿 | Rolling update / Canary / Blue-green     |
| 优雅停机            | Graceful shutdown                        |
| 就绪探针 / 存活探针     | readinessProbe / livenessProbe           |
| 服务网格 / 边车代理     | Service mesh / Sidecar proxy             |
| 熔断 / 限流 / 重试    | Circuit breaking / Rate limiting / Retry |
| 无状态 / 有状态       | Stateless / Stateful                     |
| 持久卷 / 持久卷声明     | PV / PVC                                 |
| 可观测性（指标/日志/链路）  | Observability (Metrics/Logs/Traces)      |
| 根因分析            | Root Cause Analysis (RCA)                |
| 左移安全            | Shift-left security                      |
| 最小权限            | Least privilege                          |
| 单点故障 / 高可用      | SPOF / High Availability                 |
| 服务级别目标          | Service Level Objective (SLO)            |
| 架构决策记录          | Architecture Decision Record (ADR)       |
| 渗透测试 / 风险评估     | Penetration testing / Risk assessment    |
| 告警疲劳            | Alert fatigue                            |
