# Kubernetes 核心原理与教学指南（Java 工程师视角）

> 写给资深 Java 工程师的 K8s 深度指南。
> 不教你「怎么敲命令」，而是教你「K8s 为什么这样设计」。
> 理解原理后，命令和排查自然就会了。
> 以 smart-invest 项目（微服务部署到 K3S）为上下文。

---

## 目录

| 章节 | 内容                                                                      |
|------|-------------------------------------------------------------------------|
| 零 | 前言：从 Java 到 K8s——类比驱动学习                                                 |
| 一 | K8s 解决了什么问题                                                             |
| 二 | 整体架构：Master 和 Worker 的分工                                                |
| 三 | 核心工作模型：声明式 + 控制器模式                                                      |
| 四 | 控制平面组件详解（kube-apiserver / etcd(Editable Text Configuration-Distributed) / scheduler / controller-manager）      |
| 五 | 工作节点的真正常驻进程（kubelet / kube-proxy / CRI & CNI）                           |
| 六 | 核心工作负载资源（Pod / Deployment / ReplicaSet / StatefulSet / DaemonSet / Job） |
| 七 | 网络与流量（Service / Ingress / CoreDNS / kube-proxy）                         |
| 八 | 配置与存储（ConfigMap / Secret / PVC / PV）                                    |
| 九 | 弹性伸缩（HPA / VPA / Cluster Autoscaler）                                    |
| 十 | 自我修复机制（Probe / ReplicaSet 自愈 / Node Controller）                         |
| 十一 | 完整调度流程：一个 Pod 的诞生                                                       |
| 十二 | K8s 生态核心工具清单                                                            |
| 附 A | 关键缩写全称速查                                                                |
| 附 B | 用你的 smart-invest 项目验证原理                                                 |

---

## 零、前言：从 Java 到 K8s——类比驱动学习

你是资深 Java 工程师，K8s 的很多概念用 Java 来类比会非常直观：

| K8s 概念 | Java 类比 | 说明 |
|-----------|-----------|------|
| **Pod** | `new Thread(runnable)` | K8s 不是按「容器」调度，而是按 Pod——最小调度单元 |
| **Deployment** | `ExecutorService` (线程池) | 保证 N 个 Pod 在线，死了自动补上 |
| **ReplicaSet** | 线程池底层的 `ThreadPoolExecutor` | Deployment 操作 ReplicaSet，ReplicaSet 操作 Pod |
| **Service** | `@Service` + Spring Cloud LoadBalancer | 给一组 Pod 提供稳定的 DNS 名和负载均衡 |
| **Ingress** | Nginx 的 `server { location /api { proxy_pass }}` | 外部流量的统一入口 |
| **ConfigMap** | `application.yml` | 环境变量和配置文件 |
| **Secret** | Spring Cloud Config 的加密配置 | 密码、Token 等敏感信息 |
| **HPA** | 线程池的 `setCorePoolSize()` 动态调整 | 忙时自动扩容，闲时自动缩容 |
| **etcd** | 数据库（更准确：强一致的 KV 存储） | 存放 K8s 所有期望状态的数据库 |
| **kubectl** | `curl` / JDBC Client | 操作 K8s 的命令行客户端 |

---

## 一、K8s 解决了什么问题

### 1.1 从 Google 内部说起

K8s 的作者团队来自 Google。Google 内部有一个叫 **Borg** 的系统，负责调度 Google 所有的容器——

- **搜索**
- **Gmail**
- **YouTube**
- **Google Maps**

每周能调度数十亿个容器。K8s 是 Borg 的开源重写版：

| 时间 | Google 内部                      | 开源世界 |
|------|--------------------------------|----------|
| 2003-2004 | **Borg** 诞生                    | — |
| 2014 | Google 发布 **Kubernetes** (K8s) | Docker 刚火，大家只会在单机上 `docker run` |
| 2015 | Google 把 K8s 捐给 CNCF(Cloud Native Computing Foundation)         | K8s 成为云原生基金会第一个项目 |
| 2016-至今 | Google 内部依然用 Borg              | K8s 成为了**容器编排的事实标准** |

### 1.2 没有 K8s 的世界：你只能手动操作

假设你的 smart-invest 项目有 7 个微服务，没有 K8s 时你怎么部署？

```bash
# 服务器 A（192.168.31.192）上
docker run -d --name user-service -p 8081:8081 gongchengship/smart-invest-user-service:v1
docker run -d --name fund-service -p 8082:8082 gongchengship/smart-invest-fund-service:v1
docker run -d --name order-service -p 8083:8083 gongchengship/smart-invest-order-service:v1
# ... 还有 4 个

# 然后 user-service 挂了怎么办？手动重启
docker restart user-service

# 流量上来了，一个 Pod 不够？手动扩容
# 只能再搞一台服务器 B，手动 docker run...

# 想灰度发布？手动改 Nginx 的 upstream weight...
```

### 1.3 K8s 帮你自动做了四件事

| 问题 | 没有 K8s | 有了 K8s |
|------|----------|----------|
| **部署** | 手写 `docker run` 脚本，每台服务器手动执行 | 提交一个 Deployment YAML，K8s 自动调度到合适节点 |
| **自愈** | 容器挂了？人工 `docker restart` | ReplicaSet 控制器自动重建 Pod |
| **弹性伸缩** | 手算 `docker ps | wc -l`，人工加机器 | HPA 自动看 CPU/Memory/QPS，自动增减 Pod |
| **服务发现** | 记 IP 地址、改 `/etc/hosts` | Service 自动分配 DNS（如 `user-service.smart-invest.svc.cluster.local`） |

**K8s 的本质是什么？**

```
K8s = 一个集群级别的操作系统

你（用户）：「我要 3 个 user-service 的实例，每个用 512M 内存，1 个 CPU」
K8s（OS）： 「明白。我现在找三台有空闲资源的机器，在上面启动容器。
            如果有一个挂了，我自动再启动一个补上。
            如果流量太大 CPU 到 70%，我再给你多启动几个。」

你不用关心 Pod 最终落在哪台机器——就像你写 Java 时不用关心线程落在哪个 CPU 核上。
```

---

## 二、整体架构：Master 和 Worker 的分工

### 2.1 两大角色

