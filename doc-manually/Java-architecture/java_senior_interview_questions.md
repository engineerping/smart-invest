# Java 高级开发工程师面试题库
# Java Senior Developer Interview Question Bank

> 按考频从高到低排序，同类问题归组
> Sorted by frequency (high to low), grouped by category

---

## 目录 / Table of Contents

1. [Java 基础与核心 / Java Core Fundamentals](#1-java-基础与核心--java-core-fundamentals)
2. [多线程与并发 / Multithreading & Concurrency](#2-多线程与并发--multithreading--concurrency)
3. [JVM 虚拟机 / JVM Internals](#3-jvm-虚拟机--jvm-internals)
4. [Spring 全家桶 / Spring Ecosystem](#4-spring-全家桶--spring-ecosystem)
5. [Spring Cloud 与微服务 / Spring Cloud & Microservices](#5-spring-cloud-与微服务--spring-cloud--microservices)
6. [中间件 / Middleware](#6-中间件--middleware)
7. [数据库设计与调优 / Database Design & Tuning](#7-数据库设计与调优--database-design--tuning)
8. [分布式系统设计 / Distributed System Design](#8-分布式系统设计--distributed-system-design)
9. [设计模式 / Design Patterns](#9-设计模式--design-patterns)
10. [性能调优 / Performance Tuning](#10-性能调优--performance-tuning)
11. [通讯协议与加解密 / Protocols & Cryptography](#11-通讯协议与加解密--protocols--cryptography)
12. [系统化思维与架构设计 / Systematic Thinking & Architecture](#12-系统化思维与架构设计--systematic-thinking--architecture)

---

## 1. Java 基础与核心 / Java Core Fundamentals

---

### Q1 ⭐⭐⭐⭐⭐
**问：解释 HashMap 的底层实现原理，JDK 8 做了哪些优化？**

**EN: Explain the internal implementation of HashMap. What optimizations were introduced in JDK 8?**

**答 / Answer:**

JDK 7 及之前，HashMap 使用 **数组 + 链表** 结构。每个 key 通过 `hashCode()` 计算 index，冲突时用链表（头插法）存储。

JDK 8 的主要优化：
- 数据结构改为 **数组 + 链表 + 红黑树**：当链表长度 ≥ 8 且数组容量 ≥ 64 时，链表自动转为红黑树，查询时间复杂度从 O(n) 降至 O(log n)。
- 插入方式改为**尾插法**，避免并发扩容时的死循环问题。
- `hash()` 函数优化：`(key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16)`，减少碰撞。
- 扩容时不需要重新计算 hash，只需判断高位 bit 是 0 还是 1 来决定新位置。

**默认参数：** 初始容量 16，负载因子 0.75，阈值 = 容量 × 负载因子。

---

### Q2 ⭐⭐⭐⭐⭐
**问：== 和 equals() 的区别？String 的 intern() 方法是什么？**

**EN: What is the difference between == and equals()? What does String.intern() do?**

**答 / Answer:**

- `==`：比较引用地址（基本类型比较值）。
- `equals()`：默认同 `==`，但 String、Integer 等已重写为比较内容。

`String.intern()`：将字符串加入常量池并返回其引用。若常量池中已存在，直接返回已有引用。可节省内存，但大量使用可能导致常量池溢出（PermGen/Metaspace）。

```java
String a = new String("hello");
String b = a.intern();
String c = "hello";
System.out.println(b == c); // true
```

---

### Q3 ⭐⭐⭐⭐⭐
**问：Java 中的四种引用类型是什么？分别用于什么场景？**

**EN: What are the four reference types in Java? What are their use cases?**

**答 / Answer:**

| 类型 | 回收时机 | 典型场景 |
|------|----------|----------|
| 强引用 StrongReference | GC 不回收 | 普通对象 |
| 软引用 SoftReference | 内存不足时回收 | 缓存（图片缓存） |
| 弱引用 WeakReference | 下次 GC 必回收 | ThreadLocal、WeakHashMap |
| 虚引用 PhantomReference | 随时可回收，需配合队列 | 跟踪对象被回收的时机，DirectByteBuffer 清理 |

---

### Q4 ⭐⭐⭐⭐
**问：说说 Java 异常体系，checked exception 和 unchecked exception 的区别？**

**EN: Describe Java's exception hierarchy. What is the difference between checked and unchecked exceptions?**

**答 / Answer:**

```
Throwable
├── Error（不可恢复，如 OutOfMemoryError）
└── Exception
    ├── RuntimeException（unchecked）
    │   ├── NullPointerException
    │   ├── IllegalArgumentException
    │   └── ...
    └── Checked Exception（必须捕获或声明）
        ├── IOException
        └── SQLException
```

- **Checked**：编译器强制处理，适合可预期的外部错误（如文件不存在）。
- **Unchecked**（RuntimeException）：编程错误，无需强制捕获，如空指针、数组越界。

实际项目中建议：自定义业务异常继承 `RuntimeException`，统一通过全局异常处理器（`@ControllerAdvice`）捕获。

---

### Q5 ⭐⭐⭐⭐
**问：Java 的 SPI 机制是什么？与 API 有什么区别？**

**EN: What is Java's SPI mechanism? How does it differ from API?**

**答 / Answer:**

**SPI（Service Provider Interface）** 是 Java 的服务发现机制，允许第三方为接口提供实现，实现框架的可插拔扩展。

实现步骤：
1. 定义接口
2. 实现类放在 `META-INF/services/接口全限定名` 文件中
3. 用 `ServiceLoader.load()` 加载

典型应用：JDBC Driver、SLF4J、Dubbo 扩展点、Spring Boot `spring.factories`。

区别：API 是调用方调用服务端的接口；SPI 是框架定义接口，调用方提供实现。

---

### Q6 ⭐⭐⭐
**问：泛型的类型擦除是什么？会带来什么问题？**

**EN: What is type erasure in generics? What problems can it cause?**

**答 / Answer:**

Java 泛型在编译后会将类型参数擦除，运行时 `List<String>` 和 `List<Integer>` 都是 `List`。

带来的问题：
- 无法在运行时获取泛型参数类型（`new T()` 非法）
- 无法做 `instanceof` 泛型判断
- 方法重载时 `void method(List<String>)` 和 `void method(List<Integer>)` 编译报错（擦除后签名相同）

解决方案：通过 `TypeToken`（Guava）或传入 `Class<T>` 对象来保留类型信息。

---

## 2. 多线程与并发 / Multithreading & Concurrency

---

### Q7 ⭐⭐⭐⭐⭐
**问：synchronized 和 ReentrantLock 的区别？各自适合什么场景？**

**EN: What are the differences between synchronized and ReentrantLock? When should each be used?**

**答 / Answer:**

| 特性 | synchronized | ReentrantLock |
|------|-------------|---------------|
| 实现层面 | JVM 关键字（monitorenter/exit） | JDK 类（AQS） |
| 锁的获取 | 自动 | 手动（需 finally unlock） |
| 可中断 | 不支持 | 支持（lockInterruptibly） |
| 公平锁 | 不支持 | 支持（new ReentrantLock(true)） |
| 条件变量 | wait/notify（单一） | Condition（多个） |
| 性能 | JDK 6 后差距不大 | 高竞争场景略优 |

**选择原则：** 简单场景用 synchronized（JIT 可自动优化偏向锁/轻量锁）；需要高级特性（超时、中断、多条件）时用 ReentrantLock。

---

### Q8 ⭐⭐⭐⭐⭐
**问：ThreadLocal 的原理是什么？内存泄漏如何产生？如何避免？**

**EN: How does ThreadLocal work? How do memory leaks occur and how to prevent them?**

**答 / Answer:**

每个 `Thread` 内部持有一个 `ThreadLocalMap`，key 是 `ThreadLocal` 对象的**弱引用**，value 是存储的值。

**内存泄漏原因：** 线程池中线程不销毁，ThreadLocal 对象被 GC 回收后 key 变为 null，但 value 仍被强引用保留，无法回收。

**避免方法：**
```java
try {
    threadLocal.set(value);
    // 业务逻辑
} finally {
    threadLocal.remove(); // 必须显式 remove
}
```

使用线程池时，每次任务结束都要调用 `remove()`。

---

### Q9 ⭐⭐⭐⭐⭐
**问：什么是 AQS？请解释其核心原理。**

**EN: What is AQS? Explain its core principles.**

**答 / Answer:**

`AbstractQueuedSynchronizer`（AQS）是 Java 并发包的核心基础框架，`ReentrantLock`、`Semaphore`、`CountDownLatch`、`CyclicBarrier` 都基于它实现。

**核心设计：**
- 一个 `volatile int state` 表示同步状态
- 一个 CLH（FIFO）双向队列存放阻塞线程
- 子类通过重写 `tryAcquire()`/`tryRelease()` 定义加锁逻辑

**独占模式（ReentrantLock）：**
1. `acquire()` → `tryAcquire()` 失败 → 加入等待队列 → `LockSupport.park()` 阻塞
2. 释放时 `release()` → `tryRelease()` → 唤醒队首节点

**共享模式（Semaphore）：** 多个线程可同时持有，`state` 表示可用许可数。

---

### Q10 ⭐⭐⭐⭐⭐
**问：volatile 关键字的作用是什么？能保证原子性吗？**

**EN: What does the volatile keyword do? Does it guarantee atomicity?**

**答 / Answer:**

`volatile` 的两个作用：
1. **可见性**：写操作立即刷新到主内存，读操作从主内存读取，不走 CPU 缓存。
2. **禁止指令重排**：通过内存屏障（Memory Barrier）实现，保证有序性。

**不能保证原子性：**
```java
volatile int i = 0;
i++; // 非原子，等价于 read + add + write 三步
```
需要原子操作时使用 `AtomicInteger`、`synchronized` 或 `Lock`。

**典型用法：** 状态标志位（`volatile boolean running`）、DCL 双检锁单例。

---

### Q11 ⭐⭐⭐⭐
**问：线程池的核心参数有哪些？拒绝策略有哪几种？**

**EN: What are the core parameters of a thread pool? What rejection policies exist?**

**答 / Answer:**

**核心参数（ThreadPoolExecutor）：**
| 参数 | 含义 |
|------|------|
| corePoolSize | 核心线程数（常驻） |
| maximumPoolSize | 最大线程数 |
| keepAliveTime | 空闲线程存活时间 |
| workQueue | 任务队列（LinkedBlockingQueue / SynchronousQueue / ArrayBlockingQueue） |
| threadFactory | 线程工厂 |
| handler | 拒绝策略 |

**四种拒绝策略：**
- `AbortPolicy`（默认）：直接抛出 `RejectedExecutionException`
- `CallerRunsPolicy`：由提交任务的线程自己执行（降速）
- `DiscardPolicy`：静默丢弃
- `DiscardOldestPolicy`：丢弃队列最老任务，重试提交

**最佳实践：** 避免使用 `Executors` 工厂方法（可能 OOM），手动配置 ThreadPoolExecutor 并命名线程。

---

### Q12 ⭐⭐⭐⭐
**问：ConcurrentHashMap 在 JDK 8 中的实现原理？**

**EN: How is ConcurrentHashMap implemented in JDK 8?**

**答 / Answer:**

JDK 7 使用 **Segment 分段锁**（16个segment，每个是独立的 ReentrantLock）。

JDK 8 改为 **CAS + synchronized**：
- 结构同 HashMap：数组 + 链表 + 红黑树
- 写操作：若桶为空，用 CAS 插入；若不为空，对桶头节点加 synchronized 锁
- 读操作：无锁（`volatile` 保证可见性）
- size 计算：采用 `LongAdder` 思想（分格累加），避免竞争

优势：锁粒度更细（从 Segment 级别降到 Node 级别），并发度更高。

---

### Q13 ⭐⭐⭐
**问：什么是死锁？如何检测和避免？**

**EN: What is a deadlock? How to detect and prevent it?**

**答 / Answer:**

**死锁四个必要条件：**
1. 互斥（资源不可共享）
2. 占有并等待（持有资源再申请）
3. 不可抢占（资源不能被强制释放）
4. 循环等待（A 等 B，B 等 A）

**检测：** `jstack <pid>` 可以看到死锁信息；`ThreadMXBean.findDeadlockedThreads()`。

**避免策略：**
- 固定锁获取顺序
- 使用 `tryLock(timeout)` 超时放弃
- 减少锁的持有时间和粒度
- 使用 Lock-Free 数据结构

---

### Q14 ⭐⭐⭐
**问：Java 内存模型（JMM）是什么？happens-before 原则有哪些？**

**EN: What is the Java Memory Model (JMM)? What are the happens-before rules?**

**答 / Answer:**

JMM 定义了多线程程序中变量读写的规范，屏蔽了不同硬件和操作系统的内存访问差异。

**主要 happens-before 规则：**
1. 程序顺序规则：同一线程，前面操作 happens-before 后面
2. Monitor 锁规则：unlock happens-before 后续 lock
3. volatile 规则：写 happens-before 后续读
4. 线程启动规则：`start()` happens-before 线程内所有操作
5. 线程终止规则：所有操作 happens-before `join()` 返回
6. 传递性：A hb B，B hb C → A hb C

---

## 3. JVM 虚拟机 / JVM Internals

---

### Q15 ⭐⭐⭐⭐⭐
**问：JVM 内存区域是如何划分的？各区域存什么？**

**EN: How is JVM memory divided? What does each area store?**

**答 / Answer:**

**线程私有：**
- **程序计数器（PC Register）**：当前线程执行的字节码行号
- **虚拟机栈（VM Stack）**：栈帧（局部变量表、操作数栈、动态链接）
- **本地方法栈（Native Method Stack）**：Native 方法调用

**线程共享：**
- **堆（Heap）**：对象实例、数组；GC 的主要区域
  - 新生代（Eden + S0 + S1）
  - 老年代（Old Gen）
- **方法区（Method Area）**：类信息、常量、静态变量、JIT 编译代码
  - JDK 7：PermGen（永久代）
  - JDK 8+：Metaspace（使用本地内存）

**直接内存（Direct Memory）**：NIO ByteBuffer 使用，不受 JVM GC 直接管理。

---

### Q16 ⭐⭐⭐⭐⭐
**问：GC 垃圾回收算法有哪些？G1 和 CMS 的区别？**

**EN: What GC algorithms exist? What are the differences between G1 and CMS?**

**答 / Answer:**

**基础算法：**
- 标记-清除（Mark-Sweep）：产生碎片
- 标记-整理（Mark-Compact）：无碎片，STW 较长
- 复制算法（Copying）：新生代使用，空间利用率 50%

**CMS（Concurrent Mark Sweep）：**
- 目标：最短 STW 停顿
- 流程：初始标记(STW) → 并发标记 → 重新标记(STW) → 并发清除
- 缺点：产生碎片（Concurrent Mode Failure 时 Full GC）、浮动垃圾

**G1（Garbage First）：**
- 将堆划分为等大小 Region（1~32MB）
- 优先回收垃圾最多的 Region
- 可预测停顿时间（`-XX:MaxGCPauseMillis`）
- JDK 9+ 默认收集器

**选择建议：** 响应时间敏感用 G1 或 ZGC；吞吐量优先用 Parallel GC。

---

### Q17 ⭐⭐⭐⭐
**问：什么是类加载机制？双亲委派模型的作用是什么？**

**EN: What is the class loading mechanism? What is the purpose of the parent delegation model?**

**答 / Answer:**

**类加载过程：** 加载 → 验证 → 准备 → 解析 → 初始化

**双亲委派模型：**
- Bootstrap ClassLoader → Extension ClassLoader → Application ClassLoader
- 加载时先委托父类，父类找不到才自己加载

**作用：**
1. **安全性**：防止自定义类替换核心类（如自定义 `java.lang.String`）
2. **唯一性**：同一类只被加载一次

**打破双亲委派的场景：**
- JNDI、JDBC（SPI 机制需要子加载器加载实现类）
- Tomcat（Web 应用隔离）
- OSGi（模块化）
- JDK 9 模块化系统

---

### Q18 ⭐⭐⭐⭐
**问：如何进行 JVM 调优？你有哪些实际经验？**

**EN: How do you tune the JVM? Share your practical experience.**

**答 / Answer:**

**常用 JVM 参数：**
```bash
# 堆内存
-Xms4g -Xmx4g          # 初始/最大堆（设为相同避免动态扩容）
-Xmn2g                  # 新生代大小
-XX:MetaspaceSize=256m  # Metaspace 初始大小

# GC 选择
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200

# GC 日志
-Xlog:gc*:file=/logs/gc.log:time,uptime:filecount=5,filesize=100m
```

**调优步骤：**
1. 监控：使用 Prometheus + Grafana / Arthas / JConsole
2. 分析 GC 日志：GC 频率、停顿时间、Full GC 原因
3. 堆 dump 分析：`jmap -dump:format=b,file=heap.hprof <pid>`，用 MAT 分析
4. 常见问题：频繁 Full GC（老年代泄漏）、Metaspace OOM（类加载泄漏）

---

### Q19 ⭐⭐⭐
**问：什么是 OOM？有几种类型？如何排查？**

**EN: What is OOM? What types exist? How to troubleshoot?**

**答 / Answer:**

| OOM 类型 | 原因 | 排查方法 |
|----------|------|----------|
| Java heap space | 对象太多/内存泄漏 | jmap + MAT 分析 |
| GC overhead limit exceeded | GC 时间 > 98%，回收 < 2% | 分析内存泄漏 |
| Metaspace | 类加载过多（动态代理/反射） | 检查框架使用 |
| Direct buffer memory | NIO 直接内存用尽 | 检查 ByteBuffer 是否释放 |
| Unable to create new native thread | 线程数过多 | 减少线程/增加系统限制 |
| StackOverflowError | 递归过深 | 优化递归为迭代 |

---

## 4. Spring 全家桶 / Spring Ecosystem

---

### Q20 ⭐⭐⭐⭐⭐
**问：Spring IOC 和 DI 的原理是什么？Bean 的生命周期？**

**EN: What are the principles of Spring IOC and DI? What is the Bean lifecycle?**

**答 / Answer:**

**IOC（控制反转）：** 将对象的创建和依赖关系交由容器管理，解耦业务代码。

**DI（依赖注入）方式：**
- 构造器注入（推荐，保证不可变）
- Setter 注入
- 字段注入（`@Autowired`，不推荐用于测试）

**Bean 生命周期（简化版）：**
```
实例化（Instantiation）
→ 属性填充（Populate Properties）
→ BeanNameAware / BeanFactoryAware 等 Aware 接口回调
→ BeanPostProcessor#postProcessBeforeInitialization
→ @PostConstruct / InitializingBean#afterPropertiesSet / init-method
→ BeanPostProcessor#postProcessAfterInitialization
→ 使用 Bean
→ @PreDestroy / DisposableBean#destroy / destroy-method
```

---

### Q21 ⭐⭐⭐⭐⭐
**问：Spring AOP 的原理是什么？JDK 动态代理和 CGLIB 的区别？**

**EN: How does Spring AOP work? What are the differences between JDK dynamic proxy and CGLIB?**

**答 / Answer:**

**AOP 核心概念：**
- Aspect（切面）、Pointcut（切入点）、Advice（通知）、JoinPoint（连接点）
- 通知类型：Before、After、AfterReturning、AfterThrowing、Around

**两种代理方式：**

| 特性 | JDK 动态代理 | CGLIB |
|------|-------------|-------|
| 要求 | 目标类实现接口 | 无需接口 |
| 原理 | 反射生成代理类 | 字节码增强生成子类 |
| 性能 | 调用时较慢 | 生成慢，调用快 |
| final 方法 | 支持（接口方法） | 不支持（无法继承） |

**Spring Boot 2.x+ 默认使用 CGLIB**（`spring.aop.proxy-target-class=true`）。

**AOP 失效场景：** 同一个类内部方法调用不走代理（同类调用问题），需通过 `AopContext.currentProxy()` 或注入自身解决。

---

### Q22 ⭐⭐⭐⭐⭐
**问：Spring 事务的传播行为有哪些？什么情况下事务会失效？**

**EN: What are Spring transaction propagation behaviors? When does a transaction fail to take effect?**

**答 / Answer:**

**7种传播行为：**
| 传播行为 | 说明 |
|----------|------|
| REQUIRED（默认） | 有事务加入，无则新建 |
| REQUIRES_NEW | 始终新建，挂起当前事务 |
| NESTED | 嵌套事务（保存点） |
| SUPPORTS | 有则加入，无则非事务执行 |
| NOT_SUPPORTED | 非事务执行，挂起当前事务 |
| MANDATORY | 必须在事务中，否则抛异常 |
| NEVER | 不能在事务中，否则抛异常 |

**事务失效场景：**
1. `@Transactional` 加在非 public 方法
2. 同类内部调用（AOP 代理失效）
3. 异常被 catch 吞掉
4. 抛出 checked exception（默认只回滚 RuntimeException）
5. 数据库引擎不支持事务（MyISAM）
6. 跨数据源（需分布式事务）

---

### Q23 ⭐⭐⭐⭐
**问：Spring Boot 自动装配（AutoConfiguration）的原理是什么？**

**EN: How does Spring Boot AutoConfiguration work?**

**答 / Answer:**

核心流程：
1. `@SpringBootApplication` 包含 `@EnableAutoConfiguration`
2. `@EnableAutoConfiguration` 通过 `AutoConfigurationImportSelector` 加载配置
3. 读取 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`（旧版为 `spring.factories`）中的自动配置类列表
4. 每个自动配置类通过 `@ConditionalOnClass`、`@ConditionalOnMissingBean` 等条件注解决定是否生效

**实现自定义 Starter 步骤：**
1. 创建 `autoconfigure` 模块，编写配置类
2. 在 `META-INF/spring/` 下注册配置类
3. 创建 `starter` 模块引入依赖

---

### Q24 ⭐⭐⭐⭐
**问：Spring 循环依赖是如何解决的？三级缓存的作用？**

**EN: How does Spring resolve circular dependencies? What is the purpose of the three-level cache?**

**答 / Answer:**

Spring 通过**三级缓存**解决单例 Bean 的循环依赖：

| 缓存 | 内容 |
|------|------|
| 一级缓存 singletonObjects | 完整的 Bean（初始化完成） |
| 二级缓存 earlySingletonObjects | 早期 Bean（未完成属性注入） |
| 三级缓存 singletonFactories | ObjectFactory（用于生成代理对象） |

**流程（A 依赖 B，B 依赖 A）：**
1. 创建 A → 放入三级缓存
2. 注入 B → 创建 B → 从三级缓存取 A 的 ObjectFactory → 生成 A 的早期引用 → 放入二级缓存
3. B 完成初始化 → 放入一级缓存
4. A 完成初始化 → 放入一级缓存

**无法解决的循环依赖：** 构造器注入循环依赖（实例化阶段，三级缓存未介入）、原型（prototype）Bean 循环依赖。

---

## 5. Spring Cloud 与微服务 / Spring Cloud & Microservices

---

### Q25 ⭐⭐⭐⭐⭐
**问：Nacos 和 Eureka 的区别？Nacos 的 AP/CP 模式怎么选择？**

**EN: What are the differences between Nacos and Eureka? How to choose between AP and CP mode in Nacos?**

**答 / Answer:**

| 特性 | Nacos | Eureka |
|------|-------|--------|
| 一致性协议 | CP（Raft）/ AP（Distro） | AP（Gossip） |
| 配置中心 | 内置支持 | 需配合 Spring Cloud Config |
| 健康检查 | 主动检测 + 心跳 | 心跳 |
| 服务分组 | 支持命名空间/分组 | 不支持 |
| 维护状态 | 阿里云持续维护 | Netflix 已停止维护 |

**AP vs CP 选择：**
- **AP 模式（默认）**：适合服务注册发现，允许短暂不一致，优先可用性（如电商服务）
- **CP 模式**：适合配置管理，需要强一致性（如金融服务配置变更）

---

### Q26 ⭐⭐⭐⭐⭐
**问：微服务中如何实现分布式事务？Seata 的工作模式有哪些？**

**EN: How to implement distributed transactions in microservices? What are Seata's working modes?**

**答 / Answer:**

**常见分布式事务方案：**

| 方案 | 原理 | 优缺点 |
|------|------|--------|
| 2PC | 两阶段提交 | 强一致性，同步阻塞，单点故障 |
| TCC | Try-Confirm-Cancel | 高性能，业务侵入大 |
| Saga | 补偿事务链 | 最终一致，适合长事务 |
| 本地消息表 | 消息 + 本地事务 | 简单，有一定延迟 |
| MQ 事务消息 | RocketMQ 事务消息 | 解耦，最终一致 |

**Seata 工作模式：**
- **AT 模式**（最常用）：自动解析 SQL，生成 undo log，类似 2PC 但异步
- **TCC 模式**：手动编写 Try/Confirm/Cancel 逻辑
- **Saga 模式**：适合长事务，通过状态机定义补偿流程
- **XA 模式**：标准 2PC，依赖数据库 XA 协议

---

### Q27 ⭐⭐⭐⭐
**问：熔断器（Circuit Breaker）的工作原理？Sentinel 和 Hystrix 的区别？**

**EN: How does the Circuit Breaker pattern work? What are the differences between Sentinel and Hystrix?**

**答 / Answer:**

**熔断器三种状态：**
- **Closed（关闭）**：正常请求，统计失败率
- **Open（打开）**：失败率超阈值，直接拒绝请求
- **Half-Open（半开）**：超时后允许少量请求试探，成功则关闭，失败则继续打开

| 特性 | Sentinel | Hystrix |
|------|----------|---------|
| 维护状态 | 阿里云维护 | Netflix 停止维护 |
| 限流 | 支持（QPS/并发数） | 不支持 |
| 熔断规则 | 慢调用比例/异常比例/异常数 | 异常比例 |
| 实时监控 | Dashboard 友好 | 依赖 Turbine |
| 线程池隔离 | 信号量 | 线程池/信号量 |

---

### Q28 ⭐⭐⭐⭐
**问：Apollo 和 Nacos 配置中心有什么区别？如何实现配置热更新？**

**EN: What are the differences between Apollo and Nacos as config centers? How to implement hot config reload?**

**答 / Answer:**

| 特性 | Apollo | Nacos |
|------|--------|-------|
| 配置灰度 | 支持灰度发布 | 支持 |
| 权限管理 | 细粒度权限 | 基础权限 |
| 审计日志 | 完整操作记录 | 基础 |
| 服务注册 | 不支持 | 支持 |
| 部署复杂度 | 较复杂（多组件） | 简单 |

**配置热更新实现：**
```java
// Nacos 方式
@RefreshScope
@RestController
public class ConfigController {
    @Value("${app.timeout:3000}")
    private int timeout;
}

// Apollo 方式
@ApolloConfigChangeListener
public void onChange(ConfigChangeEvent event) {
    // 手动刷新
}
```

---

### Q29 ⭐⭐⭐
**问：API 网关的作用是什么？Spring Cloud Gateway 和 Zuul 的区别？**

**EN: What is the role of an API Gateway? What are the differences between Spring Cloud Gateway and Zuul?**

**答 / Answer:**

**API 网关核心功能：** 路由转发、认证鉴权、限流熔断、日志监控、协议转换、负载均衡。

| 特性 | Spring Cloud Gateway | Zuul 1.x |
|------|---------------------|----------|
| 编程模型 | 响应式（Reactor/WebFlux） | Servlet 阻塞 |
| 性能 | 高（非阻塞 I/O） | 较低 |
| 过滤器 | GlobalFilter / GatewayFilter | ZuulFilter |
| WebSocket | 支持 | 不支持 |

**自定义过滤器示例：**
```java
@Component
public class AuthFilter implements GlobalFilter, Ordered {
    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String token = exchange.getRequest().getHeaders().getFirst("Authorization");
        if (!isValid(token)) {
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }
        return chain.filter(exchange);
    }
}
```

---

## 6. 中间件 / Middleware

---

### Q30 ⭐⭐⭐⭐⭐
**问：Redis 的数据结构有哪些？底层编码方式是什么？**

**EN: What data structures does Redis support? What are their underlying encodings?**

**答 / Answer:**

| 数据结构 | 底层编码 | 典型使用场景 |
|----------|----------|-------------|
| String | int / embstr / raw | 缓存、计数器、分布式锁 |
| List | listpack / quicklist | 消息队列、最新列表 |
| Hash | listpack / hashtable | 对象存储、购物车 |
| Set | listpack / hashtable | 标签、好友关系、去重 |
| ZSet | listpack / skiplist+hashtable | 排行榜、延迟队列 |
| Bitmap | String 扩展 | 签到、在线状态 |
| HyperLogLog | String 扩展 | UV 统计（有误差） |
| Stream | Stream | 消息队列（替代 MQ 轻量场景） |

**跳表（Skip List）特性：** ZSet 的核心，O(log n) 的查找，比红黑树实现简单，范围查询友好。

---

### Q31 ⭐⭐⭐⭐⭐
**问：如何用 Redis 实现分布式锁？有什么坑？Redisson 是如何解决的？**

**EN: How to implement a distributed lock with Redis? What are the pitfalls? How does Redisson solve them?**

**答 / Answer:**

**基础实现：**
```bash
SET lock_key unique_value NX PX 30000  # NX=不存在才设置，PX=毫秒超时
```

**常见问题：**
1. **锁超时业务未完成**：锁自动释放，其他线程误入 → Redisson 用 watchdog 机制自动续期
2. **误删他人锁**：释放时需验证 value 是否是自己的（Lua 脚本保证原子性）
3. **Redis 主从切换**：主宕机前锁未同步到从 → Redlock 算法（多数节点加锁）
4. **单点故障**：使用 Redlock（N个独立 Redis，多数派加锁）

**Redisson WatchDog 原理：** 加锁成功后启动后台线程，每 `lockWatchdogTimeout / 3` 毫秒检查并续期，直到业务完成主动释放。

---

### Q32 ⭐⭐⭐⭐
**问：Redis 的持久化方式有哪些？如何选择？**

**EN: What persistence modes does Redis offer? How to choose?**

**答 / Answer:**

| 特性 | RDB | AOF |
|------|-----|-----|
| 原理 | 定时快照 | 记录写命令 |
| 文件大小 | 小（二进制压缩） | 大（命令文本） |
| 恢复速度 | 快 | 慢 |
| 数据安全 | 最多丢失快照间隔数据 | 最多丢失 1s 数据（fsync every second） |
| 性能影响 | fork() 时 STW | 持续写入 I/O |

**混合持久化（推荐）：** Redis 4.0+ 支持 AOF 文件中包含 RDB 数据，兼顾重启速度和数据安全。

**选择建议：** 生产环境同时开启 RDB + AOF；纯缓存场景可关闭持久化。

---

### Q33 ⭐⭐⭐⭐
**问：Redis 缓存雪崩、穿透、击穿是什么？如何解决？**

**EN: What are Redis cache avalanche, penetration, and breakdown? How to solve them?**

**答 / Answer:**

**缓存雪崩（Avalanche）：** 大量 key 同时过期 → 请求打到数据库
- 解决：过期时间加随机值、多级缓存（本地 + Redis）、限流降级

**缓存穿透（Penetration）：** 查询不存在的 key → 每次都打数据库
- 解决：布隆过滤器（Bloom Filter）过滤无效 key；空值缓存（设置短期 TTL）

**缓存击穿（Breakdown）：** 热点 key 过期的瞬间大量并发请求
- 解决：
  1. 热点数据不过期（逻辑过期）
  2. 互斥锁（只有一个线程查 DB，其他等待）
  3. 逻辑过期 + 异步更新

---

## 7. 数据库设计与调优 / Database Design & Tuning

---

### Q34 ⭐⭐⭐⭐⭐
**问：MySQL 索引的底层数据结构是什么？为什么用 B+ 树而不是 B 树或哈希？**

**EN: What data structure underlies MySQL indexes? Why B+ tree over B-tree or hash?**

**答 / Answer:**

MySQL InnoDB 使用 **B+ 树**。

**B+ 树 vs B 树：**
- B 树：所有节点存数据；B+ 树：只有叶子节点存数据，非叶子节点只存索引
- B+ 树叶子节点通过双向链表连接，**范围查询高效**
- B+ 树非叶子节点更小，**一次 I/O 加载更多索引**，树更矮（通常 3 层可存 2000万数据）

**为什么不用哈希：**
- 哈希只支持等值查询，不支持范围查询、排序、LIKE
- 哈希冲突时性能退化

**聚簇索引 vs 非聚簇索引：**
- 聚簇（主键）：数据和索引在一起，叶子节点直接是数据行
- 非聚簇（二级）：叶子节点存主键值，需要回表查询（覆盖索引可避免）

---

### Q35 ⭐⭐⭐⭐⭐
**问：什么情况下索引会失效？如何排查慢 SQL？**

**EN: When does an index fail to be used? How to troubleshoot slow SQL?**

**答 / Answer:**

**索引失效场景：**
1. 对索引列使用函数或运算：`WHERE YEAR(create_time) = 2024`
2. 隐式类型转换：`WHERE phone = 13800000000`（phone 是 varchar）
3. LIKE 以 % 开头：`WHERE name LIKE '%张'`
4. OR 条件中有非索引列
5. 违反最左前缀原则：联合索引 (a, b, c)，查询只用 b
6. `IS NOT NULL`（某些情况）
7. 数据量少，优化器选择全表扫描

**慢 SQL 排查步骤：**
```sql
-- 1. 开启慢查询日志
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 1;  -- 超过 1s 记录

-- 2. EXPLAIN 分析
EXPLAIN SELECT * FROM orders WHERE user_id = 100;
-- 关注：type（ref > range > ALL），key，rows，Extra

-- 3. 分析执行计划
EXPLAIN FORMAT=JSON SELECT ...;
```

---

### Q36 ⭐⭐⭐⭐⭐
**问：MySQL 的事务隔离级别有哪些？MVCC 是如何实现的？**

**EN: What are MySQL transaction isolation levels? How is MVCC implemented?**

**答 / Answer:**

**四种隔离级别（问题 / 解决）：**
| 隔离级别 | 脏读 | 不可重复读 | 幻读 |
|----------|------|----------|------|
| READ UNCOMMITTED | ✅ | ✅ | ✅ |
| READ COMMITTED | ❌ | ✅ | ✅ |
| REPEATABLE READ（默认） | ❌ | ❌ | 部分解决 |
| SERIALIZABLE | ❌ | ❌ | ❌ |

**MVCC（多版本并发控制）：**
- 每行数据有隐藏字段：`trx_id`（事务ID）、`roll_pointer`（回滚指针）
- 读操作通过 **ReadView** 判断哪个版本可见：
  - RC（READ COMMITTED）：每次查询生成新 ReadView
  - RR（REPEATABLE READ）：事务开始时生成 ReadView，整个事务复用
- 通过 undo log 形成版本链，实现历史版本读取

**InnoDB 通过 Gap Lock + Next-Key Lock 解决 RR 级别下的幻读。**

---

### Q37 ⭐⭐⭐⭐
**问：数据库连接池参数如何设置？常用连接池的区别？**

**EN: How to configure database connection pool parameters? What are the differences between common connection pools?**

**答 / Answer:**

| 连接池 | 特点 |
|--------|------|
| HikariCP | 最快（JIT 友好），Spring Boot 默认 |
| Druid | 监控功能强大，国内主流 |
| C3P0 | 老旧，不推荐 |
| DBCP | Apache 出品，性能一般 |

**HikariCP 关键参数：**
```yaml
spring:
  datasource:
    hikari:
      minimum-idle: 5            # 最小空闲连接
      maximum-pool-size: 20      # 最大连接数（= CPU核数 * 2 + 磁盘数，经验值）
      connection-timeout: 3000   # 获取连接超时（ms）
      idle-timeout: 600000       # 空闲超时（10分钟）
      max-lifetime: 1800000      # 连接最大生命周期（30分钟，小于数据库 wait_timeout）
      connection-test-query: SELECT 1
```

---

### Q38 ⭐⭐⭐⭐
**问：MySQL 分库分表的策略有哪些？如何处理跨库查询和分布式主键？**

**EN: What are MySQL sharding strategies? How to handle cross-shard queries and distributed primary keys?**

**答 / Answer:**

**分片策略：**
- **水平分库分表**：按 user_id % N 路由，数据量分散
- **垂直分库**：按业务域拆分（订单库、用户库、商品库）
- **垂直分表**：大表拆小表（常用列 + 不常用列）
- **范围分片**：按时间/ID 范围，便于归档，但可能热点

**分布式主键方案：**
| 方案 | 优点 | 缺点 |
|------|------|------|
| 雪花算法（Snowflake） | 趋势递增、高性能 | 依赖机器时钟 |
| 数据库号段（百度 UIDGenerator） | 简单 | 依赖 DB |
| Redis incr | 简单 | 需持久化 |
| UUID | 唯一 | 无序，索引性能差 |

**跨库查询方案：** 冗余数据、应用层聚合、ES 搜索引擎补充、宽表同步（Binlog + Canal）。

---

### Q39 ⭐⭐⭐
**问：Oracle 和 MySQL 的主要区别是什么？**

**EN: What are the main differences between Oracle and MySQL?**

**答 / Answer:**

| 特性 | Oracle | MySQL |
|------|--------|-------|
| 事务 | 默认不自动提交 | 默认自动提交 |
| 序列 | 有 Sequence 对象 | 用 AUTO_INCREMENT |
| 分区 | 强大（Range/List/Hash/Composite） | 基础分区 |
| 并发控制 | 强大（SCN，多版本） | MVCC |
| 分析函数 | 丰富（行号、窗口函数） | 8.0+ 支持窗口函数 |
| 空字符串 | 等同 NULL | 非 NULL |
| 大数据量 | 企业级，性能稳定 | 互联网主流 |
| 成本 | 昂贵 | 开源免费 |

**迁移常见坑：** `ROWNUM` → `LIMIT`、`DECODE` → `CASE WHEN`、`NVL` → `IFNULL`、`SYSDATE` → `NOW()`。

---

## 8. 分布式系统设计 / Distributed System Design

---

### Q40 ⭐⭐⭐⭐⭐
**问：CAP 理论和 BASE 理论是什么？在实际设计中如何取舍？**

**EN: What are CAP and BASE theories? How to make trade-offs in real system design?**

**答 / Answer:**

**CAP 定理：** 分布式系统不能同时满足：
- **C（Consistency）**：强一致性
- **A（Availability）**：高可用
- **P（Partition Tolerance）**：网络分区容忍

网络分区在分布式中不可避免，所以实际是在 **CA 之间取舍**：
- **CP 系统**：ZooKeeper、etcd（强一致性，分区时拒绝服务）
- **AP 系统**：Eureka、Cassandra（可用性，分区时返回旧数据）

**BASE 理论（AP 系统的实践）：**
- **Basically Available**（基本可用）
- **Soft State**（软状态，允许中间态）
- **Eventually Consistent**（最终一致性）

**实际选择：** 金融账务用 CP，用户行为/推荐用 AP。

---

### Q41 ⭐⭐⭐⭐⭐
**问：如何设计一个高可用的系统？有哪些常用手段？**

**EN: How to design a highly available system? What are the common techniques?**

**答 / Answer:**

**高可用设计维度：**

1. **冗余**：主从/主主复制、多机房部署
2. **负载均衡**：Nginx/LVS/SLB，避免单点
3. **熔断降级**：Sentinel/Hystrix，快速失败
4. **限流**：令牌桶/漏桶，保护后端
5. **超时重试**：设置合理超时，幂等接口才可重试
6. **异步解耦**：消息队列削峰填谷
7. **数据分区**：分库分表，避免单库瓶颈
8. **缓存**：多级缓存，减少 DB 压力
9. **监控告警**：全链路监控（Prometheus + Grafana + SkyWalking）

**可用性与停机时间关系（SLA）：**
- 99.9%（三个九）：年停机 8.7 小时
- 99.99%（四个九）：年停机 52 分钟
- 99.999%（五个九）：年停机 5.2 分钟

---

### Q42 ⭐⭐⭐⭐
**问：如何保证消息队列的消息不丢失且不重复消费？**

**EN: How to ensure messages in MQ are not lost and not consumed repeatedly?**

**答 / Answer:**

**消息不丢失（三个环节）：**

1. **生产者端**：确认机制（Kafka acks=all / RabbitMQ confirm mode）+ 失败重试 + 本地消息表
2. **MQ 端**：持久化（Kafka 磁盘存储 / RabbitMQ durable queue）
3. **消费者端**：手动 ACK，业务处理完再确认

**不重复消费（幂等性）：**
- 数据库唯一索引防重（订单号唯一）
- Redis `SET NX` 记录消费状态
- 乐观锁（version 字段）
- 消息 ID 去重表

---

### Q43 ⭐⭐⭐⭐
**问：分布式系统中如何实现服务降级和限流？令牌桶和漏桶算法的区别？**

**EN: How to implement service degradation and rate limiting in distributed systems? What's the difference between token bucket and leaky bucket?**

**答 / Answer:**

**令牌桶（Token Bucket）：**
- 以固定速率往桶里放 token
- 请求需消耗 token，桶满则丢弃新 token
- **允许突发流量**（桶内积累的 token 可一次性消费）
- 适用：允许流量短暂突发，如 API 限流

**漏桶（Leaky Bucket）：**
- 请求进入桶中，以固定速率流出
- 超出桶容量则丢弃
- **平滑输出，不允许突发**
- 适用：平滑流量，保护下游

**Sentinel 限流规则：** QPS 限流 / 并发线程数限流 / 熔断降级（慢调用比例/异常比例）

**降级策略：** 返回默认值、返回缓存数据、Mock 数据、服务降级提示。

---

## 9. 设计模式 / Design Patterns

---

### Q44 ⭐⭐⭐⭐⭐
**问：单例模式有哪几种写法？双重检查锁为什么需要 volatile？**

**EN: What are the implementations of the Singleton pattern? Why does double-checked locking need volatile?**

**答 / Answer:**

**推荐写法——枚举单例：**
```java
public enum Singleton {
    INSTANCE;
    public void doSomething() { }
}
```

**懒汉——DCL（双重检查锁）：**
```java
public class Singleton {
    private static volatile Singleton instance;  // volatile 必须！
    
    public static Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) {
                    instance = new Singleton();
                }
            }
        }
        return instance;
    }
}
```

**为什么需要 volatile：** `new Singleton()` 分三步：① 分配内存 ② 初始化对象 ③ 引用指向内存。指令重排可能导致 ①③② 顺序，另一线程拿到未初始化的对象。`volatile` 禁止重排，保证可见性。

**静态内部类（推荐）：**
```java
public class Singleton {
    private static class Holder {
        static final Singleton INSTANCE = new Singleton();
    }
    public static Singleton getInstance() { return Holder.INSTANCE; }
}
```

---

### Q45 ⭐⭐⭐⭐
**问：说说你常用的设计模式及在项目中的实际应用？**

**EN: What design patterns do you commonly use? Give practical examples from your projects.**

**答 / Answer:**

**创建型：**
- **工厂方法**：`BeanFactory`、根据支付方式创建对应 PayService
- **建造者**：`StringBuilder`、`Lombok @Builder`、复杂对象组装
- **单例**：Spring Bean 默认单例、线程池

**结构型：**
- **代理**：Spring AOP、MyBatis Mapper 接口
- **装饰器**：`BufferedInputStream` 包装 `FileInputStream`
- **适配器**：`Arrays.asList()`、老系统接口适配

**行为型：**
- **策略**：不同促销策略、支付方式选择（消除 if-else）
- **观察者**：Spring `ApplicationEvent`、消息队列监听
- **责任链**：Servlet Filter、Spring Security 过滤链、审批流程
- **模板方法**：`JdbcTemplate`、`AbstractList`

---

### Q46 ⭐⭐⭐
**问：策略模式如何与 Spring 结合消除 if-else？**

**EN: How to combine the Strategy pattern with Spring to eliminate if-else chains?**

**答 / Answer:**

```java
// 策略接口
public interface PayStrategy {
    String type();
    void pay(Order order);
}

// 策略实现
@Component
public class AliPayStrategy implements PayStrategy {
    @Override public String type() { return "ALIPAY"; }
    @Override public void pay(Order order) { /* 支付宝支付 */ }
}

// 策略工厂（Spring 自动注入所有实现）
@Component
public class PayStrategyFactory {
    private final Map<String, PayStrategy> strategyMap;
    
    public PayStrategyFactory(List<PayStrategy> strategies) {
        strategyMap = strategies.stream()
            .collect(Collectors.toMap(PayStrategy::type, s -> s));
    }
    
    public PayStrategy get(String type) {
        return Optional.ofNullable(strategyMap.get(type))
            .orElseThrow(() -> new IllegalArgumentException("Unknown pay type: " + type));
    }
}
```

---

## 10. 性能调优 / Performance Tuning

---

### Q47 ⭐⭐⭐⭐⭐
**问：如何定位和解决 Java 应用的 CPU 飙高问题？**

**EN: How to identify and resolve high CPU usage in a Java application?**

**答 / Answer:**

**排查步骤：**
```bash
# 1. 找到高 CPU 的 Java 进程
top -H -p <pid>  # 找到高 CPU 的线程 TID

# 2. 转换 TID 为十六进制
printf "%x\n" <tid>

# 3. 查看线程堆栈
jstack <pid> | grep -A 30 "<十六进制tid>"

# 4. Arthas 在线诊断（推荐）
arthas: thread -n 3  # 找最忙的 3 个线程
arthas: thread <id>  # 查看指定线程
```

**常见原因：**
- 死循环（while(true) 无 sleep）
- 频繁 GC（内存泄漏 → 频繁 Full GC → CPU 飙高）
- 正则表达式回溯灾难
- JSON 序列化/反序列化循环引用
- 热点锁竞争

---

### Q48 ⭐⭐⭐⭐
**问：如何优化接口响应时间？从哪些层面入手？**

**EN: How to optimize API response time? What layers should be considered?**

**答 / Answer:**

**分层优化：**

1. **代码层**：
   - 减少不必要的对象创建
   - 避免反射滥用
   - 异步处理非核心逻辑（`@Async`）
   - 并行查询（`CompletableFuture`）

2. **缓存层**：
   - 本地缓存（Caffeine）+ Redis 二级缓存
   - 接口结果缓存

3. **数据库层**：
   - 索引优化、SQL 改写
   - 读写分离
   - 分页查询（避免 OFFSET 大数值）
   - 批量操作代替逐条

4. **JVM 层**：
   - GC 停顿优化
   - 连接池调优

5. **网络层**：
   - 减少请求次数（合并 API）
   - 压缩（Gzip）
   - CDN 静态资源

**工具：** Arthas `trace` 命令可精确显示方法调用耗时分布。

---

## 11. 通讯协议与加解密 / Protocols & Cryptography

---

### Q49 ⭐⭐⭐⭐
**问：HTTP 和 HTTPS 的区别？TLS 握手过程是什么？**

**EN: What are the differences between HTTP and HTTPS? Describe the TLS handshake process.**

**答 / Answer:**

**HTTP vs HTTPS：**
- HTTP：明文传输，端口 80，无身份验证
- HTTPS = HTTP + TLS/SSL，加密传输，端口 443，CA 证书验证身份

**TLS 1.3 握手（简化）：**
1. **Client Hello**：客户端发送支持的 TLS 版本、加密套件、随机数
2. **Server Hello**：服务端选择加密套件、发送证书、随机数
3. **Certificate Verify**：客户端验证证书（CA 链、有效期、域名）
4. **Key Exchange**：双方基于 ECDHE 算法交换密钥材料，各自生成会话密钥
5. **Finished**：双方用会话密钥发送 Finished 消息验证握手完整性
6. 之后通信用对称加密（AES-GCM）

**为什么用非对称 + 对称混合：** 非对称加密安全但慢（用于密钥交换），对称加密快（用于数据传输）。

---

### Q50 ⭐⭐⭐⭐
**问：常见的加密算法有哪些？对称和非对称加密的区别？数字签名是如何工作的？**

**EN: What are common encryption algorithms? What's the difference between symmetric and asymmetric encryption? How do digital signatures work?**

**答 / Answer:**

**对称加密：**
- AES（推荐）、DES（已废弃）、3DES
- 特点：速度快，密钥分发困难
- 模式：AES-GCM（推荐，提供认证加密）、AES-CBC（需额外 HMAC）

**非对称加密：**
- RSA、ECDSA、ECDH
- 公钥加密，私钥解密；或私钥签名，公钥验证
- 速度慢，但解决了密钥分发问题

**哈希算法：** MD5（不安全）、SHA-256、SHA-3、bcrypt（密码存储）

**数字签名流程：**
```
发送方：data → SHA-256(data) → RSA加密(私钥) → signature
接收方：data → SHA-256(data) → 对比 → RSA解密(公钥, signature)
```

**实际应用：**
- 接口签名防篡改：HMAC-SHA256
- 密码存储：BCrypt（加盐 + 慢哈希）
- 数据加密传输：RSA 加密 AES 密钥，AES 加密数据

---

### Q51 ⭐⭐⭐
**问：TCP 和 UDP 的区别？TCP 三次握手和四次挥手的过程？**

**EN: What are the differences between TCP and UDP? Describe TCP's three-way handshake and four-way termination.**

**答 / Answer:**

| 特性 | TCP | UDP |
|------|-----|-----|
| 连接 | 面向连接 | 无连接 |
| 可靠性 | 可靠（确认/重传） | 不可靠 |
| 顺序 | 保证顺序 | 不保证 |
| 速度 | 慢（开销大） | 快 |
| 场景 | HTTP、FTP、数据库 | DNS、视频流、游戏 |

**三次握手：**
1. Client → SYN（seq=x）
2. Server → SYN+ACK（seq=y, ack=x+1）
3. Client → ACK（ack=y+1）

**四次挥手：**
1. Client → FIN（主动关闭）
2. Server → ACK（确认，可能还有数据发送）
3. Server → FIN（数据发送完毕）
4. Client → ACK（等待 2MSL 后关闭）

**TIME_WAIT 为什么等待 2MSL：** 确保最后一个 ACK 到达；让网络中残留数据包消失，避免影响新连接。

---

### Q52 ⭐⭐⭐
**问：gRPC 和 REST 的区别？什么场景选择 gRPC？**

**EN: What are the differences between gRPC and REST? When should you choose gRPC?**

**答 / Answer:**

| 特性 | gRPC | REST |
|------|------|------|
| 协议 | HTTP/2 | HTTP/1.1 |
| 序列化 | Protobuf（二进制） | JSON（文本） |
| 性能 | 高（压缩率高，多路复用） | 相对低 |
| 接口定义 | .proto 文件（强类型） | OpenAPI/Swagger |
| 流式通信 | 支持双向流 | 不原生支持 |
| 浏览器支持 | 有限（需 grpc-web） | 完整 |

**选择 gRPC 的场景：**
- 微服务内部通信（性能敏感）
- 多语言环境（.proto 自动生成客户端）
- 实时双向通信（流媒体、即时通信）

---

## 12. 系统化思维与架构设计 / Systematic Thinking & Architecture

---

### Q53 ⭐⭐⭐⭐⭐
**问：如果让你设计一个秒杀系统，你会怎么做？**

**EN: How would you design a flash sale (seckill) system?**

**答 / Answer:**

**核心挑战：** 瞬间高并发、超卖问题、用户体验。

**设计层次：**

1. **前端层**：按钮防重点击、请求合并、CDN 静态化、验证码分散流量

2. **网关层**：限流（Sentinel/Nginx）、黑名单过滤、用户校验

3. **应用层**：
   - 库存预热：商品数量提前加载到 Redis
   - Redis 原子扣减库存：`DECRBY stock:goods_id 1`（Lua 脚本保证原子性）
   - 发送 MQ，异步创建订单
   - 同一用户同一商品幂等控制

4. **消费端**：
   - 消费 MQ，查 DB 库存（兜底）
   - 创建订单，扣减数据库库存（行级锁）

5. **数据层**：
   - 分库分表（按商品 ID）
   - 读写分离

**关键：** 库存扣减在 Redis（高性能），DB 库存是最终防线（防超卖）。

---

### Q54 ⭐⭐⭐⭐
**问：如何设计一个幂等的 API 接口？**

**EN: How would you design an idempotent API?**

**答 / Answer:**

**幂等性定义：** 多次调用与一次调用效果相同。

**常用方案：**

1. **Token 机制（防重令牌）：**
   - 客户端请求前先获取 token（存入 Redis）
   - 提交时携带 token
   - 服务端 Lua 脚本原子校验并删除 token
   - 相同 token 第二次请求直接拒绝

2. **唯一索引（数据库层）：**
   - 业务唯一键加唯一索引（如订单号）
   - 重复插入触发唯一约束，捕获异常返回成功（查已有记录）

3. **状态机（状态流转幂等）：**
   - 订单状态：待支付 → 已支付（只有特定状态才允许转换）
   - 乐观锁：`UPDATE order SET status=2 WHERE id=? AND status=1`

4. **消息消费幂等：** Redis `SETNX msg_id` 记录已消费 ID

---

### Q55 ⭐⭐⭐⭐
**问：如果让你做技术选型，你的方法论是什么？**

**EN: What is your methodology for making technology selection decisions?**

**答 / Answer:**

**技术选型框架（STAR + 量化）：**

1. **需求分析**：
   - 功能需求（核心场景是什么）
   - 非功能需求（并发量、延迟、数据量、一致性要求）

2. **候选方案评估维度：**
   - **成熟度**：社区活跃度、版本稳定性
   - **团队熟悉度**：学习成本、招聘难度
   - **性能**：benchmark 数据
   - **运维成本**：部署复杂度、监控生态
   - **生态**：与现有技术栈的兼容性
   - **许可证**：开源协议风险（AGPL 等）

3. **决策**：小规模 PoC 验证核心假设，再做最终决定

4. **文档**：记录决策背景（ADR——Architecture Decision Record）

---

### Q56 ⭐⭐⭐
**问：你如何理解软件架构中的"高内聚低耦合"？在微服务拆分中如何体现？**

**EN: How do you understand "high cohesion, low coupling" in software architecture? How is this reflected in microservice decomposition?**

**答 / Answer:**

**高内聚：** 一个模块的职责单一、相关功能集中（SRP 原则）。
**低耦合：** 模块间依赖最小化，通过接口/事件通信，而非直接调用。

**微服务拆分原则：**
- **按业务领域（DDD）**：User Service、Order Service、Payment Service
- **服务边界**：服务内高内聚（所有用户相关逻辑在 User Service），服务间低耦合（通过 REST/MQ 通信）
- **数据库独立**：每个微服务独享数据库，不共享表
- **避免过度拆分**：服务过细会导致网络开销、分布式事务激增

**耦合类型（从低到高）：**
消息耦合 < 数据耦合 < 控制耦合 < 内容耦合

---

### Q57 ⭐⭐⭐
**问：DDD（领域驱动设计）的核心概念是什么？如何划分 Bounded Context？**

**EN: What are the core concepts of DDD? How do you define Bounded Contexts?**

**答 / Answer:**

**DDD 核心概念：**
- **领域（Domain）**：业务范围（电商：用户、商品、订单、支付）
- **有界上下文（Bounded Context）**：领域的明确边界，上下文内语言一致
- **实体（Entity）**：有唯一标识（Order#12345）
- **值对象（Value Object）**：无标识，不可变（Money(100, CNY)）
- **聚合（Aggregate）**：一组一致性边界内的实体，有聚合根
- **领域事件（Domain Event）**：表达领域中发生的事情（OrderPaid）
- **领域服务（Domain Service）**：跨聚合的业务逻辑

**划分 Bounded Context 方法：**
1. 事件风暴（Event Storming）工作坊：识别领域事件 → 命令 → 聚合
2. 语言边界：同一词在不同上下文含义不同（"账户"在用户上下文 vs 财务上下文）
3. 对齐组织边界（康威定律）

---

*文档生成时间 / Generated: 2025*
*共 57 题，覆盖 12 个核心主题 / Total: 57 questions across 12 core topics*
*⭐ 数量代表考察频率 / ⭐ count indicates question frequency*
