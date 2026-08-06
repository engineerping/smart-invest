# Helm Complete Guide

> 从「为什么需要 Helm」到「Helm3 完整工作原理」——以 smart-invest 项目为实战示例
>
> 读者定位：资深 Java 开发工程师，熟悉 Maven/Gradle、Spring Boot、Docker、K8S 基础概念

---

## 目录

1. [Helm 诞生背景与设计初衷](#1-helm-诞生背景与设计初衷)
2. [Helm 与 Terraform 的关系——不是替代，是分工](#2-helm-与-terraform-的关系不是替代是分工)
3. [没有 Helm 的世界——K8S 原生的痛苦](#3-没有-helm-的世界k8s-原生的痛苦)
4. [Helm1 → Helm2 → Helm3 演进史](#4-helm1--helm2--helm3-演进史)
5. [Helm3 架构深入](#5-helm3-架构深入)
6. [Helm3 完整工作流程（源码级）](#6-helm3-完整工作流程源码级)
7. [Helm3 模板引擎深度解析](#7-helm3-模板引擎深度解析)
8. [Helm3 最佳实践与面试要点](#8-helm3-最佳实践与面试要点)
9. [附录：smart-invest 项目实战回放](#9-附录smart-invest-项目实战回放)

---

## 1. Helm 诞生背景与设计初衷

### 1.1 时间线

```
2015 年 6 月    K8S 1.0 GA 发布
2015 年 10 月    Helm 项目在 Deis 公司（后被微软收购）启动
2016 年 2 月    Helm 首个公开版本发布
2016 年 6 月    Helm 加入 CNCF
2018 年 6 月    Helm 从 CNCF 毕业（成为 K8S 生态"标准包管理器"）
2019 年 11 月   Helm3 发布（移除 Tiller，架构重大变更）
2024 年 4 月    Helm 成为 CNCF 毕业项目中下载量最高的工具之一
```

### 1.2 作者 Matt Butcher 的原始动机

Matt Butcher（Helm 创始人之一，Deis 公司工程师）在 2015 年发现：

> **问题**：K8S 提供了强大的 API（Deployment、Service、ConfigMap...），但缺乏一种「打包、分享、版本管理 K8S 应用」的方式。相当于有了 `javac` 但没有 Maven/Gradle。

他的设计目标很明确：

| 设计目标 | 类比（Java 世界） |
|----------|-------------------|
| 把一组 K8S YAML 打包成一个可复用的单元 | Maven 把 .java 编译打包成 .jar |
| 支持参数化部署（同一套 YAML，不同环境不同值） | `application-{profile}.yml` |
| 支持版本管理和回滚 | Maven SNAPSHOT / Release 版本 + 回滚到旧版 |
| 支持依赖管理（Chart A 依赖 Chart B） | pom.xml 的 `<dependency>` |
| 支持仓库分发（Chart 存到远程，其他人 `helm install`） | Maven Central / Nexus |

### 1.3 Helm 名称的由来

**Helm** = 船舵。K8S 的名字来自希腊语"舵手"（κυβερνήτης），Helm 就是"舵手的舵"——引导 K8S 舰队航行的工具。

---

## 2. Helm 与 Terraform 的关系——不是替代，是分工

### 2.1 最常见的一个误解

> ❌ "Helm 是 K8S 版的 Terraform，所以有 Helm 就不需要 Terraform 了。"
>
> ✅ "Terraform 管基础设施（IaaS），Helm 管 K8S 内部应用（PaaS/SaaS）。它们是互补的上下层关系。"

### 2.2 清晰的层次划分

```
┌──────────────────────────────────────────────────────────────────────┐
│                        云上完整技术栈                                │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Helm 管理层                                 │   │
│  │  "集群内跑什么应用"                                           │   │
│  │                                                               │   │
│  │  helm install smart-invest  →  创建 Deployment/Service/       │   │
│  │                                  Ingress/Secret/ConfigMap     │   │
│  │  helm upgrade  →  滚动更新 7 个微服务                          │   │
│  │  helm rollback →  回滚到上一个版本                            │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              │ 运行在                                │
│                              ▼                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    K8S 集群（K3S / EKS / GKE / AKS）          │   │
│  │  "应用的运行平台"                                             │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              │ 跑在                                  │
│                              ▼                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                  Terraform 管理层                              │   │
│  │  "集群本身是什么、网络怎么配、有什么云资源"                     │   │
│  │                                                               │   │
│  │  terraform apply → 创建 EC2 实例 / VPC / 安全组 / RDS / EKS   │   │
│  │  terraform plan  → 预览基础设施变更                            │   │
│  │  terraform destroy → 销毁所有云资源                            │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              │ 调 AWS/GCP/Azure API                  │
│                              ▼                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              云基础设施（EC2 / VPC / RDS / S3 / IAM...）       │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.3 详细对比表

| 维度 | Terraform | Helm |
|------|-----------|------|
| **管理对象** | 云资源（VM、网络、数据库、DNS...） | K8S 内部资源（Pod、Service、Ingress...） |
| **目标 API** | AWS/GCP/Azure API | K8S API Server |
| **状态存储** | State file（本地或 S3/DynamoDB 等远端） | K8S Secret（集群内） |
| **语言** | HCL（HashiCorp Configuration Language） | Go Template + YAML |
| **声明式** | ✅ 声明目标状态 | ✅ 声明目标状态 |
| **依赖管理** | `depends_on` / 模块引用 | Chart dependencies + conditions |
| **回滚** | 通过 state file 恢复到上一版本 | `helm rollback` 原生支持 |
| **模块/包分发** | Terraform Registry | Helm Repository / OCI Registry |
| **生命周期** | create → plan → apply → destroy | install → upgrade → rollback → uninstall |
| **典型用户** | DevOps / 平台工程师 | 应用开发者 / 发布工程师 |

### 2.4 实际协作流程（smart-invest 为例）

```bash
# ===== 第一步：Terraform 创建基础设施 =====
# 文件: infrastructure/modules/ec2/main.tf
terraform apply
# → 创建了: VPC、子网、安全组、EC2 实例、EIP
# → 输出: ec2_public_ip = "192.168.31.192"

# ===== 第二步：在 EC2 上安装 K3S =====
ssh george@192.168.31.192 "curl -sfL https://get.k3s.io | sh -"
# → 现在有一台跑着 K3S 的机器

# ===== 第三步：Helm 部署应用到 K3S =====
# 文件: infrastructure/helm-charts/umbrella/Chart.yaml
helm upgrade --install smart-invest ./umbrella/ --namespace smart-invest
# → 创建了: 7 个 Deployment + 7 个 Service + Ingress + Secret
# → 7 个微服务在 K3S 集群内运行
```

**Terraform 管"这台机器存在、网络通、安全组对"，Helm 管"机器上的 K8S 里跑什么应用"。**

### 2.5 重叠地带——Terraform 也能管 K8S 资源？

是的，Terraform 有 `kubernetes` 和 `helm` provider：

```hcl
# Terraform 里调用 Helm——两种工具不是互斥的
resource "helm_release" "smart_invest" {
  name       = "smart-invest"
  chart      = "./infrastructure/helm-charts/umbrella"
  namespace  = "smart-invest"

  set {
    name  = "user-service.image.tag"
    value = "v1"
  }
}
```

但这不改变它们的定位：**Terraform 调用 Helm → Terraform 管整个部署流水线，Helm 专注于 K8S 应用的打包和生命周期**。

---

## 3. 没有 Helm 的世界——K8S 原生的痛苦

以 smart-invest（7 个微服务）为例，如果不使用 Helm，你需要这样部署：

### 3.1 原生 kubectl 方式

```bash
# ==========================================
# 没有 Helm：每次部署需要手动管理 20+ 个 YAML
# ==========================================

# 1. 创建 Namespace
kubectl create namespace smart-invest

# 2. 创建 Secret（密码需要手动 base64）
echo -n 'localdev_only' | base64       # bG9jYWxkZXYtb25seQ==
echo -n 'smartinvest-demo-secret...' | base64
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: smart-invest-secrets
  namespace: smart-invest
type: Opaque
data:
  SPRING_DATASOURCE_PASSWORD: bG9jYWxkZXYtb25seQ==
  JWT_SECRET: c21hcnRpbnZlc3QtZGVtby1zZWNyZXQta2V5LWNoYW5nZS1tZS1wbGVhc2UtMzJieXRlcw==
  RABBITMQ_PASSWORD: bG9jYWxkZXYtb25seQ==
EOF

# 3. 逐个部署 7 个微服务（每个至少 2 个 YAML = 14+ 个文件）
kubectl apply -f rabbitmq-deployment.yaml
kubectl apply -f rabbitmq-service.yaml
kubectl apply -f rabbitmq-pvc.yaml

kubectl apply -f user-service-deployment.yaml    # 注意 image tag 不能写死
kubectl apply -f user-service-service.yaml

kubectl apply -f fund-service-deployment.yaml
kubectl apply -f fund-service-service.yaml

kubectl apply -f order-service-deployment.yaml
kubectl apply -f order-service-service.yaml

kubectl apply -f notification-worker-deployment.yaml
kubectl apply -f notification-worker-service.yaml

kubectl apply -f api-gateway-deployment.yaml
kubectl apply -f api-gateway-service.yaml

kubectl apply -f frontend-deployment.yaml
kubectl apply -f frontend-service.yaml

# 4. 创建 Ingress
kubectl apply -f ingress.yaml

# 5. 逐个检查 Pod 是否 Ready
kubectl -n smart-invest get pods -w
```

### 3.2 不使用 Helm 的 7 大痛点（结合 smart-invest 真实经历）

```
痛点 1: 模板复制粘贴
─────────────────────────────────────────────────────────────
7 个微服务的 Deployment YAML，90% 内容一样（探针配置、环境变量
注入方式、资源限制格式），只有 image、port、replicas 不同。
每次新增一个服务 → 复制粘贴 → 改 10 个地方 → 容易漏改。

有 Helm 后:
  一个模板 deployment.yaml + 7 个 values.yaml，DRY 原则。


痛点 2: 环境差异管理散乱
─────────────────────────────────────────────────────────────
开发环境用 latest tag，生产环境用 v1.2.3 tag；
开发环境 1 副本，生产环境 3 副本；
开发环境不暴露 Ingress，生产环境要 Ingress + TLS。

→ 只能维护多套 YAML 文件（dev/、staging/、prod/），
   改一个地方要同步到所有环境。

有 Helm 后:
  一套模板 + 多个 values 文件: helm install -f values-prod.yaml


痛点 3: 版本回滚困难
─────────────────────────────────────────────────────────────
新版本上线后发现 bug → 怎么回滚？
  - git revert + 重新 kubectl apply（慢，容易出错）
  - 如果上次部署的 YAML 没有 commit → 找不回来了
  - kubectl rollout undo 只能回滚 Deployment，
    不回滚 Service/ConfigMap/Ingress 的变更

有 Helm 后:
  helm rollback smart-invest 17
  一键将所有 K8S 资源恢复到 REVISION 17 的状态。


痛点 4: 依赖顺序不可控
─────────────────────────────────────────────────────────────
RabbitMQ 必须比 fund-service、order-service、
notification-worker 先启动（它们启动时就连 RabbitMQ）。
kubectl apply 是并发执行的，不做依赖排序 → 启动失败，
需要手动重试。

有 Helm 后:
  Helm 的 hook（helm.sh/hook: post-install）和
  --wait 参数保证依赖就绪后才继续。


痛点 5: 部署状态不可见
─────────────────────────────────────────────────────────────
谁在什么时候部署了什么版本？改了什么参数？
kubectl 没有历史记录。只能靠 Slack 通知 + git log 猜测。

从 smart-invest 真实服务器查：
  helm history smart-invest -n smart-invest

  REVISION  UPDATED         STATUS      CHART          DESCRIPTION
  15        Aug 6 08:26     superseded  v0.2.0         Upgrade complete
  16        Aug 6 08:26     superseded  v0.2.0         Scale frontend to 2 replicas
  17        Aug 6 08:26     superseded  v0.2.0         Scale frontend back to 1 replica
  19   →    Aug 6 08:29     deployed    v0.2.0         Rollback to 17

  每一次变更、每一次回滚、每一个 description，清清楚楚。


痛点 6: 参数化部署全靠 sed
─────────────────────────────────────────────────────────────
CI/CD 里怎么把镜像 tag 注入到 YAML？
→ sed -i "s/\${IMAGE_TAG}/v1.2.3/g" deployment.yaml
→ 脆弱、容易出错、不可复用

有 Helm 后:
  helm upgrade ... --set user-service.image.tag=v1.2.3
  模板引擎原生支持，不需要 sed。


痛点 7: 应用分享/复用几乎不可能
─────────────────────────────────────────────────────────────
想分享你的「RabbitMQ + 微服务全家桶」给另一个团队？
→ 拷贝一堆 YAML 文件，告诉他们改哪些地方的 IP/密码
→ 对方改漏一个 → 跑不起来 → 找你 debug

有 Helm 后:
  helm package ./umbrella/
  → 生成 smart-invest-0.2.0.tgz
  → 推到 Chart 仓库或直接发 .tgz
  → 对方一条命令安装: helm install my-copy ./smart-invest-0.2.0.tgz \
      --set secrets.dbPassword=theirpassword
```

---

## 4. Helm1 → Helm2 → Helm3 演进史

### 4.1 演进概览

```
Helm1 (2015-2016)     Helm2 (2016-2019)          Helm3 (2019-至今)
─────────────────     ─────────────────          ─────────────────
原型阶段              引入 Tiller（服务端）       移除 Tiller！
                      引入 Chart Repository      客户端 only
                      引入 Release 管理          OCI Registry 支持
                                                 Lua 钩子 → K8S Job 钩子
                                                 3-way strategic merge
                                                 Helm SDK（可编程调用）
```

### 4.2 为什么 Helm2 引入 Tiller？

**动机**：Helm1 是纯客户端，没有状态管理。Helm2 引入 Tiller（一个跑在 K8S 集群内的 gRPC 服务）：

```
Helm2 架构:
┌──────────┐    gRPC     ┌──────────┐    创建/管理    ┌──────────────┐
│  helm    │ ──────────→ │  Tiller  │ ──────────────→ │  K8S API     │
│  CLI     │ ←────────── │  (Pod)   │ ←────────────── │  Server      │
└──────────┘             └──────────┘                 └──────────────┘
                                  │
                                  │ 存储
                                  ▼
                          ┌──────────────┐
                          │  ConfigMap/  │
                          │  Secret      │
                          │  (Release    │
                          │   History)   │
                          └──────────────┘
```

Tiller 的职责：
- 接收 helm CLI 的请求
- 渲染模板
- 与 K8S API Server 交互（创建/更新/删除资源）
- 存储 Release 历史

### 4.3 Tiller 带来的 3 大问题 → Helm3 全部解决

```yaml
# Tiller 三大痛点:

1. 安全噩梦:
   # Tiller 默认拥有集群级别的 admin 权限
   # 任何能连到 Tiller 的人都能操作集群
   kubectl -n kube-system get deploy tiller-deploy
   # Tiller 用 cluster-admin ServiceAccount 运行
   # RBAC 配置很复杂，很多团队干脆不配 → 安全隐患

2. 状态存储冲突:
   # 多个用户同时操作同一个 Release → Tiller 串行处理
   # Tiller 升级/重启期间 → 所有部署操作全部阻塞
   # 单点故障

3. 与 K8S RBAC 不统一:
   # Tiller 有自己的一套权限
   # K8S 自己有 RBAC
   # 两套权限体系并存 → 混乱
```

### 4.4 Helm3 的天才设计——移除 Tiller

```
Helm3 架构:
┌──────────┐    REST/HTTP    ┌──────────────┐
│  helm    │ ───────────────→│  K8S API     │
│  CLI/SDK │ ←───────────────│  Server      │
└──────────┘                 └──────────────┘
       │                             │
       │ 存储 Release 历史           │ 创建/管理资源
       ▼                             ▼
┌──────────────┐           ┌──────────────────┐
│  K8S Secret  │           │  Pods / Services │
│  (sh.helm.   │           │  / Deployments / │
│   release.v1)│           │  Ingresses ...   │
└──────────────┘           └──────────────────┘
```

**核心思想**：

1. **helm CLI 直接用 K8S API**——不再经过 Tiller 中间层
2. **用当前用户的 kubeconfig RBAC**——和 kubectl 权限完全一致，零额外配置
3. **Release 历史存在 K8S Secret 里**——在对应的 namespace 下，自然继承 RBAC 隔离

```bash
# 查看 Release 历史实际存储位置
kubectl -n smart-invest get secrets -l owner=helm

# 输出:
# NAME                            TYPE                 DATA   AGE
# sh.helm.release.v1.smart-invest.v1   helm.sh/release.v1   1      3d
# sh.helm.release.v1.smart-invest.v2   helm.sh/release.v1   1      3d
# sh.helm.release.v1.smart-invest.v3   helm.sh/release.v1   1      3d
# ...
# 每个 REVISION 对应一个 Secret！
```

---

## 5. Helm3 架构深入

### 5.1 核心组件

```
┌─────────────────────────────────────────────────────────────────┐
│                        helm CLI (Go 编写)                       │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌───────────────┐ │
│  │ 模板引擎  │  │ 依赖管理 │  │ Release   │  │  Repository   │ │
│  │ (Go      │  │ (Chart.  │  │ 生命周期   │  │ 交互          │ │
│  │  Template│  │  yaml +  │  │ (install/ │  │ (repo add/    │ │
│  │  +Sprig) │  │  lock)   │  │  upgrade/ │  │  update/push) │ │
│  │          │  │          │  │  rollback/│  │               │ │
│  │          │  │          │  │  uninstall│  │               │ │
│  └──────────┘  └──────────┘  └───────────┘  └───────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  K8S Client-Go SDK                       │  │
│  │  （复用 kubectl 同款 SDK，通过 kubeconfig 认证）           │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
         │                                    │
         │ REST/HTTP                          │ REST/HTTP
         ▼                                    ▼
┌─────────────────┐                ┌─────────────────────┐
│  K8S API Server │                │  OCI / Chart 仓库    │
│  (集群内)       │                │  (集群外)            │
│                 │                │                     │
│  Secret 存储    │                │  Chart .tgz 存储     │
│  Release 历史   │                │  index.yaml 索引     │
└─────────────────┘                └─────────────────────┘
```

### 5.2 Release 生命周期状态机

```
                        helm install
    [不存在] ──────────────────────────────→ [deployed]
                                                  │
                                   helm upgrade    │
                                                  ▼
                                            [superseded]
                                                  │
                             ┌────────────────────┼────────────────────┐
                             │                    │                    │
                      升级成功              升级失败              手动回滚
                             │                    │                    │
                             ▼                    ▼                    ▼
                       [deployed]            [failed]            [deployed]
                       新 REVISION           新 REVISION          新 REVISION
                                                  │
                                        helm rollback
                                                  │
                                                  ▼
                                            [deployed]
                                            新 REVISION
                                            （状态显示 Rollback to N）


                        helm uninstall
    [任何状态] ─────────────────────────────→ [uninstalled]
                                              （所有 REVISION 的 Secret 被删除）
```

### 5.3 存储机制——每个 REVISION 一个 Secret

```bash
# 在 smart-invest 集群上实际查看
kubectl -n smart-invest get secrets -l owner=helm,status=deployed

# 一个 REVISION 的 Secret 内容（解码后）:
{
  "name": "smart-invest",
  "info": {
    "status": "deployed",
    "description": "Upgrade complete"
  },
  "chart": {
    "metadata": {
      "name": "smart-invest",
      "version": "0.2.0"
    },
    "values": {
      "user-service": { "replicaCount": 1 },
      "frontend": { "replicaCount": 1 }
    },
    "templates": [ ... ]    // 渲染前的模板
  },
  "config": {               // 本次部署的最终 values
    "user-service": { ... },
    "frontend": { ... }
  },
  "manifest": "---\napiVersion: apps/v1\nkind: Deployment\n...",
  "version": 1
}
```

> 存储 Release 历史的 Secret 一般在 10 个以内，Helm 默认保留最近 10 个 REVISION（可通过 `--history-max` 调整）。旧 REVISION 的 Secret 会被自动清理。

---

## 6. Helm3 完整工作流程（源码级）

### 6.1 `helm install` 内部发生了什么

```
helm install my-release ./my-chart/ --namespace prod --set image.tag=v2
│
├── 1. 解析命令行参数
│      - name: my-release
│      - chart: ./my-chart/
│      - namespace: prod
│      - values override: image.tag=v2
│
├── 2. 加载 Chart
│      - 读 Chart.yaml（元数据）
│      - 读 values.yaml（默认值）
│      - 加载 templates/ 目录所有 .yaml/.tpl 文件
│      - 解析 dependencies（如果有）
│
├── 3. 合并 Values（4 层合并）
│      Layer 1: chart 内置 values.yaml
│      Layer 2: 父 chart 的 values（如果是子 chart）
│      Layer 3: -f 指定的外部 values 文件
│      Layer 4: --set 参数（最高优先级）
│
├── 4. 渲染模板（Template Rendering）
│      对每个 templates/*.yaml:
│        - 解析 Go Template 语法 {{ .Values.xxx }}
│        - 执行 Sprig 函数（quote, b64enc, toYaml, ...）
│        - 使用合并后的 Values 填充变量
│      输出: 一组完整的 K8S YAML（无模板语法残留）
│
├── 5. 验证 YAML
│      - 检查 YAML 语法
│      - 检查必填字段（apiVersion, kind, metadata.name）
│      - 可选: dry-run 模式（--dry-run）只验证不部署
│
├── 6. 排序资源（Resource Ordering）
│      Helm3 内置安装顺序:
│        Namespace → NetworkPolicy → ResourceQuota → LimitRange →
│        PodSecurityPolicy → Secret → ConfigMap → StorageClass →
│        PersistentVolume → PersistentVolumeClaim → ServiceAccount →
│        CustomResourceDefinition → ClusterRole → ClusterRoleBinding →
│        Role → RoleBinding → Service → DaemonSet → Pod →
│        ReplicationController → ReplicaSet → Deployment →
│        HorizontalPodAutoscaler → StatefulSet → Job → CronJob →
│        Ingress → APIService
│
│      这个顺序确保: Secret 在 Deployment 之前创建，
│                     Service 在 Ingress 之前创建
│
├── 7. 安装 Hooks（如果定义了）
│      按 hook 权重排序，执行 pre-install / post-install Job
│      等待 Hook Job 完成 → 才继续下一步
│
├── 8. 创建 K8S 资源
│      按排序后的顺序逐个 kubectl apply
│      每创建 1 个资源 → 等待 API Server 确认
│
├── 9. 等待就绪（如果 --wait）
│      轮询所有 Deployment/StatefulSet/DaemonSet 的 Ready 状态
│      全部就绪 或 timeout → 结束
│
├── 10. 存储 Release
│      创建 Secret:
│        name: sh.helm.release.v1.my-release.v1
│        namespace: prod
│        labels:
│          owner: helm
│          name: my-release
│          status: deployed
│          version: "1"
│        data:
│          release: <base64(gzip(json(Release)))>
│
└── 11. 输出部署结果
       NAME: my-release
       LAST DEPLOYED: Thu Aug  6 08:06:00 2026
       NAMESPACE: prod
       STATUS: deployed
       REVISION: 1
```

### 6.2 `helm upgrade` vs `helm install`

```bash
# helm upgrade 比 install 多了以下步骤：

helm upgrade my-release ./my-chart/
│
├── 1-5: 与 install 相同（加载、合并值、渲染、验证）
│
├── 6. 获取上一个 REVISION 的状态
│      - 从 Secret 读取上一个 REVISION 的完整配置
│      - 比较新旧 values 和 manifest 的差异
│
├── 7. 三路策略合并 (Three-Way Strategic Merge Patch)
│      ┌──────────────────────────────────────────────────┐
│      │  三路 = 旧 manifest + 新 manifest + 当前集群状态  │
│      │                                                  │
│      │  旧 (A): 上次 Helm 渲染出的 YAML                  │
│      │  新 (B): 这次 Helm 渲染出的 YAML                  │
│      │  当前 (C): 集群里实际存在的对象                   │
│      │                                                  │
│      │  合并逻辑:                                        │
│      │  - 字段在 B 中改了 → 用 B                         │
│      │  - 字段在 A 和 C 不同（被手动改过）→ 保留 C       │
│      │  - 字段在 B 中删了 → 删除                         │
│      │  - 字段在 B 中新增 → 添加                         │
│      └──────────────────────────────────────────────────┘
│
│      这比 kubectl apply 更智能：
│        kubectl apply 用 kubectl.kubernetes.io/last-applied-configuration
│        annotation 做记录，但 Helm 有完整的三路对比逻辑
│
├── 8. 计算差异 (Diff)
│      对新旧 manifest 做 diff（仅当 --dry-run 或 helm diff 插件）
│
├── 9. 执行 Hook Job（pre-upgrade / post-upgrade）
│
├── 10. 更新 K8S 资源
│      创建: 新增的资源
│      更新: 变更的资源
│      删除: 旧 manifest 有但新 manifest 没有的资源
│
├── 11. 存储新的 REVISION（Secret vN+1）
│      更新 status=deployed
│      把上一个 REVISION 的 status 改为 superseded
│      如果 --history-max 达到上限 → 删除最早的 REVISION Secret
│
└── 12. 输出结果
```

### 6.3 `helm rollback` 的秘密

```bash
helm rollback my-release 5

# 内部流程:
# 1. 从 Secret sh.helm.release.v1.my-release.v5 读取 Release 快照
# 2. 用该快照里的 values + chart + manifest 重新部署
# 3. 不是简单地「回退指针」——是真正地重新 apply 那一版
# 4. 创建新的 REVISION v(N+1)，描述为 "Rollback to 5"
# 5. REVISION 5 本身不变（status 保持 superseded）
#
# 所以 rollback 也会增加 REVISION 号！
```

从 smart-invest 真实数据验证：

```
REVISION  STATUS      DESCRIPTION
...
17       superseded  Scale frontend back to 1 replica
18       failed      context deadline exceeded
19  →    deployed    Rollback to 17          ← rollback 创建了新 REVISION！
```

---

## 7. Helm3 模板引擎深度解析

### 7.1 Go Template + Sprig 函数库

Helm 模板引擎 = **Go 标准库 `text/template`** + **[Sprig](http://masterminds.github.io/sprig/) 函数库** + 少量 Helm 专属函数。

### 7.2 核心内置对象

模板中 `.` 开头的都是"内置对象"，Helm 在渲染前注入：

```yaml
# {{ .Values }}      — values.yaml 内容（合并后）
# {{ .Chart }}       — Chart.yaml 的字段
# {{ .Release }}     — Release 信息
# {{ .Files }}       — chart 内的非模板文件
# {{ .Capabilities }}— K8S 集群版本和能力
# {{ .Template }}    — 当前模板的 Name/BasePath

# 实例: smart-invest 的 Deployment 模板
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "svc.fullname" . }}     # . = 根上下文
  # 渲染后: name: user-service
spec:
  replicas: {{ .Values.replicaCount }}
  # 渲染后: replicas: 1
  template:
    spec:
      containers:
        - image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          # 渲染后: image: "gongchengship/smart-invest-user-service:v1"
```

### 7.3 命名模板（Named Templates）与 `_helpers.tpl`

Helm 的最佳实践是将可复用的模板片段放 `templates/_helpers.tpl`：

```yaml
# templates/_helpers.tpl
{{/*
Expand the name of the chart.
*/}}
{{- define "svc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "svc.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "svc.labels" -}}
app.kubernetes.io/name: {{ include "svc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

**类比**：`_helpers.tpl` 就是 Java 里的 `@Component` / `@Configuration`——抽取公共逻辑，避免在每个类（模板）里重复写代码。

### 7.4 常用模板语法速查

```yaml
# ──── 变量输出 ────
{{ .Values.image.tag }}                  # 简单取值
{{ .Values.image.tag | quote }}          # 管道 + quote 函数 → "v1"
{{ .Values.image.tag | upper | quote }}  # 链式管道 → "V1"

# ──── 条件判断 ────
{{- if .Values.persistence.enabled }}
  volumeMounts: ...
{{- else }}
  emptyDir: {}
{{- end }}

# ──── 循环 ────
{{- range $key, $value := .Values.env }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}

# ──── 默认值 ────
{{ .Values.replicaCount | default 1 }}
# 等价于 Java: Optional.ofNullable(x).orElse(1)

# ──── 缩进控制 ────
{{- toYaml .Values.resources | nindent 12 }}
# - 去掉左边空白，nindent 12 缩进 12 格

# ──── with 作用域 ────
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 8 }}
{{- end }}
# 等价于 Java: if (imagePullSecrets != null) { ... }

# ──── include vs tpl ────
{{ include "svc.labels" . }}             # 引用命名模板
{{ tpl .Values.customTemplate . }}       # 把字符串当作模板渲染

# ──── 文件引用 ────
{{ .Files.Get "config.json" }}           # 读取 chart 内的文件内容

# ──── 常用函数 ────
{{ .Values.password | b64enc }}          # base64 编码（Secret 格式）
{{ .Values.password | sha256sum }}       # SHA-256 哈希
{{ list "a" "b" | join "," }}           # → "a,b"
{{ .Values.tag | trimSuffix "-SNAPSHOT" }}
```

### 7.5 白名单与安全限制

Helm3 模板不能：
- 访问文件系统（`.Files.Get` 只能读 chart 内部文件）
- 访问网络
- 执行系统命令
- 创建子进程

这保证了 `helm install https://some-evil-chart.com/evil.tgz` 也不会在**你的机器**上执行恶意代码——最多在集群里创建 K8S 资源（受 RBAC 限制）。

---

## 8. Helm3 最佳实践与面试要点

### 8.1 面试高频问题

**Q1: Helm2 vs Helm3 的核心区别？**

```
Helm2                          Helm3
─────────────────────────      ─────────────────────────
有 Tiller（集群内 gRPC 服务）   无 Tiller（客户端直连 API）
两套权限（Tiller + RBAC）      只用 K8S RBAC
Release 存在 ConfigMap          存在 Secret
Lua 钩子                        K8S Job 钩子
不支持 OCI Registry             原生支持 OCI（helm push oci://...）
Tiller 是单点故障              无单点问题
```

**Q2: `helm upgrade --install` 是做什么的？**

相当于 `INSERT OR UPDATE`——如果 Release 不存在就 `install`，存在就 `upgrade`。CI/CD 里用这个命令最安全。

**Q3: `--wait` 和 `--atomic` 的区别？**

| flag | 行为 |
|------|------|
| `--wait` | 等待所有资源 Ready，超时就标记 failed，**但不回滚** |
| `--atomic` | 等待所有资源 Ready，超时或失败 → **自动 rollback 到上一个版本** |

**Q4: Helm 的 values 合并顺序？**

```
子 chart values.yaml → 父 chart values → -f 文件 → --set 参数
（低优先级）                                            （高优先级）
```

**Q5: Umbrella Chart 是什么？为什么用？**

Umbrella Chart（聚合 Chart）是一个父 Chart，通过 `dependencies` 引用多个子 Chart。

优点：
- 一条命令部署整个系统
- 统一管理公共配置（如 global.imageTag）
- 子 Chart 可独立发布和回滚
- 相当于 Maven 的 multi-module project

**Q6: `helm template` vs `helm install`？**

```bash
# helm template: 只渲染模板 → 输出 YAML 到 stdout，不部署
# 用途: CI 中生成最终 YAML 做审查，或者配合 gitops 工具（如 ArgoCD）
helm template my-release ./chart/ --values values-prod.yaml > output.yaml

# helm install: 渲染 + 部署 + 存储 Release
helm install my-release ./chart/
```

**Q7: 如何安全的升级生产环境？**

```bash
# 1. 先 dry-run
helm upgrade --dry-run --debug my-release ./chart/

# 2. 先 diff
helm diff upgrade my-release ./chart/

# 3. 带上 atomic（失败自动回滚）
helm upgrade my-release ./chart/ --atomic --timeout 600s

# 4. 带上 description（方便 helm history 查看）
helm upgrade my-release ./chart/ --description="Fix: user-service OOM"
```

### 8.2 Chart 目录结构最佳实践

```yaml
my-chart/
├── Chart.yaml              # 必填：元数据
├── values.yaml             # 必填：默认配置
├── values.schema.json      # 推荐：JSON Schema 校验 values
├── charts/                 # 子 chart（手动或 helm dep build 生成）
├── templates/
│   ├── NOTES.txt           # 推荐：安装后显示的提示信息
│   ├── _helpers.tpl        # 推荐：命名模板（公共逻辑）
│   ├── deployment.yaml     # K8S 资源模板
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── serviceaccount.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   └── tests/              # 推荐：helm test 用的测试 Pod
│       └── test-connection.yaml
├── .helmignore             # 推荐：类似 .gitignore
├── Chart.lock              # 自动生成：依赖锁定
└── README.md               # 推荐：Chart 文档
```

### 8.3 Helm + CI/CD 典型流程

```yaml
# GitHub Actions / Jenkins Pipeline 示例
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Lint Chart
    run: helm lint ./infrastructure/helm-charts/umbrella/

  - name: Unit Test Templates
    run: helm unittest ./infrastructure/helm-charts/umbrella/

  - name: Package Chart
    run: helm package ./infrastructure/helm-charts/umbrella/

  - name: Push to Registry
    run: helm push ./smart-invest-*.tgz oci://registry.example.com/charts

  - name: Deploy to Staging
    run: |
      helm upgrade --install smart-invest oci://registry.example.com/charts/smart-invest \
        --namespace staging --create-namespace \
        --values values-staging.yaml \
        --atomic --timeout 600s

  - name: Deploy to Production
    if: github.ref == 'refs/heads/master'
    run: |
      helm upgrade --install smart-invest oci://registry.example.com/charts/smart-invest \
        --namespace production --create-namespace \
        --values values-production.yaml \
        --atomic --timeout 600s \
        --description="Release ${GITHUB_SHA}"
```

### 8.4 Helm 的局限性

```
1. 模板引擎是 Go Template（不是 YAML 原生）
   → 学习曲线陡峭，语法糖少
   → 缩进处理（nindent）容易出错

2. 不适合管理基础设施
   → Helm 操作 K8S API，不操作 AWS/GCP API
   → 不能用 Helm 创建 EKS 集群或 RDS 实例

3. values.yaml 膨胀
   → 大型 Chart 的 values.yaml 可能上千行
   → JSON Schema 可以缓解但增加维护成本

4. 不是 GitOps 原生工具
   → Helm 本身是命令式的（cli 操作）
   → 配合 ArgoCD/Flux → 才是声明式 GitOps

5. Secret 不是加密存储
   → Helm 的 Release Secret 是 base64 编码（不是加密）
   → 生产环境需要配合 SealedSecret 或 ExternalSecret
```

---

## 9. 附录：smart-invest 项目实战回放

### 9.1 真实 Helm History（2026-08-06 服务器实录）

```bash
$ sudo helm history smart-invest -n smart-invest

REVISION  STATUS      CHART              APP VERSION  DESCRIPTION
10        superseded  smart-invest-0.1.1  1.0.1        Rollback to 6
11        failed      smart-invest-0.2.0  1.1.0        Upgrade failed: timeout
12        superseded  smart-invest-0.1.1  1.0.1        Rollback to 6
13        superseded  smart-invest-0.1.1  1.0.1        Rollback to 6
14        failed      smart-invest-0.2.0  1.1.0        Upgrade failed: timeout
15        superseded  smart-invest-0.2.0  1.1.0        Upgrade complete
16        superseded  smart-invest-0.2.0  1.1.0        Scale frontend to 2 replicas
17        superseded  smart-invest-0.2.0  1.1.0        Scale frontend back to 1 replica
19        deployed    smart-invest-0.2.0  1.1.0        Rollback to 17              ← 当前
```

### 9.2 历史解读

````
REVISION 1-5 (v0.1.0):
  初始部署，遇到各种问题（Postgres 连接、镜像拉取超时），
  4 次失败后最终成功。每次失败都是一次真实的 debug 过程。

REVISION 6 (v0.1.1):
  第一个成功的参数调整版本。

REVISION 7-9 (v0.2.0, v0.1.1, v0.2.0):
  appVersion 从 1.0.0 升级到 1.0.1，然后又升到 1.1.0。
  可以看到 CHART 列和 APP VERSION 列都在变化。

REVISION 10-14:
  各种回滚和重试——真实世界就是这样，部署不是一帆风顺的。
  Helm 的 rollback 保证了每次失败后都能安全回到已知状态。

REVISION 15-17:
  成功部署 v0.2.0，然后做了 frontend 副本的扩缩容。
  注意 DESCRIPTION 列——--description 参数的价值在这里体现。

REVISION 19 (当前):
  回滚到 REVISION 17。
  注意：REVISION 没有 18 和 20——rev 18 是失败的 rollback 尝试
  （被清理了），rev 19 就是当前的部署状态。
````

### 9.3 常用命令速查

```bash
# ──── Release 管理 ────
helm list -n smart-invest                         # 列出所有 Release
helm status smart-invest -n smart-invest          # 查看当前状态
helm history smart-invest -n smart-invest         # 查看历史
helm get values smart-invest -n smart-invest      # 查看所有已合并的 Values
helm get manifest smart-invest -n smart-invest    # 查看最后一次部署的完整 YAML
helm get notes smart-invest -n smart-invest       # 查看 NOTES.txt

# ──── 部署操作 ────
helm upgrade --install smart-invest ./umbrella/ --namespace smart-invest
helm rollback smart-invest 17 -n smart-invest
helm uninstall smart-invest -n smart-invest --keep-history

# ──── 调试 ────
helm lint ./umbrella/                             # 检查 Chart 语法
helm template ./umbrella/                         # 渲染模板到 stdout（不部署）
helm install --dry-run --debug smart-invest ./umbrella/
helm diff upgrade smart-invest ./umbrella/        # 需要 helm-diff 插件

# ──── 依赖管理 ────
helm dependency list ./umbrella/
helm dependency build ./umbrella/                 # 下载依赖到 charts/
helm dependency update ./umbrella/                # 强制重新下载

# ──── 包管理 ────
helm package ./umbrella/                          # 打包为 .tgz
helm push ./smart-invest-0.2.0.tgz oci://registry.example.com/charts

# ──── 仓库管理 ────
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo bitnami
```

---

> **文档版本**: v1.0
> **最后更新**: 2026-08-06
> **适用版本**: Helm 3.x
> **基于项目**: [smart-invest](https://github.com/gongchengship/smart-invest)（Spring Boot 微服务 + K3S + Helm3）