```
┌──────────────────────────────────────────────────────────────┐
│                      Control Plane (Master / 控制平面)        │
│  ┌──────────────┐  ┌──────────────────┐  ┌────────────────┐  │
│  │ kube-apiserver│  │ controller-manager│  │   scheduler     │  │
│  │ (唯一的入口)   │  │ (控制器管理器)    │  │ (调度器)        │  │
│  └──────┬───────┘  └────────┬─────────┘  └───────┬────────┘  │
│         └───────────────────┼────────────────────┘           │
│                             ↓                                │
│                     ┌───────────────┐                        │
│                     │     etcd       │                        │
│                     │ (K8s 的数据库)  │                        │
│                     └───────────────┘                        │
└──────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ↓                   ↓                   ↓
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│   Worker Node 1  │ │   Worker Node 2  │ │   Worker Node 3  │
│ ┌──────────────┐ │ │ ┌──────────────┐ │ │ ┌──────────────┐ │
│ │   kubelet    │ │ │ │   kubelet    │ │ │ │   kubelet    │ │
│ │ (节点代理)    │ │ │ │ (节点代理)    │ │ │ │ (节点代理)    │ │
│ ├──────────────┤ │ │ ├──────────────┤ │ │ ├──────────────┤ │
│ │ kube-proxy   │ │ │ │ kube-proxy   │ │ │ │ kube-proxy   │ │
│ │ (网络代理)    │ │ │ │ (网络代理)    │ │ │ │ (网络代理)    │ │
│ ├──────────────┤ │ │ ├──────────────┤ │ │ ├──────────────┤ │
│ │ Pod A Pod B  │ │ │ │ Pod C Pod D  │ │ │ │ Pod E Pod F  │ │
│ └──────────────┘ │ │ └──────────────┘ │ │ └──────────────┘ │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

| 角色 | 英文 | 核心组件 | 干什么 | 类比 |
|------|------|----------|--------|------|
| **Master** | Control Plane | apiserver, etcd, scheduler, controller-manager | 管理集群的大脑：接受请求、存储状态、做决策 | Spring Boot 的 Controller + Service + DB |
| **Worker** | Data Plane | kubelet, kube-proxy, Container Runtime | 干活的肌肉：运行 Pod、转发网络流量 | Spring Boot 的 `@Async` 线程池 |

**你的 K3S 项目实际体验：** K3S 把 Master 和 Worker 都装在**同一台** ASUS-Ubuntu 上。生产环境通常是 3 个 Master（高可用）+ N 个 Worker。

---

## 三、核心工作模型：声明式 + 控制器模式

### 3.1 这是学习 K8s 最重要的一节

K8s 最核心的思想只有一句话：

> **你只需要告诉 K8s 你想要什么（Desired State），K8s 负责把它变成现实（Current State），并持续确保两者一致。**

这和写 Spring Boot `application.yml` 是一样的：

```yaml
# 你不需要写代码去"创建数据库连接池、创建 50 个连接"
# 你只需要声明：
spring:
  datasource:
    hikari:
      maximum-pool-size: 50    # ← 这是 Desired State
```

K8s 的做法如出一辙：

```yaml
# 你不需要写脚本去 "docker run 3 个容器，挂了重启"
# 你只需要声明：
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3                   # ← Desired State：我要 3 个 Pod
```

### 3.2 控制器模式（Controller Pattern）——谁在干活？

声明容易，但**谁**来把声明变成现实？这就是**控制器（Controller）**。

**每个 K8s 资源背后都有一个 Controller 在无限循环：**

```go
// K8s 控制器伪代码（实际用 Go 写的）
// 每个 Controller 内部都是一个无限循环
for {
    desiredState  := getDesiredStateFromEtcd()     // 用户提交的 YAML（期望状态）
    currentState  := observeCurrentState()          // 集群中实际在跑的东西（当前状态）

    if desiredState != currentState {
        takeAction()                                // 调整：创建/删除/修改资源
    }
    sleep(controlLoopInterval)
}
```

这个模式叫 **Reconciliation Loop（协调循环）** 或 **Control Loop（控制循环）**。

### 3.3 回答你问的核心问题：到底谁在「监听」？

你和朋友面试时反复问的「谁在监听 Pod 数量」「谁在监听 Container workload」，现在给你精确答案：

| 你观察到的现象 | 哪个 Controller 在负责 | 它监听什么 | 它做什么 |
|---------------|----------------------|-----------|----------|
| 「我改了 replicas: 3，Pod 从 1 个变成 3 个」 | **ReplicaSet Controller** | Deployment → ReplicaSet → Pod 数量 | 发现 Pod 不够→创建；多了→删除 |
| 「Pod 挂了又自动起来了」 | **ReplicaSet Controller** | Pod 的 Status.Phase | 发现 Running Pod 数 < replicas→重建 |
| 「CPU 超过 70% 自动扩容了」 | **HPA Controller** | 每 15 秒查 Metrics Server 的 Pod CPU 指标 | 计算 desiredReplicas→改 Deployment.replicas→触发 ReplicaSet Controller |
| 「新 Pod 被调度到哪台机器」 | **Scheduler**（不是 Controller，是一个独立的调度器） | unbound Pod（`.spec.nodeName` 为空的 Pod） | 通过打分算法选一台最优的 Node |
| 「ConfigMap 改了，Pod 里的文件也更新了」 | **kubelet**（不是 Controller） | 挂载到 Pod 的 ConfigMap 版本号 | 更新容器内的文件 |
| 「节点挂了，上面的 Pod 被迁移到别的节点」 | **Node Controller**（controller-manager 的一部分） | Node 的 `.status.conditions` | 发现 Node NotReady ≥ 5min → 驱逐 Pod |
| 「Service 总能找到正确的 Pod」 | **Endpoints Controller** + **kube-proxy** | Service 的 selector + Pod 的 labels + Pod Ready 状态 | 同步 Endpoints 列表 + 更新 iptables 规则 |

**关键理解：**

```
用户提交 Deployment YAML (replicas: 3)
         │
         ↓
    Deployment Controller 收到事件：「用户创建了一个 Deployment」
         │
         ↓
    Deployment Controller 创建一个 ReplicaSet
         │
         ↓
    ReplicaSet Controller 收到事件：「有一个新 ReplicaSet，spec.replicas=3」
         │
         ↓
    ReplicaSet Controller 创建 3 个 Pod（.spec.nodeName 为空）
         │
         ↓
    Scheduler 收到事件：「有 3 个 unbound Pod」
         │
         ↓
    Scheduler 给每个 Pod 分配一个Node（设置 .spec.nodeName）
         │
         ↓
    目标Node上的 kubelet 收到事件：「这个节点被分配了一个新 Pod」
         │
         ↓
    kubelet 调用 CRI（Container Runtime Interface容器运行时接口）→ containerd → runc → 启动容器
         │
         ↓
    ReplicaSet Controller 持续检查：「当前 Running 的 Pod 是否 = 3？」
         如果不是，就纠正
