# Smart-Invest AWS Architecture — Interview Q&A
# 架构面试题（英文 + 中文）

> 面向英文面试，英语词汇控制在高中水平。  
> 数据中心：**新加坡（ap-southeast-1）主站** + **香港（ap-east-1）灾备**。

---

## Part 1 — High Availability & Disaster Recovery
## 第一部分：高可用 / 两岸三中心

---

### Q1. Can you explain what "two regions, three centers" means in your system?
### 问题1：请解释你们系统的"两岸三中心"设计是什么？

**English Answer:**

"Two regions, three centers" means we put our system in two different places and have three data centers in total.

In our system:
- **Region 1 — Singapore** (main site, "生产中心 + 同城灾备"):  
  We run our EKS cluster and Aurora database across **3 Availability Zones (AZ-a, AZ-b, AZ-c)** inside Singapore. AZ-a is the main production center. AZ-b and AZ-c are the local backup centers. If one AZ goes down, traffic automatically moves to another AZ in the same city. This is called **active-active within the same region**.

- **Region 2 — Hong Kong** (remote DR site, "异地灾备中心"):  
  We use **Aurora Global Database** to copy all data from Singapore to Hong Kong in real time. The delay is less than 1 second. If the whole Singapore region fails, we can switch to Hong Kong in under 15 minutes.

So the three centers are:
1. **Production Center** — Singapore, primary AZ  
2. **Local DR Center** — Singapore, secondary AZs (same city, different buildings)  
3. **Remote DR Center** — Hong Kong (different city, different country)

**中文解释：**

"两岸三中心"是金融行业的高可用标准：
- **两岸** = 两个地区：新加坡（主站） + 香港（异地灾备）
- **三中心** = 三个数据中心：
  1. 生产中心：新加坡，EKS主集群 + Aurora Writer
  2. 同城灾备：新加坡另一个可用区，Aurora Reader副本
  3. 异地灾备：香港，Aurora Global Database 只读副本（延迟 < 1秒）

当新加坡整个Region故障时，香港可以在15分钟内接管所有流量（手动升级Aurora副本为主库）。

---

### Q2. What is RTO and RPO? What are your targets?
### 问题2：什么是 RTO 和 RPO？你们的目标是什么？

**English Answer:**

- **RTO (Recovery Time Objective)** = "How fast can we restart?" — the maximum time we allow the system to be down.
- **RPO (Recovery Point Objective)** = "How much data can we lose?" — the maximum data loss we can accept.

| Failure Type | RTO | RPO | How We Do It |
|---|---|---|---|
| One Pod crashes | < 30 sec | 0 | Kubernetes restarts it automatically |
| One Node fails | < 2 min | 0 | Cluster Autoscaler adds a new Node |
| One AZ goes down | < 5 min | 0 | Pods are spread across 3 AZs; Aurora has Multi-AZ |
| Singapore region fails | < 15 min | < 5 min | Promote Hong Kong Aurora to primary; redeploy EKS |
| Someone deletes data by mistake | < 30 min | < 5 min | Aurora PITR (Point-in-Time Recovery) |

**中文解释：**

- **RTO（恢复时间目标）**：系统宕机后，最多允许多长时间恢复服务。
- **RPO（恢复点目标）**：最多允许丢失多长时间的数据。

关键设计：Aurora Global Database 的跨区复制延迟 < 1秒，所以香港的数据几乎是实时的，RPO < 5分钟。

---

### Q3. How does your system stay available when one Availability Zone (AZ) goes down?
### 问题3：当一个可用区（AZ）宕机时，系统如何保持可用？

**English Answer:**

We use three key tools to handle AZ failures:

1. **Pods are spread across all AZs** — we use `topologySpreadConstraints` in Kubernetes. This forces the system to put pods in different AZs. For example, if we have 6 pods, we put 2 in AZ-a, 2 in AZ-b, and 2 in AZ-c. If AZ-a goes down, the other 4 pods in AZ-b and AZ-c still work.

2. **Aurora Multi-AZ** — Aurora automatically keeps a copy of the database in each AZ. If the writer in AZ-a fails, Aurora takes about 30 seconds to promote a reader in AZ-b to become the new writer. The application does not need to change any code.

3. **RDS Proxy** — This sits between our application and Aurora. When Aurora fails over, RDS Proxy automatically connects to the new writer. The application just sees a short pause, then continues working.

