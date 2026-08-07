# Istio 服务网格深度解析（Java Spring Boot 工程师视角）

> 面向 Java 工程师的 Istio 指南。
> 回答四个核心问题：
> 1. Istio 是什么？
> 2. 它解决了什么问题？
> 3. Istio 是 Resilience4j 的替代品吗？
> 4. Sidecar 模式与 Istio 的关系？

---

## 目录

| 章节 | 内容 |
|------|------|
| 一 | Istio 是什么 |
| 二 | Istio 解决了什么问题 |
| 三 | Istio 全称、作者、历史 |
| 四 | Istio 的核心架构：数据平面 + 控制平面 |
| 五 | Sidecar 模式与 Istio 的关系（核心章节） |
| 六 | **Istio vs Resilience4j——是替代品吗？（核心章节）** |
| 七 | Istio 的核心功能详解 |
| 八 | 你的 smart-invest 项目如何接入 Istio |
| 九 | 面试高频问题 |

---

## 一、Istio 是什么

### 一句话定义

> **Istio 是一个 Service Mesh（服务网格），它在不修改应用代码的前提下，为微服务集群统一提供流量管理、安全加密、和可观测性能力。**

### 用你的 smart-invest 项目来理解

你现在有两个服务：

```
order-service ───调用───→ user-service
```

**没有 Istio 时：**

```java
// order-service 的代码
@RestController
public class OrderController {

    @Autowired
    private RestTemplate restTemplate;

    @GetMapping("/orders/{id}")
    public Order getOrder(@PathVariable Long id) {
        // 直接 HTTP 调用 user-service
        User user = restTemplate.getForObject(
            "http://user-service:8081/users/" + id, User.class);
        // ...
    }
}
```

这里有一个问题：order-service 和 user-service 之间的通信是**应用代码自己负责的**——如果 user-service 响应慢怎么办？如果要加认证怎么办？如果要看调用链怎么办？全都得改代码。

**有了 Istio 后：**

```
order-service Pod                  user-service Pod
┌──────────────┐                  ┌──────────────┐
│  Java App    │                  │  Java App    │
│  (你的代码)   │                  │  (你的代码)   │
│              │                  │              │
│  "我调 http  │──→ HTTP ──→     │  "有人调我"   │
│   ://user-   │                  │              │
│   service"   │                  │              │
└──────┬───────┘                  └──────┬───────┘
       │                                │
┌──────┴───────┐                  ┌──────┴───────┐
│   Envoy      │                  │   Envoy      │
│   Sidecar    │ ←── mTLS ──→    │   Sidecar    │
│   (Istio)    │   (自动加密)      │   (Istio)    │
└──────────────┘                  └──────────────┘
```

**你的 Java 代码一行没改**，但是：
- 调用自动加密了（mTLS）
- 有了超时控制、重试、熔断
- 有了调用链追踪
- 有了 QPS / 延迟 / 错误率的指标

**这就是 Istio 的核心价值：把「服务间通信的治理」从应用代码中抽出来，放到 Sidecar 里统一管理。**

---

## 二、Istio 解决了什么问题

### 2.1 微服务的「死亡之痛」

当一个公司从单体架构迁移到微服务架构后，会立刻面临这些新的痛苦：

| 问题 | 没有 Istio | 有 Istio |
|------|-----------|----------|
| **流量控制** | 每个服务自己写 Retry、Timeout、Circuit Breaker | Istio 在 Sidecar 层面统一处理，配置即生效 |
| **灰度发布** | 改 Nginx/改代码 | VirtualService 配权重，一条 `kubectl apply` 搞定 |
| **服务间安全** | 每个服务自己配 TLS 证书 | Istio 自动给所有服务间通信加 mTLS（双向 TLS） |
| **可观测性** | 每个服务自己接 Prometheus、自己打 Tracing 日志 | Sidecar 自动采集，业务代码零侵入 |
| **故障注入** | 写专门的 chaos 测试代码 | Istio 直接配「对 10% 的请求返回 500」 |

### 2.2 用一个真实场景说明

**场景：你要做一个金丝雀发布（Canary Release）**

```
新版本 user-service:v2 已经部署，但只给它 5% 的流量，
观察 10 分钟没有异常 → 逐步加到 25% → 50% → 100%
```