```

**这整个链条中没有任何一个「上帝线程」——每个 Controller 只负责自己那一段。这就是 K8s 的设计精髓：解耦 + 声明式 + 控制循环。**

---

## 四、控制平面组件详解

控制平面（Control Plane）是 K8s 的大脑，运行在 Master 节点上。

### 4.1 kube-apiserver（API Server）——唯一入口

| 属性 | 说明 |
|------|------|
| **全称** | Kubernetes Application Programming Interface Server |
| **身份** | 控制平面的**唯一入口**。所有操作都必须经过它 |
| **类比** | Spring Boot 的 `@RestController`——所有请求都走这里 |

**职责：**
1. 接收所有 REST 请求（`kubectl apply -f deployment.yaml` → HTTP POST 到 apiserver）
2. **认证（Authentication）**：你是谁？（证书 / Token / OIDC）
3. **授权（Authorization）**：你有权限做这个操作吗？（RBAC）
4. **准入控制（Admission Control）**：这个请求合规吗？（资源配额、安全策略）
5. 读写 etcd

```bash
# 你平时敲的每一句 kubectl 命令，背后都是向 apiserver 发 HTTP 请求
kubectl get pods -n smart-invest
# 等价于：
curl -k https://127.0.0.1:6443/api/v1/namespaces/smart-invest/pods
```

### 4.2 etcd(Editable Text Configuration-Distributed)（数据库）——集群的「真理之源」

| 属性 | 说明                                                                                          |
|------|---------------------------------------------------------------------------------------------|
| **全称** | `/etc` distributed。名字来自 Linux `/etc`(Editable Text Configuration) 目录（存配置）+ distributed（分布式） |
| **身份** | 分布式强一致的 Key-Value 存储。K8s 所有状态都存在这里                                                          |
| **类比** | MySQL/PostgreSQL——但 etcd 是 KV 而不是 SQL。用 Raft 协议保证强一致性                                       |

**存了什么：**
- 所有 Deployment/Service/Pod/ConfigMap……的 YAML
- 所有 Node 的状态
- 所有 RBAC 权限配置

**为什么 etcd 很重要：** etcd 挂了 = 整个集群失忆。生产环境 etcd 必须 3 节点或 5 节点（奇数，Raft 投票需要）。

### 4.3 kube-scheduler（Scheduler）——找房中介

| 属性 | 说明 |
|------|------|
| **全称** | Kubernetes Scheduler |
| **身份** | 为 Pod 选择最合适的 Node |
| **类比** | 房产中介——你告诉他「3 室 2 厅、朝南、预算 100 万」，他给你推荐最匹配的房子 |

**工作原理：两步走**

```
Step 1: Filtering（过滤 / 硬条件）
  - 把不满足条件的节点排除
  - 例如：Pod 要求 2G 内存 → 只剩 512M 内存的节点排除
  - 例如：节点被 cordon 了（不可调度）→ 排除
  - 例如：Pod 要求 GPU → 没有 GPU 的节点排除

Step 2: Scoring（打分 / 软偏好）
  - 在剩余节点中打分，选一个最优的
  - 例如：Pod 部署到资源利用率最低的节点（LeastRequestedPriority）
  - 例如：同一 Deployment 的 Pod 分散到不同节点（PodAntiAffinity）
  - 你的项目中有 PodAntiAffinity，就是让 Scheduler 在不同节点各放一个 Pod
```

### 4.4 kube-controller-manager（Controller Manager）——一群监工

| 属性 | 说明 |
|------|------|
| **全称** | Kubernetes Controller Manager |
| **身份** | 管理所有 Controller 的「总管」 |
| **类比** | `@Scheduled` 定时任务调度器——一大堆循环任务集合在一起 |

**它是一个进程，里面跑了这些 Controller：**

| Controller | 全称 | 负责什么 |
|-----------|------|---------|
| **Deployment Controller** | — | 管理 Deployment → ReplicaSet → Pod 的级联生命周期 |
| **ReplicaSet Controller** | — | 保证 Pod 的副本数等于期望值（你问的那个！） |
| **Node Controller** | — | 监控节点健康状态（心跳超时→标记 NotReady→驱逐 Pod） |
| **Job Controller** | — | 管理一次性 Job，确保跑完指定次数 |
| **Endpoints Controller** | — | 根据 Service selector → 生成 Endpoints 列表 |
| **ServiceAccount Controller** | — | 为每个 namespace 自动创建默认 ServiceAccount |
| **HPA Controller** | — | 每隔 15 秒查 Metrics，算 desiredReplicas（你问的那个！） |

**面试加分项：** cloud-controller-manager 是云厂商（AWS/Azure/GCP）提供的，负责对接云平台的 LB、磁盘、路由等。你的 SAP Kyma 环境里就有 SAP 自己的 cloud-controller-manager。

---

## 五、工作节点的真正常驻进程

每个 Worker Node 上运行着两个常驻进程。

### 5.1 kubelet ——节点上的「管家」

| 属性 | 说明 |
|------|------|
| **全称** | Kubernetes + let（小词后缀，表示「小代理」） |
| **身份** | 每个节点上唯一的代理进程。**kubelet 不是一个 Controller，而是 K8s 在节点上的执行者** |
| **类比** | AWS EC2 里的 `cloud-init` 或 systemd——负责执行来自 K8s 控制平面的指令 |

**职责：**
1. 接收 Scheduler 分配的 Pod（读 apiserver 中 `.spec.nodeName == 本节点` 的 Pod）
2. 调用 CRI（Container Runtime Interface）启动容器（→ containerd → runc → 容器进程）
3. 调用 CNI（Container Network Interface）给 Pod 分配 IP
4. 调用 CSI (Container Storage Interface）挂载 Volume
5. 执行 Liveness Probe/Readiness Probe，(存活探针/就绪探针)不健康则重启容器
6. 上报节点状态和 Pod 状态回 apiserver

### 5.2 kube-proxy ——节点上的网络规则维护者

| 属性 | 说明 |
|------|------|
| **全称** | Kubernetes Proxy |
| **身份** | 在每个节点上维护网络规则（iptables / IPVS），让 Service 的 ClusterIP 能把流量转发到具体的 Pod IP |
| **类比** | 交响乐指挥：一个请求来了，把它分配到具体的乐手（Pod） |

**工作原理：**
```
用户访问 user-service:8081
  ↓
CoreDNS 把 user-service → 10.43.120.88 (ClusterIP)
  ↓
ClusterIP 是虚拟的，不实际绑定任何网卡
  ↓
