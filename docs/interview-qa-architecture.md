# Smart-Invest AWS Architecture — Interview Q&A

# 架构面试题（英文 + 中文）

> 面向英文面试，英语词汇控制在高中水平。  
> 数据中心：**新加坡（ap-southeast-1）主站** + **香港（ap-east-1）灾备**。

---

## Part 1 — JD Core Skills（Java 21 · OCP · Kafka · DDD · TDD）

## 第一部分：JD 核心技术栈

> 以下题目直接对应岗位 JD 技术要求。

---

### Q1. What is new in Java 21 that you find most useful? Tell me about Virtual Threads.

### 问题1：Java 21 最有用的新特性是什么？请介绍虚拟线程。

**English Answer:**

Java 21 has many new features. The most important one for a server-side system is **Virtual Threads** (from Project Loom).

**Old way — Platform Threads:**
A normal Java thread maps 1-to-1 to an OS thread. OS threads are expensive — creating 10,000 threads uses a lot of memory and the OS spends a lot of time switching between them. So Spring Boot uses a thread pool with maybe 200 threads. If 200 requests are all waiting for a database response, the 201st request must wait.

**New way — Virtual Threads:**
Virtual threads are very lightweight. You can create **millions** of them. When a virtual thread is blocked (waiting for a database or network call), Java automatically parks it and lets another virtual thread run on the same OS thread. This is called **non-blocking I/O without changing your code**.

```java
// Spring Boot 3 — enable virtual threads in application.properties
spring.threads.virtual.enabled=true
// That's it. No code changes needed.
```

Other useful Java 21 features:

- **Record classes** — simple data holders, no boilerplate getters/setters
- **Pattern matching for switch** — cleaner if/else logic
- **Sealed classes** — control which classes can extend a type (useful for DDD value objects)

**中文解释：**

Java 21 最重要的特性是**虚拟线程（Virtual Threads）**：

- **旧方式**：平台线程（OS线程），创建成本高，线程池上限约200个，一旦全部阻塞在等I/O，新请求只能排队。
- **虚拟线程**：极轻量级，可创建数百万个。线程阻塞时自动让出OS线程，等待完成后继续执行，本质上是在JVM层实现了协程。Spring Boot 3 只需一行配置即可启用，无需改业务代码。

其他实用特性：Record类（简化DTO/Value Object）、Switch模式匹配（简化条件分支）、Sealed类（配合DDD封闭类型体系）。

---

### Q2. What are the main differences between Spring Boot 2 and Spring Boot 3?

### 问题2：Spring Boot 2 和 Spring Boot 3 的主要区别是什么？

**English Answer:**

Spring Boot 3 made three big changes:

1. **Jakarta EE 9+ (namespace change)**
   All `javax.*` packages are renamed to `jakarta.*`. This is the most common breaking change when migrating. For example: `javax.persistence.Entity` → `jakarta.persistence.Entity`. If your code uses Spring Security, JPA, or Servlet APIs, you must update all imports.

2. **Minimum Java version is Java 17**
   Spring Boot 2 supports Java 8. Spring Boot 3 requires Java 17 at minimum. In practice, we use Java 21 for virtual threads.

3. **Better observability out of the box**
   Spring Boot 3 uses **Micrometer** with a new `@Observed` annotation. You can add distributed tracing (X-Ray, Zipkin) and metrics with almost no code. It also supports **native compilation** with GraalVM — the app starts in milliseconds instead of seconds.

**中文解释：**

Spring Boot 3 三个核心变化：

1. **javax → jakarta 命名空间迁移**：所有 `javax.*` 包改为 `jakarta.*`，这是升级时最常见的编译报错，批量替换import即可。
2. **最低Java 17**：Spring Boot 2支持Java 8，Spring Boot 3要求Java 17+，搭配Java 21可使用虚拟线程。
3. **可观测性增强**：内置Micrometer Tracing，一个`@Observed`注解自动生成链路追踪span；支持GraalVM原生镜像，启动时间从秒级降到毫秒级（对Kubernetes弹性伸缩非常有价值）。

---

### Q3. What is OCP (OpenShift)? How is it different from plain Kubernetes?

### 问题3：什么是 OCP（OpenShift）？和原生 Kubernetes 有什么区别？

**English Answer:**

**OCP** stands for **OpenShift Container Platform**. It is Red Hat's version of Kubernetes. Think of it as "Kubernetes + many extra enterprise features already set up."

Key differences:

| Feature            | Kubernetes (plain)     | OCP (OpenShift)                                           |
| ------------------ | ---------------------- | --------------------------------------------------------- |
| Security           | You set it up yourself | Very strict by default (no root containers, SCC policies) |
| Ingress            | Ingress resource       | **Route** resource (similar, but OCP-specific)            |
| Image registry     | External (ECR, etc.)   | Built-in internal registry                                |
| Web console        | Basic dashboard        | Full web console with build pipelines                     |
| Developer workflow | `kubectl apply`        | `oc new-app`, built-in Source-to-Image (S2I)              |
| Support            | Community              | Red Hat enterprise support                                |