**没有 Istio 时你怎么做？**

```java
// 在 API Gateway 里写自定义负载均衡代码
// 或者自己搞一套能改权重的 Nginx + Lua 脚本
// 或者 Spring Cloud Gateway + 自定义 Route 配置
// 这些方案都依赖特定语言/框架，而且每个服务都要配一遍
```

**有 Istio 时你怎么做？**

```yaml
# 一条 YAML，不改任何代码
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: user-service
spec:
  hosts:
  - user-service
  http:
  - route:
    - destination:
        host: user-service
        subset: v1        # 旧版本
      weight: 95
    - destination:
        host: user-service
        subset: v2        # 新版本
      weight: 5           # 先给 5%
```

这就是 Istio 解决的核心问题：**用声明式配置代替写代码，统一治理所有微服务间的通信。**

---

## 三、Istio 全称、作者、历史

| 属性 | 说明 |
|------|------|
| **全称** | Istio。不是缩写。名字来自希腊语 ἰστίον（istion），意为「帆 / sail」。寓意是让微服务在网络之海中有方向地航行 |
| **作者** | Google、IBM、Lyft 三家联合创建 |
| **首次发布** | 2017 年 5 月（v0.1），2018 年 7 月 GA（v1.0） |
| **当前地位** | CNCF 毕业项目（2022 年），和 K8s 一样是云原生生态的一等公民 |
| **核心组件** | 控制平面：**Istiod**；数据平面：**Envoy** proxy（Lyft 开源，C++ 编写的高性能代理） |

### Istio 不叫「Isto」

很多人会听错/打错为「isto」，实际是 **Istio**。发音：`/ˈɪstiːəʊ/`（「伊斯提欧」）。如果你面试时说这个词，读「ist-ee-oh」就行。

---

## 四、Istio 的核心架构：数据平面 + 控制平面

```
┌─────────────────────────────────────────────────────────────┐
│                    Istio Control Plane (控制平面)             │
│                   ┌──────────────────────┐                   │
│                   │       istiod          │                   │
│                   │   (一个二进制搞定一切)   │                   │
│                   │                       │                   │
│                   │  - Pilot: 流量规则下发  │                   │
│                   │  - Citadel: 证书管理   │                   │
│                   │  - Galley:  配置校验   │                   │
│                   └──────────┬───────────┘                   │
└──────────────────────────────┼────────────────────────────────┘
                               │ 下发配置 (xDS 协议)
          ┌────────────────────┼────────────────────┐
          ↓                    ↓                     ↓
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  Pod: order-svc  │ │  Pod: user-svc  │ │  Pod: fund-svc   │
│ ┌──────────────┐ │ │ ┌──────────────┐ │ │ ┌──────────────┐ │
│ │  Java App    │ │ │ │  Java App    │ │ │ │  Java App    │ │
│ │  (你的代码)   │ │ │ │  (你的代码)   │ │ │ │  (你的代码)   │ │
│ └──────┬───────┘ │ │ └──────┬───────┘ │ │ └──────┬───────┘ │
│ ┌──────┴───────┐ │ │ ┌──────┴───────┐ │ │ ┌──────┴───────┐ │
│ │    Envoy     │ │ │ │    Envoy     │ │ │ │    Envoy     │ │
│ │   Sidecar    │ │ │ │   Sidecar    │ │ │ │   Sidecar    │ │
│ └──────────────┘ │ │ └──────────────┘ │ │ └──────────────┘ │
└──────────────────┘ └──────────────────┘ └──────────────────┘
        ↑ 数据平面 (Data Plane) ↑
        所有流量都经过 Sidecar
```

| 角色 | 组件 | 作用 | 类比 |
|------|------|------|------|
| **控制平面** | istiod | 管理全局配置（流量规则、安全策略），下发到每个 Sidecar | **交警指挥中心**：制定交通规则，告诉每个路口的交警怎么指挥 |
| **数据平面** | Envoy Sidecar | 每个 Pod 里有一个，拦截所有进出流量，执行规则 | **每个路口的交警**：实际执行指挥（限流、放行、记录） |

---

## 五、Sidecar 模式与 Istio 的关系（核心章节）

### 5.1 什么是 Sidecar 模式