kube-proxy 在 iptables 中写规则：
  请求 10.43.120.88:8081 → 随机转发给 10.42.0.15:8081 或 10.42.0.22:8081
  ↓
目标 Pod 的容器收到请求
```

**面试要点：** kube-proxy 不实际转发流量——它只是维护 iptables/IPVS 规则，流量由 Linux 内核直接转发。

---

## 六、核心工作负载资源

### 6.1 Pod ——最小调度单元

| 属性 | 说明 |
|------|------|
| **全称** | Pod。来自英文 pod（豆荚），暗示一群容器像豆子一样在一个豆荚里共生。也可能来自「Pod of whales」（一群鲸鱼） |
| **身份** | K8s 的最小调度单元——你不直接调度容器，你调度 Pod |
| **类比** | **`Thread`**——操作系统调度的最小单位不是代码行而是线程；K8s 调度的最小单位不是容器而是 Pod |

**Pod 内多个容器的关系：**
```
┌──────────────────────────────┐
│           Pod                │
│  ┌──────────┐ ┌───────────┐ │
│  │ App      │ │ Istio     │ │  ← Sidecar（边车模式）
│  │ Container │ │ Sidecar   │ │     两个容器共享：
│  │ :8080    │ │ :15001    │ │     - 同一个 IP（共享网络 namespace）
│  └──────────┘ └───────────┘ │     - 同一个 localhost（共享 loopback）
│      ↕ shared volume          │     - 同一个 Volume
│  ┌──────────────────────────┐ │
│  │      EmptyDir Volume      │ │
│  └──────────────────────────┘ │
└──────────────────────────────┘
```

**你的 smart-invest 项目中的实际情况：**
- user-service 的 Pod 目前只有 1 个容器（Java 应用）
- 如果接入 Istio，每个 Pod 里会多一个 **istio-proxy sidecar**，负责流量拦截和加密

### 6.2 Deployment ——无状态应用的「管家」

| 属性 | 说明 |
|------|------|
| **全称** | Deployment（部署） |
| **身份** | 管理 ReplicaSet，支持滚动更新、回滚 |
| **类比** | **`ExecutorService`**（Java 线程池）——你告诉线程池「最少保持 N 个线程」，它负责维持 |

```yaml
# 你的 smart-invest 项目中 user-service 的实际 Deployment
# （教学简化版：把 Helm 模板变量都替换成了具体值，方便初学理解）
# 仓库里的真实模板见下文 6.2.1 对照块
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  labels:                                    # ① 这个 labels 只属于 Deployment 自己
    app: user-service                        #    是给 Deployment 对象本身打标签
spec:
  replicas: 3                               # 期望 3 个 Pod
  selector:                                  # ② 这个 selector 管的是 Deployment 要管哪些 Pod
    matchLabels:
      app.kubernetes.io/name: user-service
  template:                                  # ③ Pod 模板（跟 Java 泛型模板一个概念）
    metadata:
      labels:                                # ④ 这里的 labels 才会盖到 Pod 上！源头在这
        app.kubernetes.io/name: user-service
    spec:
      containers:
      - name: user-service
        image: gongchengship/smart-invest-user-service:v1
        ports:
        - containerPort: 8081
```

> [!NOTE] 教学版 vs 真实代码
> 上面是**教学简化版**（把 `{{ .Values.xxx }}` 都换成了具体值）。仓库里真正的模板是 **Helm Chart**，路径：
> `infrastructure/helm-charts/charts/user-service/templates/deployment.yaml`
> 结构完全一致，只是值来自 `values.yaml`。下面 6.2.1 给出真实模板骨架，方便对照「文档教的是同一份东西」。

### 6.2.1 真实 Helm 模板对照（以 user-service 为例）

```yaml
# infrastructure/helm-charts/charts/user-service/templates/deployment.yaml
# 教学版里的「具体值」在真实代码中都是 {{ .Values.xxx }} 模板变量
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "svc.fullname" . }}        # = 教学版里的 user-service
  labels:
    {{- include "svc.labels" . | nindent 4 }}  # ① 这里给 Deployment 本身打标签
spec:
  replicas: {{ .Values.replicaCount }}        # = 教学版里的 3
  selector:                                    # ② Deployment 要管哪些 Pod
    matchLabels:
      app.kubernetes.io/name: {{ include "svc.name" . }}
  template:                                    # ③ Pod 模板
    metadata:
      labels:
        {{- include "svc.labels" . | nindent 8 }}  # ④ 这里的 labels 才会盖到 Pod 上！
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      # 把 postgres-host 映射到宿主机 IP（K3S 里访问宿主机 Docker 的 Postgres）
      hostAliases:
        - ip: "192.168.31.192"
          hostnames:
            - "postgres-host"
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.port }}
          # 非敏感环境变量从 values.env 读（部署时合并）
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
            # 敏感环境变量从 K8S Secret 注入（值存在集群里，不写进代码）
            {{- range .Values.secretEnvRefs }}
            - name: {{ . }}
              valueFrom:
                secretKeyRef:
                  name: smart-invest-secrets
                  key: {{ . }}
            {{- end }}
          # 资源限制：requests 是「保证」，limits 是「上限」
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          # 就绪探针：就绪前不接流量（滚动更新时保证新旧交替不中断）
          readinessProbe:
            httpGet:
              path: {{ .Values.readinessProbe.path }}
              port: {{ .Values.readinessProbe.port }}
            initialDelaySeconds: 30
            periodSeconds: 10
          # 存活探针：探测失败 → K8S 杀掉重启（自愈）
          livenessProbe:
            httpGet:
              path: {{ .Values.livenessProbe.path }}
              port: {{ .Values.livenessProbe.port }}
            initialDelaySeconds: 300
            periodSeconds: 15
```

> [!NOTE] 关键对照点
> - **教学版的 `user-service`** = 模板里的 `{{ include "svc.fullname" . }}`（由 Chart name + release 拼接）
> - **教学版的 `replicas: 3`** = `{{ .Values.replicaCount }}`（在 `values.yaml` 里配置）
> - **教学版的 `app.kubernetes.io/name`** 两处 labels（①②④）在真实模板里都来自 `svc.labels` 这个公共 helper——所以 Service 的 selector 只要也用同一个 helper，两边必然一致，天然不会写错
> - **教学版没画全的**（env / resources / probe）：真实模板还有环境变量注入、资源限制、就绪/存活探针

**Deployment 的滚动更新（Rolling Update）：**
```
改造前：3 个旧版本 Pod
[Pod v1] [Pod v1] [Pod v1]