**中文解释：**

三道保障：
1. **Kubernetes topologySpreadConstraints**：强制Pod跨AZ均匀分布，一个AZ宕机，剩余Pod继续处理请求。
2. **Aurora Multi-AZ**：数据库自动在多个AZ有副本，主库故障后30秒内自动切换到备库。
3. **RDS Proxy**：连接池代理，感知Aurora故障切换，应用层无需修改连接串，透明切换。

---

### Q4. If Singapore is completely down, how do you switch to Hong Kong?
### 问题4：如果新加坡整个Region宕机，如何切换到香港？

**English Answer:**

This is our **cross-region disaster recovery** plan. Here are the steps:

**Step 1 — Promote the Hong Kong database (< 1 minute)**  
We run one AWS command to make the Hong Kong Aurora cluster the new primary (writer):
```bash
aws rds failover-global-cluster \
  --global-cluster-identifier smart-invest-global \
  --target-db-cluster-identifier arn:aws:rds:ap-east-1:...:cluster:smart-invest-dr
```

**Step 2 — Redirect traffic (< 5 minutes)**  
We update Route 53 DNS to point `app.smartinvest.com` to the Hong Kong load balancer. Because we use low TTL (60 seconds), DNS updates propagate quickly.

**Step 3 — Start EKS workloads in Hong Kong (< 10 minutes)**  
We use ArgoCD and Kustomize. The Hong Kong EKS cluster already has all the Kubernetes configs stored in Git. We just apply them.

**Total time: under 15 minutes.**

We run this drill every quarter to make sure it works.

**中文解释：**

跨Region切换3步走：
1. **提升香港Aurora为主库**：一条AWS CLI命令，约1分钟完成。
2. **切换Route 53 DNS**：将域名指向香港的ALB，低TTL保证快速生效。
3. **香港EKS启动工作负载**：ArgoCD从Git拉取配置，自动部署所有微服务。

全程不超过15分钟。我们每季度进行一次演练，确保流程有效。

---

### Q5. Why do you put NAT Gateways in public subnets, but EKS and Aurora in private subnets?
### 问题5：为什么 NAT Gateway 放在公有子网，而 EKS 和 Aurora 放在私有子网？

**English Answer:**

This is a security design called **"defense in depth"** — we add many layers of protection.

- **Private subnets** have no direct connection to the internet. Attackers cannot reach our EKS pods or Aurora database directly.
- **EKS pods** need to call external APIs (like sending emails). They go through the **NAT Gateway** in the public subnet. NAT Gateway lets them call the internet, but blocks anyone from the internet calling them back.
- **Aurora** never needs to talk to the internet at all. It only talks to EKS pods inside the VPC. So we put it in the most private subnet.

We also use **VPC Endpoints** so that EKS pods can talk to AWS services (like Secrets Manager, ECR, CloudWatch) without the traffic leaving the AWS network at all.

**中文解释：**

这是"纵深防御"网络设计：
- **公有子网**：只放 NAT Gateway 和 ALB，暴露最小的攻击面。
- **私有子网（App层）**：EKS节点，外部无法直接访问，出向流量通过NAT Gateway。
- **私有子网（Data层）**：Aurora和Redis，完全不对外，只允许来自EKS的流量（Security Group白名单）。
- **VPC Endpoint**：访问Secrets Manager、ECR等AWS服务走AWS内网，不经过公网，进一步减少攻击面。

---

## Part 2 — EKS & Microservices
## 第二部分：EKS 与微服务

---

### Q6. Why did you choose EKS instead of ECS Fargate?
### 问题6：为什么选择 EKS 而不是 ECS Fargate？

**English Answer:**

Both EKS and ECS can run containers. We chose EKS for three main reasons:

1. **Network Policy** — EKS lets us use Calico or AWS VPC CNI to set rules like "service A cannot talk to service B." ECS Fargate does not have this feature. For a financial system, we need to strictly control which service can talk to which database.

2. **PodDisruptionBudget (PDB)** — In EKS, we can say "always keep at least 1 portfolio-service pod running." This protects us during maintenance or node upgrades. ECS does not have a direct equivalent.

3. **More control** — EKS is standard Kubernetes. We can use any open-source Kubernetes tool (Prometheus, cert-manager, Karpenter, ArgoCD). ECS is AWS-specific and has fewer options.