In practice, if your company uses OCP instead of plain EKS, the main things to learn are:

- Use `oc` command instead of `kubectl` (most commands are the same)
- Use **Routes** instead of Ingress
- Watch out for **Security Context Constraints (SCC)** — OCP blocks root containers by default

**中文解释：**

OCP = OpenShift Container Platform，是Red Hat基于Kubernetes的企业发行版，相当于"Kubernetes + 企业级预装功能套件"。

关键差异：

- **安全性**：OCP默认禁止root容器运行（SCC策略），比原生K8s严格得多。迁移时最容易踩坑：镜像里以root启动的服务在OCP上直接报错。
- **Route vs Ingress**：OCP用Route替代Ingress，功能类似但语法不同。
- **内置镜像仓库**：OCP自带镜像仓库，原生K8s需要自己对接ECR/Harbor等。
- **命令行**：`oc`命令，大部分与`kubectl`相同，额外提供`oc new-app`等开发者友好命令。

面试回答要点：理解两者本质相同（都是K8s），OCP加了安全合规层，在金融/政府场景更受欢迎。

---

### Q4. What is the difference between Kafka and IBM-MQ? When do you use each?

### 问题4：Kafka 和 IBM-MQ 有什么区别？什么场景用哪个？

**English Answer:**

Both Kafka and IBM-MQ are message systems. They solve different problems.

**IBM-MQ — Traditional Message Queue:**

- Each message is delivered to **exactly one consumer**. Once consumed, it is gone.
- Best for: "send a payment request, one service processes it, done." The message must not be processed twice.
- Guarantees: **at-most-once** or **exactly-once** delivery.
- Used in banking for many years. Very reliable. Enterprise support.

**Kafka — Event Streaming Platform:**

- Messages are stored as a **log** and can be read by **many consumers independently**.
- Best for: "a user made a trade — the risk service, the audit service, and the portfolio service all need to know about it." Each service reads the same event at its own pace.
- Messages are kept for days or weeks (configurable). You can replay old events.
- Much higher throughput than IBM-MQ.

**Simple rule:**

- Use **IBM-MQ** when you need guaranteed exactly-once processing of commands (e.g., "transfer money").
- Use **Kafka** when you need to broadcast events to many services, or need to replay events (e.g., "user logged in" — audit, analytics, fraud detection all care).

**中文解释：**

|      | IBM-MQ             | Kafka               |
| ---- | ------------------ | ------------------- |
| 消息消费 | 一条消息只被一个消费者处理（点对点） | 一条消息可被多个消费者组独立消费    |
| 消息保留 | 消费后删除              | 保留数天/数周，可重放         |
| 吞吐量  | 中等                 | 极高（百万级/秒）           |
| 适用场景 | 命令（精确一次执行）：转账、下单   | 事件（广播）：用户行为、审计日志、风控 |

**面试答法**：IBM-MQ用于"命令"（需要精确一次处理，不能重复），Kafka用于"事件"（需要多个服务响应同一事件，或需要事件回溯）。两者在同一系统中可以共存。

---

### Q5. What is Domain-Driven Design (DDD)? Explain with an example from a financial system.

### 问题5：什么是领域驱动设计（DDD）？请用金融系统举例说明。

**English Answer:**

DDD is a way to design software by focusing on the **business domain** — the real-world problem you are solving. The code structure should reflect how the business works, not how the database looks.

**Key concepts:**

1. **Bounded Context** — a clear boundary around one part of the business. In our system:
   
   - `Order Context`: handles placing and managing orders
   - `Portfolio Context`: handles what assets a user holds
   - `Fund Context`: handles fund information
     Each context has its own database and does not share tables with others.

2. **Aggregate** — a cluster of objects that must stay consistent together. For example, an `Order` aggregate contains the `Order` itself plus its `OrderItems`. You always save or load them together. The `Order` is the **Aggregate Root** — the only entry point to change the data.

3. **Domain Event** — something important that happened in the business. For example: `OrderPlaced`, `FundPurchased`, `PortfolioUpdated`. Other bounded contexts listen for these events (via Kafka) and react.

4. **Value Object** — an object defined by its value, not its identity. For example, `Money(100, USD)` — two Money objects with the same amount and currency are equal. No ID needed. Use Java `record` classes for these.

**中文解释：**

DDD核心思想：**代码结构反映业务结构**，而不是反映数据库表结构。

金融系统中的应用：

- **限界上下文（Bounded Context）**：order-service、fund-service、portfolio-service各自是独立的上下文，各自拥有自己的数据库，互不直接访问对方的表。
- **聚合（Aggregate）**：`Order`聚合包含Order本身 + 若干OrderItem，只能通过`Order`（聚合根）修改，保证一致性。
- **领域事件（Domain Event）**：`OrderPlaced`事件通过Kafka发布，portfolio-service监听后更新持仓，实现解耦。
- **值对象（Value Object）**：`Money(100, "USD")`，用Java 21 Record实现，两个Money只要金额和币种相同就相等，不需要ID。

---

### Q6. What is TDD? Show me the Red-Green-Refactor cycle with a simple example.