改造中：先起 1 个新版本，等它 Ready → 杀 1 个旧版本 → 循环
[Pod v2] [Pod v1] [Pod v1]
[Pod v2] [Pod v2] [Pod v1]
[Pod v2] [Pod v2] [Pod v2]

改造后：3 个新版本 Pod
```

**面试核心：** Deployment 本身不直接管 Pod——它管 ReplicaSet，ReplicaSet 管 Pod。每滚动更新一次，创建一个新 ReplicaSet。这就是为什么 `kubectl rollout undo` 能回滚——它切回了旧 ReplicaSet。

### 6.3 ReplicaSet ——Pod 数量的直接管理者

| 属性 | 说明 |
|------|------|
| **全称** | Replica Set（副本集） |
| **身份** | 直接保证「当前 Pod 数量 == 期望数量」的控制器 |
| **你一般不会直接操作它**——它是 Deployment 的下属。但面试一定要知道它的存在 |

```
Deployment
    │
    ├── ReplicaSet v1 (revision 1)  → [Pod-A] [Pod-B] [Pod-C]
    │
    └── ReplicaSet v2 (revision 2)  → [Pod-D] [Pod-E] [Pod-F]     ← 滚动更新中
```

### 6.4 StatefulSet ——有状态应用

| 属性 | 说明 |
|------|------|
| **全称** | Stateful Set（有状态集合） |
| **身份** | 为需要持久化身份的应用提供管理 |
| **和 Deployment 的核心区别** | Deployment 的 Pod 是「无名的」（随机后缀如 `xxx-7fd4c8b`），StatefulSet 的 Pod 有固定的序号 `xxx-0, xxx-1, xxx-2` |

**适用场景：** 数据库（PostgreSQL、MySQL）、消息队列（Kafka、RabbitMQ）、缓存集群（Redis Cluster）。

### 6.5 DaemonSet ——每节点一个守护 Pod

| 属性 | 说明 |
|------|------|
| **全称** | Daemon Set（守护进程集） |
| **身份** | 保证每个（符合条件的）节点上运行一个 Pod 副本 |
| **典型用途** | kube-proxy、日志采集 Fluentd、监控 Node Exporter、CNI 网络插件（Calico/Flannel） |

```
节点 A: [Daemon Pod] [普通 Pod] [普通 Pod]
节点 B: [Daemon Pod] [普通 Pod]
节点 C: [Daemon Pod] [普通 Pod] [普通 Pod]
# 每个节点自动有一个 Daemon Pod
```

### 6.6 Job 与 CronJob ——一次性/定时任务

| 属性 | 说明 |
|------|------|
| **全称** | Job / Cron Job（定时任务） |
| **身份** | 跑完就退出，不会一直运行 |
| **类比** | Quartz Scheduler / Spring `@Scheduled` |

```yaml
# Job：数据库迁移，跑一次
apiVersion: batch/v1
kind: Job
spec:
  completions: 1
  template:
    spec:
      containers:
      - name: db-migration
        image: liquibase-migration:v2
      restartPolicy: Never
---
# CronJob：每天凌晨 3 点跑数据清理
apiVersion: batch/v1
kind: CronJob
spec:
  schedule: "0 3 * * *"         # cron 表达式
  jobTemplate: ...
```

---

## 七、网络与流量

### 7.1 Service ——给 Pod 发个「固定门牌号」

**核心问题：** Pod 的 IP 是临时的——Pod 重建后 IP 就变了。那 order-service 怎么找到 user-service？

**解决：** Service 提供了一个**不变的 ClusterIP + DNS 名**。

```
                   user-service (ClusterIP: 10.43.120.88)
                          │
                 ┌────────┼────────┐
                 ↓        ↓        ↓
           Pod-A:10.42.0.15   Pod-B:10.42.0.22   Pod-C:10.42.0.33
           (Ready)            (Ready)            (Not Ready → 不接收流量)
```

**Service 类型：**

| 类型 | 全称 | 访问范围 | 使用场景 |
|------|------|----------|----------|
| **ClusterIP** | — | 仅集群内部 | 微服务间互调（默认类型） |
| **NodePort** | — | 节点 IP:30000-32767 | 开发环境简单暴露 |
| **LoadBalancer** | — | 云厂商分配公网 LB | 生产环境对外暴露 |
| **ExternalName** | — | DNS 别名 | 把外部服务映射进集群内部 |

```yaml
# 你的 user-service 的实际 Service
apiVersion: v1
kind: Service
metadata:
  name: user-service
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: user-service    # 选哪些 Pod
  ports:
  - port: 8081                               # Service 自己的端口
    targetPort: 8081                         # Pod 上容器的端口
    protocol: TCP
```
> [!CAUTION]
> **Service 是通过 selector 匹配 Pod 的 labels 来找到后端的。**
> 这就是为什么 `kubectl get endpoints` 为空时说明 labels 没对上或 Pod 不 Ready。所以当 `kubectl get endpoints` 为空,优先检查 labels 是否匹配、Pod 是否 Running & Ready。

> [!WARNING] 更详细地说: Service 找后端的方式：label 匹配，不是名字匹配
>
> **Service 是通过 `spec.selector` 匹配 Pod 的 labels 来找到后端的。**
> 而 Pod 的 labels 根源，在 Deployment 的 **`spec.template.metadata.labels`**（不是顶层的 `metadata.labels`）。
> 当 `kubectl get endpoints` 为空时，依次排查：① Service 的 selector 和 Deployment 的 Pod 模板 labels 是否一致；② Pod 是否处于 Running & Ready。

**① 为什么用 selector 匹配，而不直接写 Pod 名字/IP？** —— Pod 的 IP 和名字每次重建都会变，只有 label 是稳定的。所以 Service 只认 label，不认 IP；label 匹配上的 Pod，IP 才会被写进 Endpoints。

**② Pod 的 labels 根源到底在哪？** —— 在 Deployment 的 `spec.template.metadata.labels`，不是顶层的 `metadata.labels`。注意别混淆这两处：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  labels:                                    # ① 这个 labels 只属于 Deployment 自己
    app: user-service                        #    是给 Deployment 对象本身打标签
spec:
  selector:                                  # ② 这个 selector 管的是 Deployment 要管哪些 Pod
    matchLabels:
      app: user-service
  template:                                  # ③ Pod 模板，真正生成 Pod 的地方
    metadata:
      labels:                                # ④ 这里的 labels 才会盖到 Pod 上！源头在这
        app: user-service
        app.kubernetes.io/name: user-service
    spec:
      containers:
      - name: user-service
        image: ...
```