**Sidecar（边车）** 是一种容器设计模式：在同一个 Pod 里放两个容器——一个是你的应用，一个是辅助容器。

```
┌──────────────────────────────────────────┐
│                 Pod                       │
│                                           │
│  ┌────────────────┐  ┌─────────────────┐ │
│  │  Main Container │  │ Sidecar Container│ │
│  │  (你的 Java App)│  │ (Envoy / Istio)  │ │
│  │                 │  │                  │ │
│  │  监听 :8080     │  │  监听 :15001     │ │
│  └────────┬───────┘  └────────┬────────┘ │
│           │                   │           │
│           └───共享网络 namespace──┘        │
│           (同一个 IP、同一个 localhost)     │
└──────────────────────────────────────────┘
```

**名字来源：** Sidecar 来自摩托车旁边的**边斗（sidecar）**——主车（摩托车 = 你的 Java 应用）和边斗（Sidecar = Envoy）绑定在一起，形影不离。

**关键特性：**
- 共享同一个 Pod IP
- 共享 localhost（`curl localhost:15001` 可以访问 Sidecar）
- 共享 Volume
- 生命周期绑定：Pod 创建时 Sidecar 先启动，Pod 销毁时 Sidecar 最后退出

### 5.2 Istio 用 Sidecar 做了什么

Istio 在**每个 Pod 里注入一个 Envoy Sidecar**。它通过 **iptables 规则**拦截 Pod 的所有进出流量，让 Envoy 成为代理：

```
原来（无 Istio）：
  Java App → 直接 HTTP 调用 → 目标 Java App

Istio 注入后：
  Java App → 发 HTTP 请求 → iptables 拦截 → 转发给 Envoy Sidecar
  → Envoy 做：超时/重试/熔断/加密/记录指标/追踪
  → Envoy 转发给目标 Pod 的 Envoy Sidecar
  → 目标 Envoy 做：解密/鉴权/记录指标
  → 转发给目标 Java App

你的 Java 代码完全不知道中间多了一层——它以为自己在直接调目标服务
```

**用 iptables 规则解释（你可以上 K3S 节点自己看）：**

```bash
# 进入一个注入 Istio 的 Pod，查看流量劫持规则
iptables -t nat -L -n -v
# 你会看到类似这样的规则：
# 所有从 App Container 发出的流量 → 重定向到 Envoy 的 15001 端口
# 所有进入 Pod 的流量 → 先经过 Envoy 的 15006 端口
```

### 5.3 Sidecar 模式 vs 非 Sidecar 模式

| 对比维度 | Sidecar 模式（Istio 传统方案） | 非 Sidecar 模式（例如 Resilience4j） |
|----------|-------------------------------|-------------------------------------|
| **代码侵入** | 零侵入——应用代码完全不知道 Istio 的存在 | 侵入式——要在 pom.xml 加依赖，代码里加注解 |
| **语言绑定** | 语言无关——Java、Go、Python 都能用 | 绑死 Java——其他语言用不了 |
| **升级方式** | 升级 Sidecar 镜像即可，应用不需要重新构建 | 升级 pom.xml 依赖→重新构建→重新部署 |
| **配置方式** | YAML（Istio CRD） | Java 代码 / application.yml |
| **运维责任** | 平台团队统一管理 | 每个团队各自管理，可能配置不一致 |
| **性能开销** | 每个 Pod 多一个 Envoy 进程（约 50MB 内存） | 零额外进程开销 |
| **故障隔离** | Sidecar 出问题不影响应用进程本身 | 依赖库的 Bug 可能导致应用崩溃 |

**Sidecar 的本质好处是：把「横切关注点」（安全、流量治理、可观测性）从业务代码中剥离，让 AOP 发生在容器层面而不是代码层面。**

```
Java AOP（Spring AOP）:
  @Around 切面 → 拦截方法调用 → 加日志/事务/权限

Istio Sidecar（容器层 AOP）:
  Envoy Sidecar → 拦截网络流量 → 加加密/限流/追踪

两者的思想完全一样，只是作用层级不同。
代码层 AOP → 容器网络层 AOP
```

---

## 六、Istio vs Resilience4j——是替代品吗？（核心章节）

### 6.1 Resilience4j 是什么