The trade-off is that EKS is more complex to manage. But for a financial-grade system, the extra control is worth it.

**中文解释：**

选择EKS的3个关键原因：
1. **Network Policy（网络隔离）**：EKS + Calico可以实现细粒度的Pod间网络访问控制，这是金融合规要求的。ECS Fargate不支持。
2. **PodDisruptionBudget**：维护期间保证最少可用Pod数量，ECS没有等价功能。
3. **生态系统**：标准Kubernetes，可以使用所有开源工具（Prometheus、ArgoCD、Karpenter等）。

---

### Q7. What is IRSA and why is it better than putting AWS keys in the code?
### 问题7：什么是 IRSA？为什么比把 AWS 密钥放在代码里更好？

**English Answer:**

**IRSA** stands for **IAM Roles for Service Accounts**. It is a way to give each Kubernetes pod permission to use AWS services, without using any password or access key.

**Old way (bad):** Put `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as environment variables in the pod. Problems:
- If someone reads the pod config, they can steal the key.
- The key never expires automatically.
- All pods share the same key, so one compromised pod puts everything at risk.

**IRSA (good):**
- Each pod gets its own IAM Role. For example, `portfolio-service` gets a role that can only read its own secrets from Secrets Manager.
- There is no password to steal. AWS gives the pod a short-lived token (expires every hour).
- Tokens rotate automatically.

This follows the **principle of least privilege** — each service can only do exactly what it needs, nothing more.

**中文解释：**

IRSA（IAM Roles for Service Accounts）解决了"如何让Pod安全访问AWS资源"的问题：

- **旧方式（危险）**：把AK/SK硬编码或放入环境变量，密钥长期有效，一旦泄露后果严重。
- **IRSA（安全）**：Pod通过K8s ServiceAccount绑定IAM Role，获取自动轮换的临时Token（每小时过期），无需任何长期密钥。每个服务只有访问自己资源的权限（最小权限原则）。

---

### Q8. How does the system handle a sudden traffic spike, like 10x more users?
### 问题8：如果流量突然增加10倍，系统如何应对？

**English Answer:**

We use a **two-level autoscaling** system:

**Level 1 — Pod scaling (HPA):**  
Kubernetes HPA (Horizontal Pod Autoscaler) watches CPU and memory usage. When CPU goes above 60%, it adds more pods. For example, `portfolio-service` can scale from 2 pods to 20 pods automatically in about 15 seconds.

**Level 2 — Node scaling (Karpenter):**  
When there are more pods than the current nodes can hold, Karpenter automatically adds new EC2 instances to the cluster. Karpenter is faster than the old Cluster Autoscaler — it can add a new node in about 60 seconds.

**Scale-down protection:**  
When traffic drops, we wait 5 minutes (stabilizationWindowSeconds: 300) before removing pods. This avoids "flapping" — removing pods too quickly and then needing to add them back.

**中文解释：**

两级弹性伸缩：
1. **Pod级（HPA）**：CPU超过60%或内存超过70%时，自动增加Pod数量（最多20个）。扩容无等待，缩容有5分钟稳定窗口防止抖动。
2. **Node级（Karpenter）**：当Node资源不足时，Karpenter自动添加新的EC2实例，速度比传统Cluster Autoscaler快约2倍（约60秒）。

极端情况下，系统可以在2-3分钟内从最小配置扩展到最大配置，无需人工干预。

---

## Part 3 — Security
## 第三部分：安全设计

---

### Q9. How does the system protect against DDoS attacks?
### 问题9：系统如何防御 DDoS 攻击？

**English Answer:**

We use a **three-layer defense**:

**Layer 1 — AWS Shield Standard (automatic, free)**  
This protects against large network attacks (like SYN floods and UDP floods) at the CloudFront level. It's always on and works 24/7.

**Layer 2 — AWS WAF (Web Application Firewall)**  
WAF runs on CloudFront and checks every HTTP request. It blocks:
- SQL Injection (attacker puts SQL code in a form field)
- XSS (Cross-Site Scripting)
- Known bad bots
- Rate limiting: if one IP sends more than 1000 requests in 5 minutes, it gets blocked automatically.

**Layer 3 — CloudFront absorbs the traffic**  
CloudFront is a global CDN. It handles attacks at the edge, before traffic even reaches our servers in Singapore or Hong Kong. This means our EKS cluster and Aurora database are never directly hit.

**中文解释：**

三层DDoS防护：
1. **Shield Standard**：自动防护L3/L4网络层攻击（流量清洗），免费，部署在CloudFront。
2. **WAF**：防护L7应用层攻击，规则包括SQL注入、XSS、恶意Bot，还有频率限制（1000次/5分钟/IP）。
3. **CloudFront边缘节点**：攻击流量在边缘被吸收和过滤，不会到达新加坡或香港的服务器。

---

### Q10. How does the system store and protect passwords and secrets?
### 问题10：系统如何存储和保护密码、密钥等敏感信息？

**English Answer:**

We follow one rule: **no secret is ever stored in code, config files, or Kubernetes Secrets in plain text.**

Here's how it works:

1. **AWS Secrets Manager** stores all secrets:
   - Database password (auto-rotated every 30 days)
   - JWT signing key (rotated every 90 days)
   - Redis auth token

2. **AWS KMS (Key Management Service)** encrypts the secrets inside Secrets Manager. We use our own Customer Managed Keys (CMK), not AWS's default keys.

3. **Secrets Store CSI Driver** injects secrets into the pod as mounted files at runtime. The secret is never stored in a Kubernetes Secret object (which is only base64-encoded, not truly encrypted).

4. **Aurora** uses **IAM Database Authentication** — instead of a username/password, the pod uses its IAM token to connect. No password needed.

**中文解释：**

零明文密钥原则：
- **Secrets Manager**：集中存储所有密钥，数据库密码每30天自动轮换，无需重启应用（RDS Proxy会透明切换）。
- **KMS（客户管理密钥）**：对Secrets Manager中的数据做信封加密，密钥控制权在我们手中。
- **Secrets Store CSI Driver**：Pod启动时从Secrets Manager拉取密钥挂载为文件，不写入K8s Secret（K8s Secret只是base64，不是加密）。
- **Aurora IAM认证**：Pod用IAM临时Token连接数据库，根本没有数据库密码。

---

### Q11. Someone on your team accidentally pushes a bad Docker image to production. How does the system catch this?
### 问题11：如果团队成员不小心把有问题的 Docker 镜像推送到了生产环境，系统如何防御？

**English Answer:**

We have **multiple checkpoints** before any image reaches production:

1. **GitHub Actions CI** — every pull request runs:
   - Unit tests and integration tests
   - OWASP dependency scan (checks for known security vulnerabilities in libraries)
   - Amazon Inspector scans the Docker image for CVEs (known security holes)
   - If any check fails, the image cannot be pushed to ECR.

2. **Image Signing** — after the image passes all checks, we sign it with cosign (or AWS Signer). A Kyverno policy on EKS checks: "Is this image signed?" If not, the pod cannot start.

3. **ArgoCD + manual approval gate** — changes go through: dev → staging → production. The production step requires a human to approve.

4. **Canary rollout** — even after approval, we only send 10% of traffic to the new version first. We watch the error rate. If errors go above 1%, ArgoCD automatically stops the rollout and rolls back.

**中文解释：**

4道安全闸门：
1. **CI门禁**：PR阶段运行单元测试、依赖扫描、Inspector镜像CVE扫描，全部通过才能推送到ECR。
2. **镜像签名**：只有通过CI签名的镜像才能在EKS中运行（Kyverno Policy强制校验签名），防止供应链攻击。
3. **手动审批门**：生产环境部署需要人工确认（GitOps manual approval gate）。
4. **Canary金丝雀发布**：先放10%流量，监控错误率，超过1%自动回滚，保护99%的用户。

---

## Part 4 — Database Design
## 第四部分：数据库设计

---

### Q12. Why did you choose Aurora PostgreSQL instead of regular RDS PostgreSQL?
### 问题12：为什么选择 Aurora PostgreSQL 而不是普通的 RDS PostgreSQL？

**English Answer:**

Aurora PostgreSQL is better than regular RDS in three important ways for a financial system:

1. **Faster failover**: When the primary database fails, Aurora promotes a reader in about **30 seconds**. Regular RDS takes about **60–120 seconds**. In a financial system, 30 extra seconds of downtime can mean many failed transactions.

2. **Storage auto-expansion**: Aurora's storage grows automatically from 10GB up to 128TB. With regular RDS, you have to set a fixed size and manually resize.

3. **Global Database for DR**: Aurora Global Database can replicate data to Hong Kong with less than **1 second of delay**. This is how we achieve RPO < 5 minutes for cross-region disasters. Regular RDS does not have this feature.

The trade-off is that Aurora costs more than regular RDS. But for a financial product, reliability is more important than cost.

**中文解释：**

Aurora vs RDS三个关键差异：
1. **故障切换更快**：Aurora约30秒，RDS约60-120秒。金融业务每多一秒宕机损失都很大。
2. **存储自动扩展**：Aurora从10GB自动扩展到128TB，无需手动操作，不影响业务。
3. **Global Database**：跨Region复制延迟 < 1秒，这是我们能实现香港灾备RPO < 5分钟的技术基础，普通RDS没有这个功能。

---

### Q13. What problem does RDS Proxy solve?
### 问题13：RDS Proxy 解决了什么问题？

**English Answer:**

Spring Boot applications create many database connections. In a microservices system with 50+ pods, each pod might keep 10 connections open. That's 500+ connections to Aurora, which is near Aurora's maximum limit.

**RDS Proxy** sits between the pods and Aurora:
- It **pools** connections. 500 pods can share a smaller number of actual database connections.
- When Aurora fails over (switches to a new primary), RDS Proxy **automatically reconnects** to the new primary. The application sees only a 1-2 second pause.
- When the database password rotates every 30 days, RDS Proxy fetches the new password from Secrets Manager automatically. We don't need to restart any pods.

**中文解释：**

RDS Proxy解决3个问题：
1. **连接数爆炸**：50个Pod × 每Pod10个连接 = 500个连接。Aurora的连接数有上限（约5000），RDS Proxy通过连接复用将实际到Aurora的连接控制在合理范围。
2. **故障切换透明化**：Aurora主备切换时，RDS Proxy自动感知新主库，应用层只感受到短暂停顿（1-2秒），无需修改连接串。
3. **密码轮换无感**：Secrets Manager每30天更换数据库密码，RDS Proxy自动拉取新密码，不需要重启Pod。

---

## Part 5 — CI/CD & GitOps
## 第五部分：CI/CD 与 GitOps

---

### Q14. Can you walk me through what happens when a developer merges code to main?
### 问题14：当开发者把代码合并到 main 分支时，发生了什么？请走一遍流程。

**English Answer:**

Here is the full journey from code to production:

```
Developer merges PR to main
        ↓