所以排查口诀是：**Service 的 selector 要匹配的，是 Deployment 的 `spec.template.metadata.labels`，而不是 `metadata.labels`。**

**③ `app.kubernetes.io/name` 是什么？** —— 它是 K8s 官方的 **Recommended Labels（推荐标签）** 约定。`app.kubernetes.io` 是前缀，表示这个 key 是 Kubernetes 社区规范定义的；`name` 表示应用的名字。它不是必须的——只要 Service.selector 和 Pod 模板 labels 两边 key-value 一致就能匹配，用 `app: user-service` 这种朴素写法也行。推荐标签的价值在于：Helm、Prometheus、Kustomize 等工具都认得这套标准 key，打了一致的标签，整套工具链才能自动把「这是哪个应用、哪个实例、哪个组件」关联起来。

**④ 从 Deployment 到 Endpoints 的完整链路：**

```
Deployment.spec.template.metadata.labels     ← 源头：Pod 的标签在这定义
        ↓ K8s 创建 Pod 时盖上
Pod.metadata.labels                          ← Pod 带着这些标签
        ↓ 控制面比对
Service.spec.selector                        ← 匹配条件，决定后端是哪些 Pod
        ↓ 匹配成功
Endpoints 里出现这些 Pod 的 IP               ← kubectl get endpoints 能看到
```

### 7.2 CoreDNS ——集群内的 DNS 服务

| 属性 | 说明 |
|------|------|
| **全称** | Core Domain Name System |
| **身份** | 集群内 DNS 服务。替代了旧版的 kube-dns |
| **类比** | AWS Route53 私有托管区——集群内的 DNS |

```bash
# order-service 访问 user-service，不需要知道 IP
curl http://user-service:8081/api/users

# 实际被 CoreDNS 解析为：
curl http://user-service.smart-invest.svc.cluster.local:8081/api/users
# 格式：<service-name>.<namespace>.svc.cluster.local
```

### 7.3 Ingress ——外部流量的统一入口

| 属性 | 说明 |
|------|------|
| **全称** | Ingress（入口） |
| **身份** | 将外部 HTTP/HTTPS 请求按域名和路径路由到内部 Service |
| **类比** | Nginx 的 `server { location / {} }` 配置 |

```yaml
# 你的 smart-invest 项目中的 Ingress
spec:
  rules:
  - http:
      paths:
      - path: /           # 前端 React 页面
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
      - path: /api        # API 请求
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 8080
```

**背后需要一个 Ingress Controller 来实际执行路由：** Nginx Ingress Controller、Traefik（你的 K3S 环境默认带的就是 Traefik）、Kong、Istio Gateway。

---

## 八、配置与存储

### 8.1 ConfigMap ——非敏感配置

| 属性 | 说明 |
|------|------|
| **全称** | Configuration Map（配置映射） |
| **身份** | 存放 key-value 配置的 K8s 资源 |
| **类比** | Spring Boot 的 `application.yml` |

```yaml
# 你的项目中的配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-service-config
data:
  SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-host:5432/smartinvest
  RABBITMQ_HOST: rabbitmq
  RABBITMQ_PORT: "5672"
```

### 8.2 Secret ——敏感配置

| 属性 | 说明 |
|------|------|
| **全称** | Secret（密钥） |
| **身份** | 存放密码、Token 等敏感信息 |
| **和 ConfigMap 的区别** | Secret 的数据用 base64 编码存储，支持加密选项，可以挂载为 tmpfs（内存文件系统） |

```yaml
# 你的 smart-invest-secrets
apiVersion: v1
kind: Secret
metadata:
  name: smart-invest-secrets
type: Opaque
data:
  SPRING_DATASOURCE_PASSWORD: bG9jYWxkZXYtb25seQ==   # echo -n 'localdev_only' | base64
  JWT_SECRET: c21hcnRpbnZlc3Qt...
```

**面试要点：** base64 不是加密！生产环境中 Secret 应配合：
- **SealedSecret**：加密后可以安全存入 Git
- **ExternalSecret**：从 Vault / AWS Secrets Manager 同步到 K8s
- **HashiCorp Vault Sidecar Injector**：运行时注入，不存进 K8s

### 8.3 PV（PersistentVolume）与 PVC（PersistentVolumeClaim）

```
PV  = 管理员预配的存储资源（「仓库里有 100G 磁盘」）
PVC = 用户申请的存储请求（「我要 5G」）

类比 Java：
  PV  = DataSource 连接池（实际的资源）
  PVC = DataSource.getConnection()（申请资源）
```

---

## 九、弹性伸缩（HPA / VPA / Cluster Autoscaler）

### 9.1 HPA（Horizontal Pod Autoscaler）——水平 Pod 扩缩容

| 属性 | 说明 |
|------|------|
| **全称** | Horizontal Pod Autoscaler |
| **做什么** | 根据 CPU/Memory/自定义指标自动调整 Deployment 的 replicas |
| **公式** | `desiredReplicas = ceil(currentReplicas × currentMetricValue / desiredMetricValue)` |

**工作流程：**
```
每 15 秒：
  HPA Controller → 向 Metrics Server 查询 Pod 的 CPU 使用率
                → 计算 desiredReplicas
                → 如果不等于 currentReplicas
                → 修改 Deployment.spec.replicas
                → ReplicaSet Controller 检测到 replicas 变了
                → 增/删 Pod
```

### 9.2 VPA（Vertical Pod Autoscaler）——垂直 Pod 扩缩容

| 属性 | 说明 |
|------|------|
| **全称** | Vertical Pod Autoscaler |
| **做什么** | 自动调整 Pod 的 CPU/Memory requests/limits |
| **和 HPA 的区别** | HPA = 加更多 Pod（横向）；VPA = 给 Pod 加更多资源（纵向） |

### 9.3 Cluster Autoscaler ——节点级伸缩

| 属性 | 说明 |
|------|------|
| **全称** | Cluster Autoscaler |
| **做什么** | Pod 因资源不足无法调度时，自动向云厂商申请新节点 |

```
Pod 排队等调度（没有节点有足够资源）
    ↓
Cluster Autoscaler 检测到 unschedulable Pod
    ↓
调用 AWS API → 扩容 Auto Scaling Group → 新 EC2 加入集群
    ↓
Scheduler 把 Pod 调度到新节点
```

---

## 十、自我修复机制

### 10.1 Liveness Probe（存活探针）与 Readiness Probe（就绪探针）

**谁在执行？** → **kubelet**（不是 Controller！）

```
Readiness Probe 失败 → kubelet 把 Pod 从 Service Endpoints 移除（不接流量）
Liveness Probe 失败  → kubelet 杀掉容器并重建（kubelet 调 CRI → containerd → runc）
```