**Resilience4j**（resilience + for + Java，意为「Java 的韧性」）是一个 Java 轻量级容错库，灵感来自 Netflix Hystrix。它是专门给 Java 开发者用的，在**应用进程内部**提供：

| 功能 | 注解/用法 | 作用 |
|------|----------|------|
| **Circuit Breaker（断路器）** | `@CircuitBreaker(name = "userService")` | user-service 连续失败 N 次 → 直接返回 fallback，不继续调（快速失败） |
| **Retry（重试）** | `@Retry(name = "userService")` | 调用失败后自动重试 N 次 |
| **TimeLimiter（超时）** | `@TimeLimiter(name = "userService")` | 超过指定时间没响应就抛异常 |
| **RateLimiter（限流）** | `@RateLimiter(name = "userService")` | 每秒最多允许 N 个请求 |
| **Bulkhead（舱壁隔离）** | `@Bulkhead(name = "userService")` | 限制并发调用数，防止一个服务拖垮整个应用 |

**在你的 smart-invest 项目中的用法：**

```java
// 你需要加这个依赖
// <dependency>
//     <groupId>io.github.resilience4j</groupId>
//     <artifactId>resilience4j-spring-boot3</artifactId>
// </dependency>

@RestController
public class OrderController {

    @Autowired
    private RestTemplate restTemplate;

    @CircuitBreaker(name = "userService", fallbackMethod = "userFallback")
    @Retry(name = "userService")
    @TimeLimiter(name = "userService")
    @GetMapping("/orders/{id}")
    public Order getOrder(@PathVariable Long id) {
        User user = restTemplate.getForObject(
            "http://user-service:8081/users/" + id, User.class);
        // ...
    }

    // 熔断后的兜底方法
    public Order userFallback(Long id, Throwable t) {
        return Order.builder()
            .id(id)
            .userName("User Service Unavailable")
            .build();
    }
}
```

### 6.2 它们的关系：不是替代，是不同层次

```
                          ┌─────────────────────────┐
   应用层容错               │     Resilience4j         │
  (应用进程内部)            │  - @CircuitBreaker       │
                           │  - @Retry               │
                           │  - @TimeLimiter         │
                           │  代码侵入，语言绑定        │
                           └─────────────────────────┘
                                     ↑
                                     │ 互补，不是互斥
                                     ↓
                           ┌─────────────────────────┐
   网络层容错               │       Istio              │
  (Sidecar 代理层)          │  - Circuit Breaker       │
                           │  - Retry                │
                           │  - Timeout              │
                           │  零代码侵入，语言无关       │
                           └─────────────────────────┘
```

| 对比维度 | Resilience4j | Istio |
|----------|-------------|-------|
| **运行位置** | 应用 JVM 进程内部 | Pod 内的 Sidecar 容器（Envoy） |
| **拦截层级** | 方法调用层（AOP 切面） | 网络层（iptables + Envoy 代理） |
| **代码侵入** | 需要：pom.xml 加依赖 + 注解 + fallback 方法 | 零：一行业务代码不用改 |
| **语言限制** | 只有 Java / Kotlin | 任何语言（Go/Python/Node.js/C++） |
| **熔断粒度** | 方法级别 | Service 级别 |
| **配置方式** | `application.yml` 或注解 | Istio CRD YAML（如 DestinationRule） |
| **适用场景** | 单体应用 / 非 K8s 部署 / 细粒度业务容错 | K8s 集群中的微服务通信治理 |

### 6.3 核心结论

**Istio 不是 Resilience4j 的替代品，它们是互补关系。**

但有一个重要的实际考虑：

| 场景 | 建议 |
|------|------|
| **你已经有 K8s + Istio** | 流量治理优先用 Istio（Circuit Breaker / Retry / Timeout）。不写代码就能配，统一管理，不绑定语言。Resilience4j 用在 Istio 做不了的细粒度场景（如某个特定方法的 fallback 逻辑） |
| **你没有 K8s 或没有 Istio** | 用 Resilience4j。它是 JVM 进程内的方案，不需要任何基础设施 |
| **你朋友离职那个 SAP 项目** | SAP Kyma 内置了 Istio。他们的 Circuit Breaker / Retry / Timeout 是用 Istio 的 DestinationRule 配置的，不是用 Resilience4j |
| **你的 smart-invest 项目（K3S）** | 目前没有 Istio。如果你想加熔断/重试，有两个选择：(1) 简单方案：加 Resilience4j 依赖；(2) 专业方案：装 Istio，用 DestinationRule 配熔断 |