### 问题6：什么是 TDD？请用一个简单例子演示红-绿-重构循环。

**English Answer:**

**TDD (Test-Driven Development)** means you write the test **before** you write the code. The cycle has three steps:

1. **Red** — write a test that fails (because the code doesn't exist yet)
2. **Green** — write the minimum code to make the test pass
3. **Refactor** — clean up the code, keeping the test green

**Example — calculate order total with discount:**

```java
// Step 1: RED — write the test first (it fails because OrderService doesn't exist yet)
@Test
void shouldApply10PercentDiscountWhenOrderOver1000() {
    OrderService service = new OrderService();
    Money total = service.calculateTotal(new BigDecimal("1200"));
    assertThat(total.getAmount()).isEqualByComparingTo("1080.00"); // 1200 * 0.9
}

// Step 2: GREEN — write just enough code to pass
public class OrderService {
    public Money calculateTotal(BigDecimal amount) {
        if (amount.compareTo(new BigDecimal("1000")) > 0) {
            return new Money(amount.multiply(new BigDecimal("0.9")));
        }
        return new Money(amount);
    }
}

// Step 3: REFACTOR — extract the discount threshold to a named constant
private static final BigDecimal DISCOUNT_THRESHOLD = new BigDecimal("1000");
private static final BigDecimal DISCOUNT_RATE = new BigDecimal("0.9");
```

Why TDD matters for this job (Code Review + Refactor focus):

- Tests act as living documentation — you can refactor safely because tests catch regressions.
- Forces you to think about the interface before the implementation.

**中文解释：**

TDD = 先写测试，再写实现，最后重构。循环是：**红（测试失败）→ 绿（测试通过）→ 重构（改善代码质量）**。

对这个JD的意义：岗位要求Code Review和Code Refactor，TDD提供了重构的安全网——有测试覆盖才能放心重构，改坏了测试立刻报红。

关键点：每次只写**刚好能让测试通过的最少代码**，不过度设计，然后再重构。这叫做YAGNI原则（You Aren't Gonna Need It）。

---

### Q7. How do you use Mockito in unit tests? Why do we mock dependencies?

### 问题7：如何在单元测试中使用 Mockito？为什么要 Mock 依赖？

**English Answer:**

When we test a service, we don't want to connect to a real database or call a real external API. That would make tests slow and unreliable. **Mockito** lets us create fake ("mock") versions of dependencies.

**Example — test portfolio-service without hitting the real database:**

```java
@ExtendWith(MockitoExtension.class)
class PortfolioServiceTest {

    @Mock
    private PortfolioRepository repository;  // fake database

    @Mock
    private FundClient fundClient;           // fake HTTP call to fund-service

    @InjectMocks
    private PortfolioService portfolioService;

    @Test
    void shouldReturnTotalValueOfPortfolio() {
        // Arrange — tell the mock what to return
        when(repository.findByUserId("user123"))
            .thenReturn(List.of(new Holding("FUND_A", 100)));
        when(fundClient.getPrice("FUND_A"))
            .thenReturn(new BigDecimal("12.50"));

        // Act
        Money total = portfolioService.getTotalValue("user123");

        // Assert
        assertThat(total.getAmount()).isEqualByComparingTo("1250.00");

        // Verify the repository was called exactly once
        verify(repository, times(1)).findByUserId("user123");
    }
}
```

**Why mock?**

- Tests run in milliseconds, not seconds
- No need for a running database in CI pipeline
- You can test error cases easily: `when(...).thenThrow(new RuntimeException("DB down"))`

**中文解释：**

Mockito核心用法三步：

1. `@Mock`：创建假对象，不需要真实的数据库或网络连接。
2. `when(...).thenReturn(...)` / `when(...).thenThrow(...)`：定义假对象的行为。
3. `verify(...)`：验证某个方法被调用了几次。

为什么要Mock：单元测试要快（毫秒级）、稳定（不依赖外部系统）、可控（能模拟各种异常场景）。Mock让我们把测试范围严格限制在当前Service的业务逻辑上，而不是整个系统。

---

### Q8. What is the Pub/Sub pattern? How does it help in a microservices system?

### 问题8：什么是 Pub/Sub 模式？它如何帮助微服务解耦？

**English Answer:**

**Pub/Sub (Publish/Subscribe)** is an Enterprise Integration Pattern. It works like a newspaper:

- The **Publisher** writes an article and sends it to the newspaper.
- Multiple **Subscribers** read the newspaper independently. The publisher does not know who reads it.

In microservices with Kafka:

```
order-service publishes: OrderPlaced { orderId, userId, amount, timestamp }
        ↓ Kafka topic: "order.events"
        ├── portfolio-service subscribes → updates user's holdings
        ├── audit-service subscribes → writes to audit log
        └── notification-service subscribes → sends email to user
```

**Benefits:**

1. **Loose coupling** — `order-service` does not call `portfolio-service` directly. If `portfolio-service` is down, orders still work. Portfolio-service catches up when it restarts.
2. **Easy to add new subscribers** — if we add a `fraud-detection-service`, it just subscribes to the same topic. No changes to `order-service`.
3. **Event replay** — Kafka keeps events for 7 days. If `portfolio-service` has a bug and processes events wrong, we can fix the bug and replay all events to correct the data.

**Compare to direct REST calls:**
If `order-service` calls `portfolio-service` via REST and portfolio-service is down, the order fails. With Pub/Sub, the order succeeds and portfolio-service processes the event when it comes back up.

**中文解释：**

Pub/Sub是Enterprise Integration Patterns（企业集成模式）中的核心模式。发布者不知道谁在订阅，订阅者不知道发布者的实现细节，两者通过消息通道完全解耦。

在Kafka中的实践：`order-service`发布`OrderPlaced`事件到Kafka Topic，`portfolio-service`、`audit-service`、`notification-service`各自独立消费，互不影响。

**核心价值**：

1. **故障隔离**：portfolio-service宕机不影响下单，重启后从Kafka消费未处理的事件即可"追平"。
2. **易扩展**：新增订阅者只需订阅Topic，无需修改发布者代码（开闭原则）。
3. **事件回放**：Kafka保留历史消息，可以重新消费历史事件修复数据问题。

---

### Q9. How do you use Redis in a microservices system? What problems does it solve?

### 问题9：在微服务系统中如何使用 Redis？它解决了什么问题？

**English Answer:**

We use Redis in several ways:

1. **Session cache / JWT token store**
   After a user logs in, we store their session in Redis with a TTL (e.g., 30 minutes). All microservices can check Redis to validate the token — no need to call the user-service every time.

2. **Database query cache**
   Fund information (prices, names) does not change every second. We cache it in Redis for 60 seconds. This reduces the load on Aurora by 80-90% for read-heavy endpoints.
   
   ```java
   @Cacheable(value = "fund-price", key = "#fundCode")
   public FundPrice getFundPrice(String fundCode) {
       return fundRepository.findByCode(fundCode); // only called if not in cache
   }
   ```

3. **Distributed lock**
   If two pods try to update the same user's portfolio at the same time, we can use a Redis lock (Redisson) to make sure only one runs at a time.

4. **Rate limiting**
   Use Redis `INCR` + `EXPIRE` to count API calls per user per minute. Block users who send too many requests.

**中文解释：**

Redis在微服务中的4种典型用途：

1. **会话缓存**：用户登录后把Session/JWT存Redis（带TTL），所有服务验证token时查Redis，避免每次都请求user-service。
2. **查询缓存**：基金净值等读多写少的数据缓存到Redis（60秒TTL），Spring Boot用`@Cacheable`注解一行搞定，大幅降低数据库压力。
3. **分布式锁**：多Pod并发修改同一用户数据时，用Redisson的分布式锁保证串行执行，防止数据竞争。
4. **限流计数器**：用`INCR` + `EXPIRE`实现API频率限制，防止接口被滥用。

---

### Q10. What do you look for when doing a code review?

### 问题10：做 Code Review 时，你重点关注哪些方面？

**English Answer:**

I look at five areas when reviewing code:

1. **Correctness — does it work?**
   
   - Does the logic handle edge cases? (null input, empty list, negative numbers)
   - Are there off-by-one errors in loops?
   - Is the transaction boundary correct? (Does `@Transactional` cover the right methods?)

2. **Security — is it safe?**
   
   - Any SQL injection risk? (Is the developer using `JdbcTemplate` with `?` placeholders, not string concatenation?)
   - Is sensitive data (passwords, card numbers) being logged?
   - Are authorization checks in the right place?

3. **Design — is it clean?**
   
   - Does the method do only one thing? (Single Responsibility)
   - Are variable names clear? (`userList` not `list1`)
   - Is there duplicated code that should be extracted to a shared method?

4. **Test coverage — is it tested?**
   
   - Is there a unit test for the new logic?
   - Does the test cover the happy path and at least one error path?

5. **Performance — will it scale?**
   
   - Is there an N+1 query problem? (Calling the database inside a loop)
   - Are database indexes used correctly?

**中文解释：**

Code Review五个维度：

1. **正确性**：边界条件（null、空集合）、事务边界（`@Transactional`范围是否正确）、并发安全。
2. **安全性**：SQL注入（要用参数化查询）、敏感信息不能进日志、权限校验位置是否正确。
3. **设计质量**：单一职责（一个方法只做一件事）、命名是否清晰、有无重复代码需要抽取。
4. **测试覆盖**：新逻辑有没有单元测试，有没有覆盖异常分支。
5. **性能**：有没有N+1查询（在循环里查数据库）、分页是否正确（避免一次加载全量数据）。

回答这道题时，可以提一个自己发现过的真实Bug，面试官印象会很深刻。

---

### Q11. What is the Circuit Breaker pattern? Why is it important in a microservices system?

### 问题11：什么是断路器模式？它在微服务中为什么重要？

**English Answer:**

In a microservices system, services call each other. If `portfolio-service` calls `fund-service` and `fund-service` is slow or down, `portfolio-service` will keep waiting. Soon all its threads are stuck waiting. Then `portfolio-service` becomes slow too. This problem spreads through the whole system — it is called a **cascading failure**.

**Circuit Breaker** stops this from happening. It works like an electrical circuit breaker in your house:

- **Closed (normal)**: requests pass through normally.
- **Open (tripped)**: after 5 failures in a row, the circuit breaker "trips." All requests **immediately fail fast** with a fallback response (e.g., return cached data or an error message). No more waiting.
- **Half-open (testing)**: after 30 seconds, one test request is allowed through. If it succeeds, the circuit closes again.

```java
// Spring Boot 3 + Resilience4j
@CircuitBreaker(name = "fundService", fallbackMethod = "getFundPriceFallback")
public FundPrice getFundPrice(String fundCode) {
    return fundClient.getPrice(fundCode); // external call
}

public FundPrice getFundPriceFallback(String fundCode, Exception ex) {
    return cache.getLastKnownPrice(fundCode); // return stale cache instead of failing
}
```

**中文解释：**

微服务级联故障的场景：A服务调B服务，B服务变慢，A的线程全部阻塞在等待B，A也变慢，C依赖A也开始变慢——整个系统雪崩。

断路器（Circuit Breaker）是防雪崩的核心手段：

- **Closed（关闭/正常）**：请求正常通过。
- **Open（打开/断路）**：连续失败N次后断路，后续请求直接走fallback（返回缓存数据或友好错误），不再等待，防止资源耗尽。
- **Half-Open（半开/探测）**：断路后等待一段时间，放一个探测请求，成功则恢复正常，失败继续断路。

在Spring Boot 3中通常用**Resilience4j**实现（Hystrix已停止维护）。

---

## Part 2 — High Availability & Disaster Recovery

## 第二部分：高可用 / 两岸三中心

---

### Q12. Can you explain what "two regions, three centers" means in your system?

### 问题12：请解释你们系统的"两岸三中心"设计是什么？

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

### Q13. What is RTO and RPO? What are your targets?

### 问题13：什么是 RTO 和 RPO？你们的目标是什么？

**English Answer:**

- **RTO (Recovery Time Objective)** = "How fast can we restart?" — the maximum time we allow the system to be down.
- **RPO (Recovery Point Objective)** = "How much data can we lose?" — the maximum data loss we can accept.

| Failure Type                    | RTO      | RPO     | How We Do It                                      |
| ------------------------------- | -------- | ------- | ------------------------------------------------- |
| One Pod crashes                 | < 30 sec | 0       | Kubernetes restarts it automatically              |
| One Node fails                  | < 2 min  | 0       | Cluster Autoscaler adds a new Node                |
| One AZ goes down                | < 5 min  | 0       | Pods are spread across 3 AZs; Aurora has Multi-AZ |
| Singapore region fails          | < 15 min | < 5 min | Promote Hong Kong Aurora to primary; redeploy EKS |
| Someone deletes data by mistake | < 30 min | < 5 min | Aurora PITR (Point-in-Time Recovery)              |

**中文解释：**

- **RTO（恢复时间目标）**：系统宕机后，最多允许多长时间恢复服务。
- **RPO（恢复点目标）**：最多允许丢失多长时间的数据。

关键设计：Aurora Global Database 的跨区复制延迟 < 1秒，所以香港的数据几乎是实时的，RPO < 5分钟。

---

### Q14. How does your system stay available when one Availability Zone (AZ) goes down?

### 问题14：当一个可用区（AZ）宕机时，系统如何保持可用？

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

### Q15. If Singapore is completely down, how do you switch to Hong Kong?

### 问题15：如果新加坡整个Region宕机，如何切换到香港？

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

### Q16. Why do you put NAT Gateways in public subnets, but EKS and Aurora in private subnets?

### 问题16：为什么 NAT Gateway 放在公有子网，而 EKS 和 Aurora 放在私有子网？

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

## Part 3 — EKS & Microservices

## 第三部分：EKS 与微服务

---

### Q17. Why did you choose EKS instead of ECS Fargate?

### 问题17：为什么选择 EKS 而不是 ECS Fargate？

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

### Q18. What is IRSA and why is it better than putting AWS keys in the code?

### 问题18：什么是 IRSA？为什么比把 AWS 密钥放在代码里更好？

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

### Q19. How does the system handle a sudden traffic spike, like 10x more users?

### 问题19：如果流量突然增加10倍，系统如何应对？

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

## Part 4 — Security

## 第四部分：安全设计

---

### Q20. How does the system protect against DDoS attacks?

### 问题20：系统如何防御 DDoS 攻击？

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

### Q21. How does the system store and protect passwords and secrets?

### 问题21：系统如何存储和保护密码、密钥等敏感信息？

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

### Q22. Someone on your team accidentally pushes a bad Docker image to production. How does the system catch this?

### 问题22：如果团队成员不小心把有问题的 Docker 镜像推送到了生产环境，系统如何防御？

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

## Part 5 — Database Design

## 第五部分：数据库设计

---

### Q23. Why did you choose Aurora PostgreSQL instead of regular RDS PostgreSQL?

### 问题23：为什么选择 Aurora PostgreSQL 而不是普通的 RDS PostgreSQL？

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

### Q24. What problem does RDS Proxy solve?

### 问题24：RDS Proxy 解决了什么问题？

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

## Part 6 — CI/CD & GitOps

## 第六部分：CI/CD 与 GitOps

---

### Q25. Can you walk me through what happens when a developer merges code to main?

### 问题25：当开发者把代码合并到 main 分支时，发生了什么？请走一遍流程。

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

### Q26. What is a "canary deployment"? Why do you use it instead of releasing to all users at once?

### 问题26：什么是"金丝雀发布"？为什么不直接发布给所有用户？

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

## Part 7 — Observability

## 第七部分：可观测性

---

### Q27. If a user says "the system is slow," how do you find out what's wrong?

### 问题27：如果用户说"系统很慢"，你如何找到问题所在？

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

| Technology        | Why We Chose It                                        | Why Not the Alternative                            |
| ----------------- | ------------------------------------------------------ | -------------------------------------------------- |
| EKS               | Network Policy, PDB, full K8s ecosystem                | ECS Fargate: less control, no Network Policy       |
| Aurora PostgreSQL | 30s failover, Global DB, auto storage                  | Regular RDS: slower failover, no Global DB         |
| RDS Proxy         | Connection pooling, transparent failover               | Direct connection: connection limit, slow failover |
| IRSA              | No long-lived credentials, per-service least privilege | Hard-coded AK/SK: security risk, key rotation pain |
| ArgoCD GitOps     | Git as source of truth, drift detection, audit trail   | kubectl apply: no audit, no drift detection        |
| Secrets Store CSI | Secrets never in K8s Secret (base64 only)              | K8s Secret: base64 is not encryption               |
| CloudFront + WAF  | Edge protection, DDoS absorption, geo-restriction      | Direct ALB exposure: no edge protection            |
| Canary Deployment | Max 10% users affected if bug found                    | Big-bang: 100% users affected                      |

---

> **面试小贴士**：
> 
> - 每个技术选型都要说"为什么选它，为什么不选另一个"（trade-off）。
> - 两岸三中心优先讲RTO/RPO数字，面试官印象深刻。
> - 遇到不会的，说"In our current design we did X, but if I had more time I would also consider Y"。

---

## Part 8 — Capacity & Numbers（QPS / Latency / Scale）

## 第八部分：容量设计题 — "你们系统的 QPS 是多少？"

> 这类题的本质：面试官想看你**推算思路**，而不是背一个数字。  
> 答题公式：**估算用户规模 → 推算并发 → 算出 QPS → 说明架构能否支撑 → 说出扩容方案**

---

### Q28. What is the QPS of your system? How did you design for it?

### 问题28：你们系统的 QPS 是多少？是怎么设计和支撑的？

**English Answer:**

I will walk you through how I estimated the QPS, then explain how the architecture handles it.

**Step 1 — Estimate the user base**

Flex Invest is a fund investment platform. It is not a high-frequency stock trading app. Users check their portfolio and browse funds — they do not click hundreds of times per second.

| Metric                       | Estimate | Reasoning                                |
| ---------------------------- | -------- | ---------------------------------------- |
| Registered users             | 500,000  | Medium-sized financial platform          |
| Daily Active Users (DAU)     | 50,000   | ~10% of registered users log in each day |
| Peak concurrent users        | 5,000    | ~10% of DAU are online at the same time  |
| Requests per user per minute | 3        | One click every 20 seconds on average    |

**Step 2 — Calculate peak QPS**

```
Peak QPS = concurrent users × requests per minute / 60 seconds
         = 5,000 × 3 / 60
         ≈ 250 QPS  (total across all services)
```

Breaking it down by service:

| Service           | QPS      | Why                              |
| ----------------- | -------- | -------------------------------- |
| portfolio-service | ~100 QPS | Most users check portfolio first |
| fund-service      | ~80 QPS  | Browsing fund list and details   |
| order-service     | ~30 QPS  | People don't trade every second  |
| user-service      | ~20 QPS  | Login + profile update           |
| plan-service      | ~20 QPS  | Investment plan management       |

**Peak spikes:** Around market close (3pm Singapore time), order QPS can jump **5-10x** — up to 150-300 QPS just for order-service.

**Step 3 — How the architecture handles it**

| Layer                      | Capacity        | Our Load         | Headroom      |
| -------------------------- | --------------- | ---------------- | ------------- |
| CloudFront (static)        | Unlimited (CDN) | ~60% of requests | ✅ Infinite    |
| ALB                        | ~1M connections | 5,000            | ✅ 200x margin |
| EKS (per service, 20 pods) | ~2,000 QPS      | ~250 QPS peak    | ✅ 8x margin   |
| Aurora (RDS Proxy)         | ~5,000 TPS      | ~30 TPS writes   | ✅ 166x margin |
| ElastiCache Redis          | ~100,000 ops/s  | ~500 ops/s       | ✅ 200x margin |

**Step 4 — If traffic grows 10x**

HPA automatically scales each service from 2 pods to 20 pods. Karpenter adds new EC2 nodes in ~60 seconds. For sustained 10x load we would also upgrade Aurora reader instances and add Redis memory.

**中文解释：**

**QPS估算公式（背下来）：**

```
注册用户(500K) × DAU比例(10%) = 5万日活
5万日活 × 峰值在线比例(10%) = 5千并发
5千并发 × 每分钟3次请求 / 60秒 ≈ 250 QPS
```

下午3点收盘尖峰时 order-service 可达 300 QPS。EKS 20个Pod上限约2000 QPS，**现有负载的8倍冗余**。

**关键话术**："We designed for 10x peak capacity because in financial systems, downtime during market close is not acceptable."

---

### Q29. What is the P99 latency requirement? How do you measure it?

### 问题29：P99 延迟要求是多少？你怎么测量的？

**English Answer:**

**P99** means: if we sort all requests by response time, P99 is the 99th percentile — 99% of requests finish faster than this number.

Our latency targets:

| API Type                         | P50 (median) | P99 target | Why                                      |
| -------------------------------- | ------------ | ---------- | ---------------------------------------- |
| Portfolio read (Redis cache hit) | < 20ms       | < 100ms    | Redis is in-memory                       |
| Portfolio read (Aurora query)    | < 100ms      | < 300ms    | Database query                           |
| Fund browse (cached)             | < 50ms       | < 200ms    | Redis cache                              |
| Order placement                  | < 200ms      | < 500ms    | Writes to Aurora + publishes Kafka event |
| User login                       | < 100ms      | < 300ms    | JWT generation + Redis session           |

**How we measure:**

1. **Prometheus + Grafana** — Spring Boot Actuator auto-records latency histograms. Grafana shows P50/P95/P99 per endpoint in real time.
2. **AWS X-Ray** — when P99 is high, X-Ray traces show exactly which step is slow (DB query? Redis? External API?).
3. **JMeter load tests** — before every release, we simulate 10x peak and verify P99 stays within target.

Alert: if P99 > 1 second on any endpoint, PagerDuty pages the on-call engineer.

**中文解释：**

**P99 = 99%的请求在这个时间内完成**，比平均值更有意义（平均值会被少数超快请求拉低）。

目标：读接口（Redis缓存）P99 < 100ms，写接口（下单）P99 < 500ms。监控工具：Prometheus采集延迟直方图，Grafana展示，X-Ray定位慢点，JMeter压测验证。P99 > 1秒触发PagerDuty告警。

---

### Q30. How much data does your system store? How fast does it grow?

### 问题30：你们系统存了多少数据？增长速度是多少？

**English Answer:**

| Data Type                   | Size       | Monthly Growth                          |
| --------------------------- | ---------- | --------------------------------------- |
| User profiles (500K users)  | ~3.5 GB    | ~10 MB                                  |
| Portfolio snapshots (daily) | ~5 GB      | ~200 MB                                 |
| Order history               | ~10 GB     | ~500 MB                                 |
| Fund data (prices, info)    | ~2 GB      | ~100 MB                                 |
| **Total Aurora data**       | **~20 GB** | **~800 MB**                             |
| Application logs            | ~5 GB/day  | CloudWatch 90 days → S3 Glacier 7 years |
| Audit trail (CloudTrail)    | ~1 GB/day  | S3 Object Lock, 7-year retention        |

Key points:

- 20 GB is tiny for Aurora (max 128 TB). No storage pressure.
- **Logs are the biggest cost driver.** We use S3 Lifecycle rules to move logs to Glacier after 90 days — cost drops 10x.
- 7-year audit retention is a **regulatory requirement** for financial systems, not optional.

**中文解释：**

Aurora 总数据量约 **20GB**，每月增长约 800MB，对 Aurora 微不足道（上限128TB）。最大存储消耗是日志（5GB/天），90天后归档到 S3 Glacier（成本降低10倍），满足金融监管7年合规保留要求。

---

### Q31. Have you done load testing? How did you do it?

### 问题31：你们做过压力测试吗？怎么做的？

**English Answer:**

Yes. We run load tests before every major release using **JMeter**. Four test levels:

| Test Level  | Users            | Duration | Goal                                            |
| ----------- | ---------------- | -------- | ----------------------------------------------- |
| Smoke test  | 10               | 5 min    | Basic sanity — nothing is broken                |
| Load test   | 500 (2× peak)    | 30 min   | P99 latency stays within target                 |
| Stress test | 5,000 (10× peak) | 15 min   | Find the breaking point; verify HPA fires       |
| Soak test   | 300              | 8 hours  | Find memory leaks or connection pool exhaustion |

**What we check in each run:**

- P99 < 1 second
- Error rate < 0.1%
- HPA scales pods from 2 → 20 as CPU rises
- No `OutOfMemoryError` after 8 hours
- No "too many connections" error from Aurora (proves RDS Proxy works)

**中文解释：**

压测4个阶段：

1. **冒烟**（10用户/5分钟）：验证基本功能。
2. **负载**（500用户/30分钟，2倍峰值）：验证P99达标。
3. **压力**（5000用户，10倍峰值）：找到系统瓶颈，验证HPA自动扩容。
4. **稳定性**（300用户/8小时）：排查内存泄漏和连接池耗尽。

重点指标：P99 < 1秒，错误率 < 0.1%，HPA正常触发，Aurora无连接超限报错。

---

### Q32. How do you handle a sudden 10x traffic spike — like a big marketing campaign?

### 问题32：如果突然来了10倍流量（比如一个大型营销活动），你们怎么应对？

**English Answer:**

Two strategies: **reactive** (automatic) and **proactive** (planned ahead).

**Reactive — Auto-scaling (always on):**

- HPA detects CPU > 60%, adds pods in ~15 seconds (up to 20 pods per service)
- Karpenter detects "Pending" pods, adds new EC2 node in ~60 seconds
- For a 10x spike, HPA scales from 2 → 20 pods automatically

**Proactive — Pre-warm before a known campaign:**

1. Set `minReplicas: 10` in HPA 1 hour before the campaign starts
2. Add one Aurora read replica to handle read-heavy traffic
3. Increase Redis memory for higher cache throughput
4. CloudFront handles static assets at unlimited scale — no action needed

**Safety net:**

- WAF rate limiting: blocks any single IP sending > 1,000 requests in 5 minutes
- Circuit breakers prevent one slow service from cascading to others

**中文解释：**

**被动（自动）**：HPA 15秒内扩Pod（最多20个），Karpenter 60秒内加Node，10倍流量基本可以自动吸收。

**主动（已知活动）**：活动前提前把 `minReplicas` 调高，加 Aurora 读副本，扩 Redis 内存，避免冷启动延迟。

兜底：WAF 频率限制（1000次/5分钟/IP）+ 各服务间断路器防雪崩。

---

### Q33. What is your database connection pool size? How did you decide on the number?

### 问题33：你们的数据库连接池大小是多少？怎么定的？

**English Answer:**

**The math:**

```
5 services × 20 pods (max) × 10 HikariCP connections = 1,000 connections to Aurora
Aurora db.r6g.large supports ~800–1,000 connections maximum
```

Without RDS Proxy, we would hit Aurora's connection limit during scale-out. That is why **RDS Proxy is mandatory**.

**With RDS Proxy:**

- All 1,000 pod connections go to RDS Proxy
- RDS Proxy maintains a fixed pool of 500 connections to Aurora
- Even if we scale to 50 pods, the Aurora connection count stays at 500

**HikariCP settings per pod:**

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10       # max 10 connections per pod
      minimum-idle: 2             # keep 2 warm connections always
      connection-timeout: 3000    # fail fast — 3 seconds, not hang forever
      idle-timeout: 300000        # close idle connections after 5 minutes
```

`connection-timeout: 3000` is important: if no connection is available, the request fails fast after 3 seconds instead of hanging forever and blocking a thread.

**中文解释：**

**计算**：5服务 × 20Pod × 10连接 = 1000，正好撞 Aurora 上限（约1000）。

**RDS Proxy 的必要性**：所有 Pod 连接指向 RDS Proxy，Proxy 维护到 Aurora 的固定连接池（500个），无论 Pod 怎么扩，Aurora 始终只看到500个连接，不会超限。

**HikariCP 关键参数**：`maximum-pool-size=10`（每Pod10个），`connection-timeout=3000`（3秒等不到连接直接抛异常，快速失败比无限等待强得多）。

---

## Quick Reference — Key Technology Choices

## 快速参考：核心技术选型理由

| Technology        | Why We Chose It                                        | Why Not the Alternative                            |
| ----------------- | ------------------------------------------------------ | -------------------------------------------------- |
| EKS               | Network Policy, PDB, full K8s ecosystem                | ECS Fargate: less control, no Network Policy       |
| Aurora PostgreSQL | 30s failover, Global DB, auto storage                  | Regular RDS: slower failover, no Global DB         |
| RDS Proxy         | Connection pooling, transparent failover               | Direct connection: connection limit, slow failover |
| IRSA              | No long-lived credentials, per-service least privilege | Hard-coded AK/SK: security risk, key rotation pain |
| ArgoCD GitOps     | Git as source of truth, drift detection, audit trail   | kubectl apply: no audit, no drift detection        |
| Secrets Store CSI | Secrets never stored in K8s Secret (base64 only)       | K8s Secret: base64 is not encryption               |
| CloudFront + WAF  | Edge protection, DDoS absorption, geo-restriction      | Direct ALB exposure: no edge protection            |
| Canary Deployment | Max 10% users affected if a bug is found               | Big-bang: 100% users affected                      |

---

> **面试小贴士**：
> 
> - 每个技术选型都要说"为什么选它，为什么不选另一个"（trade-off）。
> - 两岸三中心优先讲 RTO/RPO 数字，面试官印象深刻。
> - 容量题不要背数字，要说推导过程：用户数 → DAU → 并发 → QPS。
> - 遇到不会的，说"In our current design we did X, but if I had more time I would also consider Y"。