### 10.2 ReplicaSet 自愈

**谁在执行？** → **ReplicaSet Controller**

```
ReplicaSet Controller 每 1 秒检查：
  「当前 Running Pod 数量 == spec.replicas？」
  不等 → 创建/删除 Pod 直到相等
```

### 10.3 Node Controller 节点故障驱逐

**谁在执行？** → **Node Controller**（controller-manager 的一部分）

```
Node 停止上报心跳
    ↓ 40 秒后
Node 被标记为 NotReady
    ↓ 5 分钟后（pod-eviction-timeout）
Node Controller 驱逐该节点上的所有 Pod
    ↓
Deployment Controller 创建新 Pod（在原节点？不！新 Pod 被 Scheduler 分配到其他健康节点）
```

---

## 十一、完整调度流程：一个 Pod 的诞生

这是你面试需要能完整描述的场景：

```bash
kubectl apply -f deployment.yaml
```

```
1. kubectl → 将 YAML 编码为 JSON → HTTP POST 到 kube-apiserver

2. kube-apiserver:
   ├── 认证（Authentication）：你有合法证书/Token 吗？
   ├── 授权（Authorization）：你的 RBAC 角色允许这个操作吗？
   ├── 准入（Admission）：通过 Mutating/Validating Webhook（如 Istio sidecar 注入）
   └── 存入 etcd

3. Deployment Controller（in controller-manager）:
   「收到事件：namespace=smart-invest 里创建了一个 Deployment」
   → 创建 ReplicaSet 对象，存入 etcd

4. ReplicaSet Controller（in controller-manager）:
   「收到事件：有一个新 ReplicaSet，replicas=3」
   → 创建 3 个 Pod 对象（此时 .spec.nodeName 为空），存入 etcd

5. Scheduler:
   「收到事件：有 3 个 unbound Pod（.spec.nodeName 为空）」
   → 对每个 Pod 执行 Filtering + Scoring
   → 选一个最优节点
   → 设置 Pod 的 .spec.nodeName = "node-2"
   → 更新 etcd

6. kubelet（on node-2）:
   「收到事件：我（node-2）被分配了一个 Pod」
   → 调用 CRI（Container Runtime Interface）→ containerd → runc
   → 创建 Linux Namespace（PID/NET/MNT...）
   → 设置 Cgroups（CPU/Memory limits）
   → 从 Registry 拉镜像
   → 在 UnionFS 只读层之上创建可写层
   → 启动容器进程：java -jar app.jar

7. kubelet:
   → 调用 CNI（Container Network Interface）给 Pod 分配 IP
   → 执行 Readiness Probe → 通过后设置 Pod Ready
   → 上报 Pod Status 到 apiserver

8. Endpoints Controller（in controller-manager）:
   「收到事件：Pod 变成 Ready 了」
   → 更新 Service 的 Endpoints 列表：把新 Pod 的 IP 加进去

9. kube-proxy（on each node）:
   「收到事件：Endpoints 列表变了」
   → 更新 iptables 规则：新 Pod IP 加入负载均衡池

10. 请求来了 → Service ClusterIP → iptables 转发到 Pod IP → 容器收到请求
```

**面试时你只需要记住核心逻辑链条：**
```
Deployment → ReplicaSet → Pod（unbound）→ Scheduler 分配节点 → kubelet 启动容器 → kube-proxy 更新网络规则
```

---

## 十二、K8s 生态核心工具清单

### 必备工具

| 工具 | 全称 | 作用 | 类比 |
|------|------|------|------|
| **kubectl** | Kubernetes Control | K8s 的命令行控制工具。`kube` + `ctl`(control) | `docker` 命令 |
| **kubeadm** | Kubernetes Admin | 初始化和管理 K8s 集群的工具 | `terraform init` |
| **k3s** | — | 轻量级 K8s 发行版（你的项目用的），名字是「K8s 砍一半」的意思 | Minikube 的竞品 |
| **Helm** | — | K8s 的包管理器。名字来自航海术语「舵」 | `apt` / `brew` |

### 容器运行时

| 工具 | 全称 | 作用 |
|------|------|------|
| **containerd** | Container Daemon | 替代 dockerd 的容器运行时。K8s 1.24+ 不再默认支持 Docker |
| **CRI-O** | Container Runtime Interface - OCI | 另一个轻量容器运行时（Red Hat 主导） |
| **runc** | Run Container | 底层真正创建容器的工具（OCI 标准实现） |

### 网络（CNI）

| 工具 | 全称 | 作用 |
|------|------|------|
| **CNI** | Container Network Interface | 容器网络标准接口（不是具体工具，是规范） |
| **Flannel** | — | 简单好用的 CNI 插件（K3S 默认） |
| **Calico** | — | 功能更丰富的 CNI 插件（支持 NetworkPolicy） |
| **Cilium** | — | 基于 eBPF 的高性能 CNI 插件（大厂首选） |

### 服务网格（Service Mesh）

| 工具 | 全称 | 作用 |
|------|------|------|
| **Istio** | — | 服务网格，管理微服务间流量、安全、可观测性。你朋友的 SAP 项目中就在用 |
| **Envoy** | — | Istio 的 sidecar 代理（Lyft 开源） |

### 可观测性

| 工具 | 全称 | 作用 |
|------|------|------|
| **Prometheus** | — | Metrics 采集和存储（希腊神话「先见之明」，比宙斯更早的神） |
| **Grafana** | — | 数据可视化。名字来自「Graph + -ana」 |
| **Jaeger** | — | 分布式 Tracing。德文「猎人」 |
| **ELK Stack** | Elasticsearch + Logstash + Kibana | 日志收集、存储、可视化 |

### GitOps

| 工具 | 全称 | 作用 |
|------|------|------|
| **ArgoCD** | Argo + CD (Continuous Delivery)。Argo 是希腊神话中的船名 | Git → K8s 自动同步。Pull 模式 GitOps |
| **Flux** | — | 另一个 GitOps 工具，也是 Pull 模式 |

### CI/CD

| 工具 | 全称 | 作用 |
|------|------|------|
| **Jenkins** | — | CI/CD 鼻祖级工具 |
| **Tekton** | — | K8s 原生的 CI/CD 框架 |
| **GitHub Actions** | — | GitHub 内置 CI/CD（你的项目 CI 用的这个） |
| **Azure DevOps** | — | 微软 CI/CD 平台（你朋友的 SAP 项目用的） |

---

## 附 A：关键缩写全称速查 / Key Abbreviation Glossary