**面试时的标准回答：**

> 「Resilience4j 和 Istio 的 Circuit Breaker 不是同一层的东西。Resilience4j 在 JVM 进程内拦截方法调用，Istio 的 Envoy Sidecar 在网络层拦截 HTTP/TCP 流量。在 K8s 环境中，流量治理（熔断、重试、超时、灰度）优先用 Istio，因为零代码侵入、语言无关、配置统一管理。Resilience4j 更适合非 K8s 环境或需要细粒度业务级容错的场景。两者可以同时用——Istio 管服务间通信的通用韧性，Resilience4j 管应用进程内的特殊业务逻辑兜底。」

---

## 七、Istio 的核心功能详解

### 7.1 流量管理（Traffic Management）

**核心 CRD（Custom Resource Definition）：**

| CRD | 全称 | 作用 | 类比 |
|-----|------|------|------|
| **VirtualService** | 虚拟服务 | 定义「流量到哪里去」——按权重/Header/路径路由 | Nginx `server { location }` |
| **DestinationRule** | 目标规则 | 定义「到了目的地后怎么处理」——负载均衡策略、熔断、TLS | 给 upstream 配置的连接池参数 |
| **Gateway** | 网关 | 网格边界的入口/出口 | Nginx 在边界监听 80/443 |

**面试高频配置——金丝雀发布 + 熔断：**

```yaml
# 1. DestinationRule：定义两个子版本
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: user-service
spec:
  host: user-service
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  # 全局熔断配置
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100           # 最大连接数
      http:
        http1MaxPendingRequests: 10   # 最大等待请求数
        maxRequestsPerConnection: 5   # 每连接最大请求数
    outlierDetection:                  # 异常检测（熔断触发条件）
      consecutive5xxErrors: 5         # 连续 5 次 5xx → 熔断
      interval: 30s
      baseEjectionTime: 30s           # 熔断 30 秒
      maxEjectionPercent: 50          # 最多熔断 50% 的 Pod

---
# 2. VirtualService：金丝雀流量分配
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: user-service
spec:
  hosts:
  - user-service
  http:
  - match:
    - headers:
        x-canary:
          exact: "true"               # 带这个 Header 的请求全走 v2
    route:
    - destination:
        host: user-service
        subset: v2
  - route:                            # 默认流量：95% v1，5% v2
    - destination:
        host: user-service
        subset: v1
      weight: 95
    - destination:
        host: user-service
        subset: v2
      weight: 5
```

### 7.2 安全（Security）

Istio 提供**自动 mTLS**。你不需要给每个 Java 服务配 `server.ssl.key-store`。

```yaml
# 一条 PeerAuthentication 策略
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: smart-invest
spec:
  mtls:
    mode: STRICT        # 强制所有服务间通信加密
```

**效果：**
- Istio 自动给每个 Sidecar 颁发证书（由 istiod 中的 Citadel 组件签发）
- Sidecar 之间自动做 mTLS 握手
- 你的 Java 代码继续用 HTTP（不是 HTTPS），但网络包在传输层已加密
- 这在金融/合规场景中非常重要——「所有服务间通信必须加密」是硬性要求

### 7.3 可观测性（Observability）

**Istio 自动采集三大支柱数据，不改代码：**

| 支柱 | Istio 做了什么 | 你不需要做什么 |
|------|---------------|---------------|
| **Metrics** | Envoy 自动上报请求量/成功率/延迟的 Prometheus 指标 | 不需要加 Micrometer/Prometheus 依赖 |
| **Tracing** | Envoy 自动生成 Trace ID 并在 HTTP Header 中传播 | 不需要加 Spring Cloud Sleuth/Brave |
| **Logging** | Envoy 自动记录每个请求的访问日志 | 不需要在 Controller 里手动打日志 |

---

## 八、你的 smart-invest 项目如何接入 Istio

### 8.1 当前状态