1. GitHub Actions starts (automatic)
   - Runs unit tests (mvn test)
   - Builds the JAR file
   - Builds Docker image
   - Amazon Inspector scans the image for CVEs
   - Signs the image with cosign
   - Pushes the image to ECR with a unique tag (git commit SHA)
        ↓
2. GitHub Actions updates the infra repo
   - Changes the image tag in kustomization.yaml
   - Commits and pushes to the infra Git repo
        ↓
3. ArgoCD detects the change (polls every 3 minutes or uses webhook)
   - Deploys to staging automatically
   - Runs smoke tests
        ↓
4. Human approves production deployment
   - ArgoCD deploys to production
   - Canary: 10% traffic → watch errors → 50% → 100%
   - If error rate > 1%, ArgoCD rolls back automatically
```

The key idea is that **Git is the single source of truth**. If someone changes the cluster manually (e.g., with kubectl), ArgoCD detects the drift and resets it back to what Git says.

**中文解释：**

GitOps核心理念：**Git是唯一的事实来源**。

完整流程：代码合并 → CI（构建+测试+扫描+签名+推送ECR） → 更新infra仓库的镜像Tag → ArgoCD检测变更 → 自动部署到Staging → 人工审批 → Canary金丝雀发布到Production → 自动监控错误率，超阈值自动回滚。

任何人通过kubectl手动修改集群配置，ArgoCD都会检测到偏差（drift）并自动恢复到Git中的声明状态。

---

### Q15. What is a "canary deployment"? Why do you use it instead of releasing to all users at once?
### 问题15：什么是"金丝雀发布"？为什么不直接发布给所有用户？

**English Answer:**

A canary deployment means you release a new version to only a **small percentage of users first** — say 10%. You watch how it behaves. If everything is fine, you slowly increase to 50%, then 100%. If something goes wrong, you only affected 10% of users, and you roll back immediately.

The name comes from an old practice where miners brought canary birds into coal mines. If the air was poisonous, the canary would fall sick first — a warning before humans were harmed.

In our system, ArgoCD Rollouts does this automatically:
- Send 10% of traffic to the new version
- Watch error rate for 5 minutes
- If error rate < 1%, continue to 50%
- If error rate > 1%, roll back to the old version automatically

Compare to a **big-bang deployment** (all users at once): if there's a bug, all users are affected, and rollback takes time. Canary deployment is much safer.

**中文解释：**

金丝雀发布：先把新版本暴露给少量用户（10%），观察是否有错误，再逐步扩大（50% → 100%）。

名字来源：早期矿工会带金丝雀进矿井，一氧化碳积累时金丝雀先昏倒，给矿工预警。新版本就是那只"金丝雀"——先承受可能的风险，保护大多数用户。

ArgoCD Rollouts自动执行：10% → 观察5分钟 → 错误率 < 1% → 继续扩大 → 否则自动回滚。对比"全量发布"：一旦出bug影响100%用户，本方案最坏情况只影响10%用户。

---

## Part 6 — Observability
## 第六部分：可观测性

---

### Q16. If a user says "the system is slow," how do you find out what's wrong?
### 问题16：如果用户说"系统很慢"，你如何找到问题所在？

**English Answer:**

We use a **three-signal approach**: Metrics, Logs, and Traces.

**Step 1 — Check Metrics (Grafana dashboard)**  
Open the RED dashboard (Rate / Error / Duration):
- Is the request rate (number of requests per second) normal?
- Is the error rate above 1%?
- Is the response time (P99 latency) high? For example, normally P99 = 200ms, but now it's 2000ms.

This tells us which service is slow.

**Step 2 — Check Logs (CloudWatch Logs Insights)**  
Run a query to find error messages or slow requests in the specific service:
```
fields @timestamp, level, message, traceId
| filter level = "ERROR" or duration > 1000
| sort @timestamp desc
```

**Step 3 — Check Traces (AWS X-Ray)**  
X-Ray shows the full journey of one request: `user-service → database → Redis`. We can see exactly which step is slow. For example: "The database query for this endpoint took 1800ms — that's the bottleneck."

**中文解释：**

排查"系统慢"三步法（Metrics → Logs → Traces）：

1. **Grafana RED看大盘**：Rate（请求量有没有异常峰值）、Error（错误率有没有升高）、Duration（P99延迟有没有变高），定位到哪个服务。
2. **CloudWatch Logs查错误日志**：在问题服务中搜索ERROR日志或慢请求（duration > 1000ms），找到具体报错信息。
3. **X-Ray看全链路Trace**：找到某一个慢请求，看完整调用链（HTTP → Service → RDS → Redis），精确定位是哪个环节耗时最长。

三者配合，通常5-10分钟内可以定位问题根因。

---

## Quick Reference — Key Technology Choices
## 快速参考：核心技术选型理由

| Technology | Why We Chose It | Why Not the Alternative |
|---|---|---|
| EKS | Network Policy, PDB, full K8s ecosystem | ECS Fargate: less control, no Network Policy |
| Aurora PostgreSQL | 30s failover, Global DB, auto storage | Regular RDS: slower failover, no Global DB |
| RDS Proxy | Connection pooling, transparent failover | Direct connection: connection limit, slow failover |
| IRSA | No long-lived credentials, per-service least privilege | Hard-coded AK/SK: security risk, key rotation pain |
| ArgoCD GitOps | Git as source of truth, drift detection, audit trail | kubectl apply: no audit, no drift detection |
| Secrets Store CSI | Secrets never in K8s Secret (base64 only) | K8s Secret: base64 is not encryption |
| CloudFront + WAF | Edge protection, DDoS absorption, geo-restriction | Direct ALB exposure: no edge protection |
| Canary Deployment | Max 10% users affected if bug found | Big-bang: 100% users affected |

---

> **面试小贴士**：
> - 每个技术选型都要说"为什么选它，为什么不选另一个"（trade-off）。
> - 两岸三中心优先讲RTO/RPO数字，面试官印象深刻。
> - 遇到不会的，说"In our current design we did X, but if I had more time I would also consider Y"。