| 缩写 | 全称 | 中文 | 一句话解释 |
|------|------|------|-----------|
| **K8s** | Kubernete**s**（8 代表中间省略了 8 个字母） | Kubernetes | 容器编排平台 |
| **API** | Application Programming Interface | 应用程序接口 | — |
| **etcd** | `/etc` distributed | 分布式 etc | K8s 的 KV 数据库 |
| **YAML** | YAML Ain't Markup Language | — | 配置文件格式 |
| **CRD** | Custom Resource Definition | 自定义资源定义 | 让 K8s 认识新的资源类型 |
| **CRI** | Container Runtime Interface | 容器运行时接口 | K8s ↔ containerd/runc 的协议 |
| **CNI** | Container Network Interface | 容器网络接口 | K8s ↔ 网络插件（Calico/Flannel）的协议 |
| **CSI** | Container Storage Interface | 容器存储接口 | K8s ↔ 存储插件（EBS/NFS）的协议 |
| **OCI** | Open Container Initiative | 开放容器标准 | 定义镜像格式和容器运行标准 |
| **RBAC** | Role-Based Access Control | 基于角色的访问控制 | 谁能做什么操作 |
| **HPA** | Horizontal Pod Autoscaler | 水平 Pod 自动扩缩容 | 增减 Pod 数量 |
| **VPA** | Vertical Pod Autoscaler | 垂直 Pod 自动扩缩容 | 增减 Pod 的 CPU/内存 |
| **PDB** | Pod Disruption Budget | Pod 中断预算 | 最少保持几个 Pod 在线 |
| **QoS** | Quality of Service | 服务质量 | Pod 的资源保证级别（Guaranteed/Burstable/BestEffort） |
| **PVC** | Persistent Volume Claim | 持久卷声明 | 用户申请存储的请求 |
| **PV** | Persistent Volume | 持久卷 | 管理员预配的存储资源 |
| **SC** | Storage Class | 存储类 | 动态创建 PV 的模板 |
| **SA** | Service Account | 服务账号 | Pod 在集群内的身份 |
| **SVC** / **svc** | Service（缩写） | 服务 | — |
| **NS** / **ns** | Namespace（缩写） | 命名空间 | 资源的隔离分组 |
| **LB** | Load Balancer | 负载均衡器 | — |
| **TLS** | Transport Layer Security | 传输层安全 | 加密通信 |
| **mTLS** | Mutual TLS | 双向 TLS | 客户端和服务端互相验证证书（Istio 默认开启） |
| **SLA** | Service Level Agreement | 服务等级协议 | 承诺的可用性（如 99.9%） |
| **SLO** | Service Level Objective | 服务等级目标 | 内部目标（如错误率 < 0.1%） |
| **SLI** | Service Level Indicator | 服务等级指标 | 实际测量出来的值 |
| **MTTD** | Mean Time To Detect | 平均检测时间 | 多久发现故障 |
| **MTTR** | Mean Time To Recover | 平均恢复时间 | 多久修复故障 |
| **HA** | High Availability | 高可用 | 多副本、自动故障转移 |
| **DR** | Disaster Recovery | 灾难恢复 | 异地多活、跨区域备份 |
| **IaC** | Infrastructure as Code | 基础设施即代码 | Terraform/Ansible 做的事 |
| **GitOps** | Git + Operations | Git 运维 | Git 是唯一事实来源 |
| **CI** | Continuous Integration | 持续集成 | 代码提交 → 自动构建 + 测试 |
| **CD** | Continuous Delivery (or Deployment) | 持续交付/部署 | 构建产物自动部署 |
| **CAP** | Consistency, Availability, Partition tolerance | CAP 定理 | 分布式系统最多满足三者中的两个 |
| **SAP** | Systeme, Anwendungen, Produkte (德文) | — | SAP 公司的 ERP 系统 |

---

## 附 B：用你的 smart-invest 项目验证原理

现在你可以用你已经部署的 K3S 环境验证上面的原理。

```bash
# SSH 到你的 ASUS 服务器
ssh george@192.168.31.192
sudo -i
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# === 看 Master 组件（K3S 打包成了一个 k3s 进程） ===
ps aux | grep k3s
# 这一个 k3s 进程里包含了 apiserver / etcd / scheduler / controller-manager

# === 看 Worker 组件 ===
# kubelet 是独立的
ps aux | grep kubelet

# kube-proxy 也是
ps aux | grep kube-proxy

# === 看 Deployment → ReplicaSet → Pod 链条 ===
kubectl get deployment -n smart-invest
kubectl get replicaset -n smart-invest       # 你会发现名字里带 deployment 名 + hash
kubectl get pods -n smart-invest -o wide     # 看看 Pod 的 labels

# === 验证 Deployment → ReplicaSet → Pod 的级联关系 ===
kubectl describe deployment user-service -n smart-invest | grep -A5 "ReplicaSets"
# 输出类似：ReplicaSets: user-service-7d4f8c9b6...

# === 看 Service + Endpoints ===
kubectl get svc -n smart-invest
kubectl get endpoints -n smart-invest        # 如果 <none>，说明 Pod 不 Ready

# === 验证 Service selector → Pod labels ===
kubectl get svc user-service -n smart-invest -o jsonpath='{.spec.selector}'
kubectl get pods -n smart-invest -l app.kubernetes.io/name=user-service

# === 看 Container 资源限制（对应 Cgroups） ===
kubectl get pods -n smart-invest -o jsonpath='{.items[0].spec.containers[0].resources}'

# === 验证 Liveness/Readiness Probe ===
kubectl describe pod -n smart-invest -l app.kubernetes.io/name=user-service | grep -A3 "Liveness\|Readiness"

# === 验证 Helm 管理了什么 ===
helm list -n smart-invest
helm get manifest smart-invest -n smart-invest | head -50
```

---

> **学习建议：**
> 1. 先理解第零~三章（声明式 + 控制器模式），这是 K8s 的「道」。后面的章节是「术」。
> 2. 用附 B 的验证命令在你的 K3S 环境上实际跑一遍，把理论和现实对上。
> 3. 面试时被问到 K8s 原理，从「用户提交 YAML → apiserver 写 etcd → Controller 检测差异 → 执行操作」这个链条讲起，考官会觉得你是真正理解 K8s 而不是只会背命令。
> 4. 作为 Java 工程师，K8s 里有大量设计模式和 Go 协程的应用——声明式部署（Builder 模式）、控制器（Observer 模式）、Scheduler（策略模式）、Informer（生产者-消费者模式）——你能比纯粹的运维人员理解得更深。