你的 smart-invest 运行在 **K3S** 上，K3S 默认不带 Istio。你需要手动安装。

### 8.2 安装 Istio（极简版）

```bash
# 1. 下载 istioctl
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# 2. 安装到 K3S 集群（用 minimal profile，资源开销小）
istioctl install --set profile=minimal -y

# 3. 给 smart-invest namespace 开启自动 Sidecar 注入
kubectl label namespace smart-invest istio-injection=enabled

# 4. 重新部署——新 Pod 自动被注入 Envoy Sidecar
helm upgrade --install smart-invest ./umbrella \
  -n smart-invest --create-namespace \
  --wait --timeout 300s

# 5. 验证——每个 Pod 里应该有两个容器了
kubectl get pods -n smart-invest
# NAME                            READY   STATUS
# user-service-xxx                2/2     Running    ← 2/2！多了 Envoy
```

### 8.3 接入后你能获得的「免费」能力

一装完 Istio，你立刻获得（一行代码不改）：

1. **Kiali 可视化**——看到所有微服务之间的调用拓扑图
2. **Grafana 指标**——每个服务的 QPS、延迟 P50/P90/P99、错误率
3. **Jaeger 追踪**——一个请求横跨 order-service → fund-service → user-service 的完整链路
4. **mTLS 加密**——所有服务间通信自动加密
5. **金丝雀发布**——配一条 VirtualService YAML 就能灰度

---

## 九、面试高频问题

### Q1: 什么是 Service Mesh？Istio 和它什么关系？

**答案：**

> Service Mesh（服务网格）是一种基础设施层，专门处理微服务之间的通信。就像 TCP/IP 是网络层的标准协议一样，Service Mesh 是应用通信层的标准方案。Istio 是 Service Mesh 理念最流行的实现（另一个是 Linkerd）。

### Q2: Istio 的 Sidecar 注入是怎么实现的？

**答案：**

> Istio 利用了 K8s 的 **Mutating Admission Webhook**。当你创建一个 Pod 时，apiserver 在处理请求的准入阶段（Admission），会调用 Istio 的 webhook。Webhook 自动修改 Pod 的 YAML——在 `spec.containers` 中追加一个 Envoy 容器，并注入 `istio-init` 容器来设置 iptables 规则。这一切对开发者完全透明。

### Q3: Istio 的性能开销有多大？

**答案：**

> 每个 Envoy Sidecar 约消耗 **50MB 内存 + 0.1 核 CPU**。对于资源敏感的场景（比如边缘计算），这是额外的开销。Istio 在 2023 年推出了 **Ambient Mesh** 模式——不再给每个 Pod 注入 Sidecar，而是用节点级别的 ztunnel（零信任隧道）来处理流量。不过目前 Ambient 模式还在成熟中，生产还是 Sidecar 模式为主。

### Q4: 你朋友那个 SAP 项目中是怎么用 Istio 的？

> SAP Kyma 内置 Istio 作为服务网格。在 SAP 项目中，Istio 的主要用途：
> 1. **VirtualService** 管理多区域流量路由（US20/EU20/IN30...每个 region 有独立的 VirtualService 配置）
> 2. **DestinationRule** 配置熔断和异常检测
> 3. **mTLS** 全网格加密——金融级合规要求
> 4. **EnvoyFilter** 配合 AWS X-Ray 做分布式追踪（自动传播 `x-amzn-trace-id`）
>
> 所有这些东西都在 GitOps 仓库中通过 Helm + Bash + kubectl 管理，不需要应用代码配合。

---

> **核心结论：**
>
> 1. **Istio ≠ Resilience4j 替代品**——它俩在不同层。Istio 在网络层（Sidecar），Resilience4j 在应用层（JVM 内）。有 K8s + Istio 时流量治理用 Istio，细粒度业务兜底用 Resilience4j。
> 2. **Sidecar 是 Istio 的实现方式**——Istio 通过在每个 Pod 里注入 Envoy Sidecar，用 iptables 劫持流量，实现零代码侵入的服务治理。
> 3. **Istio 的本质是把 AOP 的思想从 Java 代码层搬到了容器网络层**——你在 Spring Boot 中熟悉的 `@Around` 切面，在 Istio 中以 Envoy Sidecar 的形式存在。
