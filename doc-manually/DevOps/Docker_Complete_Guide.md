# Docker 完全指南（Java 工程师视角）

> 从「会敲 `docker run`」到「理解 Docker 是怎样工作的」。
> 写给有 Java 开发经验、但 Docker 理解停留在初级的工程师。
> 目标：不仅会用，而且理解 Docker 的设计哲学、底层原理和生产实践。
> 以 smart-invest 项目（Spring Boot 微服务容器化部署到 K3S）为上下文。

---

## 目录

| 章节 | 内容 | 重要度 |
|------|------|--------|
| 零 | Docker 诞生背景：Solomon Hykes 到底解决了什么问题 | ★★★★★ |
| 一 | Docker 架构全景：不是"一个程序"，而是一组协作的组件 | ★★★★★ |
| 二 | 镜像 vs 容器：Docker 世界最重要的类比 | ★★★★★ |
| 三 | 镜像分层与 UnionFS：容器"秒启动"和"镜像复用"的秘密 | ★★★★★ |
| 四 | Dockerfile 深度实战：从能跑 → 优雅 → 生产级 | ★★★★★ |
| 五 | 容器运行时全景：dockerd → containerd → runc → OCI | ★★★★☆ |
| 六 | Docker 网络：从单机 `-p` 到跨主机 overlay | ★★★★☆ |
| 七 | Docker 存储：Volume / Bind Mount / tmpfs 彻底搞清楚 | ★★★★☆ |
| 八 | Docker Compose：本地多服务编排 | ★★★★☆ |
| 九 | Registry 与镜像分发：Docker Hub / Harbor / crane / ctr | ★★★★☆ |
| 十 | 容器安全：你以为安全 ≠ 真的安全 | ★★★★☆ |
| 十一 | Docker 与 K8S 的关系：为什么 K8S 要"抛弃" Docker | ★★★★★ |
| 十二 | Docker 替代品：Podman / containerd / nerdctl | ★★★☆☆ |
| 十三 | 生产环境最佳实践 | ★★★★★ |
| 附 A | Docker 关键缩写全称速查 | — |
| 附 B | smart-invest 项目 Docker 化实战复盘 | — |

---

## 零、Docker 诞生背景：Solomon Hykes 到底解决了什么问题

### 0.1 时间线

```
2008 年        Solomon Hykes 在巴黎创立 dotCloud（一家 PaaS 公司）
2010 年        dotCloud 内部开发了一个叫 "Docker" 的内部工具来管理容器
2013 年 3 月   Solomon Hykes 在 PyCon 上做了一场闪电演讲（5 分钟），开源了 Docker
2013 年        演讲后 Docker 爆炸式增长，GitHub star 数几个月破万
2014 年        dotCloud 公司更名为 Docker Inc.，全力投入 Docker
2014 年        Google 发布 Kubernetes（基于内部 Borg 的经验）
2015 年        Docker 推出 Docker Swarm（与 K8S 竞争容器编排）
2015 年        OCI（Open Container Initiative）成立，Docker 捐献 runc 和镜像规范
2017 年        Docker 将 containerd 捐给 CNCF
2017 年        K8S 生态全面胜出，Swarm 逐渐边缘化
2020 年        K8S 宣布弃用 Docker 作为容器运行时（改用 containerd + CRI）
2022 年        K8S 1.24 彻底移除 dockershim
```

### 0.2 Solomon Hykes 遇到了什么问题

Solomon Hykes 当时在 dotCloud 做 PaaS 平台（你也可以理解为"比 Heroku 更灵活的云平台"）。他面临的核心痛点是：

**用户上传的代码在 dotCloud 的服务器上运行，但每个用户的环境需求都不同：**

```
用户 A：「我的 Django 应用需要 Python 2.7 + PostgreSQL 客户端库」
用户 B：「我的 Node.js 应用需要 Node 0.10 + ImageMagick」
用户 C：「我的 Java 应用需要 JDK 6 + MySQL 连接器」
```

如果把所有用户的代码跑在同一台服务器上，依赖冲突是灾难级的。用 VM 隔离？太重了——每个 VM 要跑一个完整 OS，启动慢、占内存大。

**Hykes 的洞察：用 Linux 已有的内核特性（Namespace + Cgroups）来做轻量级隔离，加上 UnionFS 做分层文件系统，再把三者打包成一个好用的工具。**

这就是 Docker 的起源——它不是发明了容器（容器技术在 Linux 内核里已经存在多年），而是**让容器变得好用**。

### 0.3 Docker 解决的核心问题：环境一致性

用 Java 世界来理解：

| 没有 Docker 时 | 有了 Docker 后 |
|----------------|---------------|
| "我电脑上能跑啊！" | "镜像是一样的，跟在哪跑没关系" |
| 新同事入职配 2 天环境 | `docker compose up` 一条命令 |
| 生产环境 JDK 版本和开发不一样，ClassFormatError | 镜像自带 JDK，绝对一致 |
| CI 服务器上要装 Maven、JDK、Node... | CI 只需要装 Docker |
| "只跑了 3 个微服务，服务器内存满了"（共享 OS 争抢依赖） | 每个容器独立运行环境，不互相干扰 |

**Docker 的本质 = 把你的应用程序和它的全部依赖（JDK、系统库、配置、jar）打包成一个不可变的、标准化的集装箱。这个集装箱在 Docker 引擎上的行为完全一致，不管底层是什么 Linux 发行版。**

```
┌───────────────────────────────────────────────────────────────┐
│                     传统部署 vs Docker 部署                      │
│                                                                │
│  传统方式：                                                      │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐                           │
│  │ App A    │ │ App B    │ │ App C    │   ← 共享同一个 OS       │
│  │ JDK 8    │ │ JDK 21  │ │ Python   │      依赖冲突是常态       │
│  ├─────────┤ ├─────────┤ ├─────────┤                           │
│  │           Host OS              │                             │
│  └────────────────────────────────┘                             │
│                                                                │
│  Docker 方式：                                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                        │
│  │ App A    │ │ App B    │ │ App C    │   ← 每个自带依赖        │
│  │ + JDK 8  │ │ + JDK 21 │ │ + Python │      完全隔离            │
│  │ + Libs   │ │ + Libs   │ │ + Libs   │                        │
│  ├──────────┤ ├──────────┤ ├──────────┤                        │
│  │              Docker Engine         │                         │
│  ├────────────────────────────────────┤                         │
│  │              Host OS               │                         │
│  └────────────────────────────────────┘                         │
└───────────────────────────────────────────────────────────────┘
```

---

## 一、Docker 架构全景：不是"一个程序"，而是一组协作的组件

### 1.1 你敲下 `docker run` 时发生了什么

很多初学者以为 Docker 是一个大程序。实际上 Docker 是**多进程协作**的架构：

```
你在终端敲的                     后台服务                      底层干活
┌────────────────┐          ┌─────────────────┐        ┌──────────────┐
│                │ REST API │                 │  gRPC  │              │
│   docker CLI   │ ────────→│ dockerd          │ ──────→│ containerd   │
│   (客户端)      │ ←────────│ (Docker Daemon)  │ ←──────│ (容器管理器)  │
│                │ Unix     │                 │        │              │
└────────────────┘ Socket   └─────────────────┘        └──────┬───────┘
                                                              │
                                              ┌───────────────┤
                                              ↓               ↓
                                        ┌──────────┐   ┌──────────┐
                                        │ containerd│   │ containerd│
                                        │ -shim     │   │ -shim     │
                                        └────┬─────┘   └────┬─────┘
                                             │              │
                                             ↓              ↓
                                        ┌──────────┐   ┌──────────┐
                                        │  runc     │   │  runc     │
                                        │ (创建容器) │   │ (创建容器) │
                                        └──────────┘   └──────────┘
```

| 组件 | 全称/含义 | 作用 | 类比（Java 世界） |
|------|-----------|------|-------------------|
| **docker CLI** | Command Line Interface | 用户交互命令行，发 REST 请求给 dockerd | 你的键盘和鼠标 |
| **dockerd** | Docker Daemon | 管理镜像、容器、网络、卷——所有高级逻辑 | Spring Boot 的 Controller + Service 层 |
| **containerd** | Container Daemon | 专门管理容器生命周期（拉镜像、创建/启停容器） | JVM：管理对象的生命周期 |
| **containerd-shim** | Shim = 垫片 | 每个容器配一个 shim，作为 containerd 和容器之间的"中间人" | `Thread` 的 monitor |
| **runc** | Run Container | 最底层工具——创建 Namespace/Cgroups，启动容器进程 | `new Thread(runnable).start()` 中的 JNI 调用 |

### 1.2 为什么需要这么多层？直接让 dockerd 创建容器不行吗？

**设计原因 1：职责分离（Unix 哲学——Do one thing well）**

dockerd 负责"高层的业务逻辑"（管理镜像、网络、卷、API 认证），containerd 负责"容器的生命周期"，runc 负责"创建隔离环境"。互不干扰，各自演进。

**设计原因 2：containerd-shim 的意义——守护孤儿容器**

```
dockerd 重启 → 所有 shim 不受影响 → 所有容器继续运行
```

如果没有 shim，dockerd 重启时所有容器都挂了。有了 shim，每个容器有自己的守护进程，和 dockerd 的生命周期解耦。

**设计原因 3：可替换性**

这是最重要的原因。Docker 把 containerd 和 runc 都标准化了，任何符合 OCI 规范的工具都可以替换它们。K8S 后来"抛弃 Docker"正是利用了这个设计——K8S 直接跟 containerd 打交道，不再需要 dockerd 这一层。

### 1.3 通信方式

```bash
# docker CLI → dockerd：默认通过 Unix Socket
ls -la /var/run/docker.sock
# srw-rw---- 1 root docker 0 ... /var/run/docker.sock

# 其实你可以直接 curl 这个 socket
curl --unix-socket /var/run/docker.sock http://localhost/containers/json

# dockerd → containerd：通过 gRPC（在同一个 socket 文件上）
ls -la /run/containerd/containerd.sock
```

**这就是为什么 `docker` 命令能在不装 Docker Desktop 的 Linux 上远程操作另一台机器：**

```bash
# 在你的 Mac 上远程操作 ASUS-Ubuntu 上的 Docker
docker -H tcp://192.168.31.192:2375 ps
```

---

## 二、镜像 vs 容器：Docker 世界最重要的类比

### 2.1 类与实例

用 Java 的类比最直观：

| Docker | Java | 说明 |
|--------|------|------|
| **Image（镜像）** | `class UserService {}` | 只读模板，定义"这个应用包含什么" |
| **Container（容器）** | `new UserService()` | 镜像的运行实例 |
| **Dockerfile** | `UserService.java` | 构建镜像的源码 |
| **`docker build`** | `javac UserService.java` | 编译生成镜像 |
| **Registry（Docker Hub）** | Maven Central / Nexus | 存储和分发镜像 |
| **`docker run`** | `new UserService().start()` | 从镜像启动容器 |

```bash
# 一个镜像可以启动多个容器，就像一个类可以 new 多个实例
docker run -d --name user-service-1 my-image
docker run -d --name user-service-2 my-image
docker run -d --name user-service-3 my-image
#   镜像 (class)            三个容器 (instances)
```

### 2.2 镜像的不可变性

**镜像一旦构建好，永远不会被修改。** 容器运行时产生的任何写操作，都发生在容器独有的可写层上（详见第三章 UnionFS）。删除容器，可写层就没了——镜像毫发无损。

这就带来了 Docker 的核心优势之一：**不可变基础设施**。你不需要去"修"一个运行中的容器——改 Dockerfile、重新构建、重新部署即可。这也杜绝了"这台服务器上偷偷改过什么配置"的生产噩梦。

### 2.3 镜像命名规范

```bash
# 完整格式
registry/repository:tag

# 示例拆解
gongchengship/smart-invest-user-service:v1.2.3
│               │                         │
│               │                         └─ tag（版本标签）
│               └─ repository（仓库名 = 命名空间/镜像名）
└─ 省略了 registry（默认是 docker.io）

# 完整写法等价于：
docker.io/gongchengship/smart-invest-user-service:v1.2.3

# 各种常见写法
nginx                          # docker.io/library/nginx:latest
nginx:1.25                     # docker.io/library/nginx:1.25
harbor.internal.com/app:v1     # 私有仓库
192.168.31.192:5000/app:v1     # IP + 端口
```

**重要提示：`latest` 标签只是一个约定，没有任何特殊语义。** Docker 不会自动帮你更新 `latest`，`latest` 不表示"最新版本"——它只是默认的 tag 值。生产环境**必须**用明确的版本号标签。

---

## 三、镜像分层与 UnionFS：容器"秒启动"和"镜像复用"的秘密

### 3.1 没有分层会怎样

假设一个 Java 微服务镜像，如果不分层，就是一个巨大的 tar 包（可能 500MB+）。每次构建、传输、存储都要处理这个完整的 500MB 文件。

**更糟糕的是：** 如果你有 7 个微服务，每个都是基于 Ubuntu + JDK 21 构建的，那 7 个镜像各自存一份 Ubuntu + JDK，浪费 7 倍的磁盘空间和传输时间。

### 3.2 UnionFS（联合文件系统）的设计

Docker 的解决方案是把镜像**分层存储**：

```
Docker 镜像的层结构：

┌─────────────────────────────┐
│  第 5 层: app.jar            │  ← `COPY target/app.jar /app/`
├─────────────────────────────┤
│  第 4 层: 配置文件            │  ← `COPY application.yml /app/config/`
├─────────────────────────────┤
│  第 3 层: 环境变量和启动脚本   │  ← `ENV JAVA_OPTS=...` + `ENTRYPOINT`
├─────────────────────────────┤
│  第 2 层: JDK 21             │  ← `RUN apt-get install openjdk-21-jdk`
├─────────────────────────────┤
│  第 1 层: Ubuntu 22.04 基础  │  ← `FROM ubuntu:22.04`
└─────────────────────────────┘

每层都是只读的。
每一层 = Dockerfile 中的一条指令（FROM / RUN / COPY / ADD）
```

### 3.3 容器运行时：可写层被加到最上面

镜像的所有层都是**只读的**。容器启动时，Docker 在所有只读层之上创建一层薄薄的**可写层（Container Layer）**：

```
┌──────────────────────────────────┐
│  可写层 (Container Layer)         │  ← 容器独有，可读可写，删容器即消失
├──────────────────────────────────┤
│  镜像层 5: app.jar               │  ← 只读
├──────────────────────────────────┤
│  镜像层 4: 配置文件               │  ← 只读
├──────────────────────────────────┤
│  镜像层 3: JDK 21                │  ← 只读
├──────────────────────────────────┤
│  镜像层 1: Ubuntu 22.04          │  ← 只读
└──────────────────────────────────┘
```

### 3.4 Copy-on-Write（写时复制）机制

UnionFS 读写的核心规则：

```
读文件：从上往下找
  ┌─ 可写层里有？ → 返回可写层的版本（"遮蔽"了底层）
  └─ 可写层没有？→ 一层层往下找 → 找到就返回

写文件（修改已有文件）：
  ┌─ 先把该文件从只读层"复制"到可写层
  └─ 在可写层里修改它
  （原始只读层里的文件完全不受影响）
  
  这就是 "Copy-on-Write" —— 只有真正要写的时候才复制

新建文件：
  └─ 直接在可写层创建

删除文件：
  └─ 可写层生成一个 "whiteout" 标记文件
  （底层文件还在，但 UnionFS 对容器"隐藏"了它）
```

### 3.5 这解释了什么

**解释 1：容器为什么"秒启动"？**

因为不需要复制整个文件系统。启动过程只是创建了一个薄薄的可写层，然后把进程丢进隔离环境里跑。如果物理机上已经有 Ubuntu + JDK 的镜像层缓存了，启动新容器几乎不花时间。

**解释 2：多个容器为什么能共享磁盘空间？**

```
┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
│ 容器 A 的可写层       │  │ 容器 B 的可写层       │  │ 容器 C 的可写层       │
│ 各自独有              │  │ 各自独有              │  │ 各自独有              │
├──────────────────────┤  ├──────────────────────┤  ├──────────────────────┤
│         共享的只读镜像层（磁盘上只有一份！）                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │  app.jar                                                            │ │
│  ├─────────────────────────────────────────────────────────────────────┤ │
│  │  JDK 21                                                             │ │
│  ├─────────────────────────────────────────────────────────────────────┤ │
│  │  Ubuntu 22.04                                                       │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
```

3 个容器，底层 Ubuntu + JDK + app.jar 在磁盘上只有一份。

**解释 3：`docker commit` 做了什么？**

当你把容器打包成新镜像时，那个可写层被"冻结"成一个新的只读镜像层：

```
docker commit 之前：                     docker commit 之后：

┌──────────────────┐                   ┌──────────────────────┐
│  可写层（有改动）  │                   │  新镜像层（冻结成只读） │
├──────────────────┤                   ├──────────────────────┤
│  app.jar         │   ──commit──→     │  app.jar             │
├──────────────────┤                   ├──────────────────────┤
│  JDK 21          │                   │  JDK 21              │
├──────────────────┤                   ├──────────────────────┤
│  Ubuntu          │                   │  Ubuntu              │
└──────────────────┘                   └──────────────────────┘
```

**解释 4：为什么 Dockerfile 要合并 `RUN` 命令？**

```dockerfile
# ❌ 坏的写法：三个 RUN，三个只读层
RUN apt-get update                  # 第 3 层：下载了 200MB 的 apt 缓存
RUN apt-get install -y curl vim     # 第 4 层：安装了 curl 和 vim
RUN rm -rf /var/lib/apt/lists/*    # 第 5 层：标记"缓存已删除"，但前面层的缓存物理上还在！

# ✅ 好的写法：一个 RUN，一层搞定
RUN apt-get update && \
    apt-get install -y curl vim && \
    rm -rf /var/lib/apt/lists/*
# 单个 RUN 中缓存被装完就删了，不会进入任何镜像层
```

**关键认知：** 在 UnionFS 中，"后面的层删除前面的层里的文件"不会真正释放磁盘空间。它只是在可写层做了个标记，底层文件还在。所以：**安装依赖 → 清理缓存 → 必须在同一个 RUN 里完成。**

### 3.6 存储驱动：overlay2

Docker 支持多种 UnionFS 实现，现在默认是 **overlay2**：

```bash
# 查看你的 Docker 用的什么存储驱动
docker info | grep 'Storage Driver'
# Storage Driver: overlay2
```

Overlay2 把镜像层存在 `/var/lib/docker/overlay2/` 下，每个容器对应一个子目录。你可以直接看：

```bash
# 每个目录代表一层（l 开头的 = 底层只读层）
ls /var/lib/docker/overlay2/
```

overlay2 在 Linux kernel 3.18+ 就内置支持，不需要额外安装内核模块。这也是它打败 aufs 成为默认的原因。

---

## 四、Dockerfile 深度实战：从能跑 → 优雅 → 生产级

### 4.1 Dockerfile 是一条"构建流水线"

先把心态摆对——Dockerfile 不是在描述"容器的最终状态"，而是在描述**构建步骤**。每一步生成一个新的只读层：

```dockerfile
FROM eclipse-temurin:21-jre-alpine    # 第 1 层：基础镜像
WORKDIR /app                           # 第 2 层（元数据，不占空间）
COPY target/*.jar app.jar              # 第 3 层：放入 jar
EXPOSE 8080                            # 第 4 层（元数据）
ENTRYPOINT ["java", "-jar", "app.jar"] # 第 5 层（元数据）
```

### 4.2 指令详解（从最常见的到高级的）

#### FROM —— 选基础镜像

```dockerfile
# 选基础镜像是 Dockerfile 最重要的决策之一
FROM eclipse-temurin:21-jre-alpine   # ✅ 推荐：官方 JDK + Alpine（小）
FROM ubuntu:22.04                     # ⚠️ 很重，但兼容性好
FROM alpine:3.19                      # ✅ 超小（~7MB），但用 musl libc 不是 glibc
FROM gcr.io/distroless/java21         # ✅ Google 的"无发行版"镜像——连 shell 都没有
FROM scratch                          # 空镜像，什么都不包含
```

| 基础镜像 | 大小 | 有 Shell？ | 适用场景 |
|----------|------|-----------|----------|
| `ubuntu:22.04` | ~77MB | 有 | 快速开发、需要调试 |
| `eclipse-temurin:21-jre-alpine` | ~200MB | 有 | Java 应用生产推荐 |
| `gcr.io/distroless/java21` | ~120MB | **没有** | 极致安全的生产环境 |
| `alpine:3.19` | ~7MB | 有 | 非 Java 的静态编译语言 |
| `scratch` | 0MB | 没有 | 静态二进制（Go/Rust） |

**选镜像的铁律：**
1. 能用官方就不自己造
2. 能用精简版（slim/alpine）就不用完整版
3. 生产环境优先考虑 distroless（减少攻击面）
4. 构建阶段 → 运行阶段应该用不同的镜像（见多阶段构建）

#### COPY vs ADD

```dockerfile
COPY target/app.jar /app/app.jar      # ✅ 99% 的情况用 COPY
ADD target/app.tar.gz /app/            # ADD 会自动解压 tar，COPY 不会
ADD https://example.com/file /app/     # ADD 可以下载 URL，但别这么用（用 RUN curl）
```

**规则：永远用 COPY，除非你需要自动解压 tar。** 原因：COPY 行为简单可预测，ADD 的"魔法"容易产生意外。

#### ENTRYPOINT vs CMD

这是面试最爱考的概念：

```dockerfile
# ENTRYPOINT：容器启动时必定执行的命令（不可被 docker run 后面的参数覆盖）
# CMD：默认参数，可以被 docker run 后面的参数覆盖

# 模式 1：ENTRYPOINT + CMD（推荐）
ENTRYPOINT ["java", "-jar", "app.jar"]
CMD ["--spring.profiles.active=dev"]
# docker run my-image                           → java -jar app.jar --spring.profiles.active=dev
# docker run my-image --spring.profiles.active=prod  → java -jar app.jar --spring.profiles.active=prod

# 模式 2：只用 CMD
CMD ["java", "-jar", "app.jar"]
# docker run my-image                           → java -jar app.jar
# docker run my-image sleep 3600                → sleep 3600（整个 CMD 都被覆盖！）
```

**exec 形式 vs shell 形式：**

```dockerfile
# exec 形式（推荐）：直接执行，不启动 shell，能接收信号
ENTRYPOINT ["java", "-jar", "app.jar"]

# shell 形式：实际执行的是 /bin/sh -c "java -jar app.jar"
# 会多一个 sh 进程，且 sh 不转发信号（容器 stop 收不到 SIGTERM）
ENTRYPOINT java -jar app.jar
```

#### ARG vs ENV

```dockerfile
# ARG：构建时参数（build-time），不会进最终镜像
ARG JAR_FILE=target/*.jar

# ENV：环境变量（run-time），存在于运行中的容器
ENV SPRING_PROFILES_ACTIVE=prod
```

### 4.3 多阶段构建（Multi-stage Build）

这是 Docker 17.05 引入的最重要特性，彻底解决了"构建需要大镜像，运行却只需要小镜像"的矛盾：

```dockerfile
# ===== 阶段 1：构建阶段 =====
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline    # 先下载依赖（利用 Docker 缓存）
COPY src/ src/
RUN mvn package -DskipTests

# ===== 阶段 2：运行阶段 =====
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

# 最终镜像只有 JRE + jar（~200MB），不包含 Maven（~500MB+）
```

**为什么不用 `mvn dependency:go-offline` 再 `COPY src/`？**

Docker 构建时，每一步生成一个缓存层。如果某一步的输入没变，Docker 直接复用缓存层，跳过执行：

```dockerfile
COPY pom.xml .                        # 第 3 层
RUN mvn dependency:go-offline         # 第 4 层（只要 pom.xml 没变，这层就被缓存！）
COPY src/ src/                        # 第 5 层（源码变了才触发重新编译）
RUN mvn package -DskipTests           # 第 6 层
```

**把 COPY pom.xml 和 RUN dependency 放在 COPY src 前面，意味着：** 日常改代码时，只有 5-6 步重新执行（几秒），3-4 步命中缓存（很快）。如果你把整个源码目录 COPY 进去再下载依赖，每次改一行代码都要重新下载所有依赖。

### 4.4 生产级 Spring Boot Dockerfile 模板

```dockerfile
# ===== smart-invest 微服务生产级 Dockerfile =====
# 阶段 1：构建
FROM maven:3.9-eclipse-temurin-21-alpine AS builder
WORKDIR /build
COPY pom.xml .
# 如果项目是多模块的，把其他模块的 pom 也复制进来
# COPY module-a/pom.xml module-a/
RUN mvn dependency:go-offline -B
COPY src/ src/
RUN mvn package -DskipTests -B

# 阶段 2：运行
FROM eclipse-temurin:21-jre-alpine

# 安全：不以 root 运行
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar

# 给 JVM 合理的默认内存配置
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

EXPOSE 8080

USER appuser

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT exec java $JAVA_OPTS -jar app.jar
```

### 4.5 .dockerignore

和 `.gitignore` 一样重要，但经常被忽略：

```dockerignore
# Maven/Gradle 构建产物
target/
build/
*.class

# IDE
.idea/
*.iml
.vscode/

# Git
.git/
.gitignore

# 日志和临时文件
*.log
*.tmp

# 文档
doc/
*.md

# 环境配置（用 ConfigMap/Secret 注入，不要打进镜像）
application-local.yml
```

**为什么重要？** `COPY . .` 会把当前目录所有东西发给 Docker daemon（即 build context），如果不忽略 `target/`，可能在构建时混入旧的构建产物。

### 4.6 镜像瘦身技巧

```bash
# 1. 用 dive 分析镜像每一层的大小
dive my-image:latest
# 直观看到哪一层最"胖"，精准优化

# 2. 用 docker history 看层大小
docker history my-image:latest
# IMAGE          CREATED         SIZE
# a1b2c3d4e5f6   2 minutes ago   250MB   ← 这一层最大

# 3. 瘦身手段一览
```

| 手段 | 效果 | 成本 |
|------|------|------|
| 用 Alpine/slim 基础镜像 | Ubuntu(77MB) → Alpine(7MB) | 需要验证兼容性 |
| 多阶段构建 | 构建工具不进最终镜像 | 改 Dockerfile 就行 |
| `--no-install-recommends`（apt） | apt 少装推荐包 | 一行参数 |
| 清理包管理器缓存（同一 RUN） | 减少几十到几百 MB | 一行命令 |
| `docker-slim` 工具 | 自动分析并精简镜像 | 额外工具 |
| 不要装调试工具（vim/curl/telnet） | 减少体积 + 增加安全 | 排查时可能不方便 |

---

## 五、容器运行时全景：dockerd → containerd → runc → OCI

### 5.1 OCI（Open Container Initiative）—— 容器的"JSR 规范"

2015 年 Docker 一家独大时，社区担心被锁定。于是 Docker 联合 Google、Red Hat 等成立了 OCI（你可以类比为 Java 的 JCP + JSR）：

| OCI 规范 | 内容 | 类比 |
|----------|------|------|
| **OCI Image Spec** | 镜像的格式标准（怎么分层、怎么存文件） | JVM 字节码规范 |
| **OCI Runtime Spec** | 容器运行时标准（怎么创建隔离环境） | Java Language Spec |
| **OCI Distribution Spec** | 镜像仓库的 API 标准（怎么 push/pull） | Maven Repository 规范 |

任何符合 OCI 的运行时（runc、crun、youki...）都能运行任何符合 OCI 的镜像。这就是"容器标准化"。

### 5.2 runc —— 真正干活的人

runc 是整个链条的最底层——它做的事情就是：

```c
// runc 创建容器的本质：
// 1. 创建 Linux Namespace（PID/NET/MNT/UTS/IPC/User/Cgroup）
// 2. 设置 Cgroups（CPU/Memory/IO 限制）
// 3. pivot_root 切换文件系统到镜像的 rootfs
// 4. exec 启动用户进程（取代 runc 自身）
```

```bash
# 可以不通过 Docker，直接用 runc 创建容器
# Docker 只是帮你调用了 runc
runc run my-container
```

### 5.3 containerd —— 比 Docker 更轻的容器管理器

containerd 原本是 dockerd 的一个模块，后来独立出来成为 CNCF 毕业项目。它的职责：

- 管理镜像（pull / push / store）
- 管理容器（create / start / stop / delete）
- 管理快照（snapshot —— 分层文件系统）
- 管理 Task（容器进程）

**containerd 提供的命令行工具是 `ctr`（调试用）和 `nerdctl`（日常用）：**

```bash
# ctr：containerd 原生 CLI（功能全但用法怪异，适合调试）
ctr image pull docker.io/library/nginx:latest
ctr container create docker.io/library/nginx:latest my-nginx
ctr task start -d my-nginx

# nerdctl：模仿 docker CLI 风格（日常用）
nerdctl run -d --name nginx -p 80:80 nginx:latest
nerdctl ps
nerdctl images

# 也可以用 crictl（K8S 社区的标准 CLI）
crictl ps
crictl images
```

### 5.4 运行时分类

| 运行时类型 | 代表 | 说明 |
|-----------|------|------|
| **低层运行时（OCI Runtime）** | runc, crun, youki | 只负责"创建容器"——调用内核 Namespace + Cgroups |
| **高层运行时（Container Runtime）** | containerd, CRI-O | 管理镜像、容器、快照、网络...调用低层运行时干活 |
| **沙箱运行时** | gVisor, Kata Containers, Firecracker | 不共享宿主机内核，用 VM 级隔离 |

```
高层运行时                低层运行时              内核
           调用             调用
containerd ──────→ runc ──────────→ Linux Namespace + Cgroups
(管理容器)          (创建隔离环境)     (真正实现隔离)
```

### 5.5 为什么 K8S 要"抛弃" Docker？

这是面试和实际工作中常见的问题——见第十一章详解。

---

## 六、Docker 网络：从单机 `-p` 到跨主机 overlay

### 6.1 五种网络驱动的本质

```bash
docker network ls
# NETWORK ID     NAME      DRIVER    SCOPE
# abc123         bridge    bridge    local     ← 默认网络（单机）
# def456         host      host      local     ← 直接共享宿主机网络栈
# ghi789         none      null      local     ← 完全无网络
```

| 驱动 | 通信范围 | 原理 | 用途 |
|------|---------|------|------|
| **bridge** | 单机 | 虚拟网桥 `docker0`，NAT 转发 | 默认方式，开发/测试 |
| **host** | 单机 | 容器直接使用宿主机网卡 | 高性能场景（网络密集型） |
| **overlay** | 跨主机 | VXLAN 隧道，跨节点组网 | Docker Swarm / 跨主机 |
| **macvlan** | 单机 | 容器直接分配物理网络 MAC 地址 | 容器需要局域网 IP |
| **none** | 无网络 | 只有 lo 接口 | 安全隔离 |

### 6.2 bridge 模式深度解析

当你 `docker run -p 8080:8080`：

```
┌────────────────────────────────────────────────────────────┐
│                        宿主机                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    iptables DNAT                       │  │
│  │  宿主机 eth0:8080 收到的流量 → → → 转发给容器          │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                  │
│                    docker0 (虚拟网桥)                        │
│                    172.17.0.1                               │
│                   ┌───┴───┐                                 │
│                   ↓       ↓                                 │
│  ┌────────────┐         ┌────────────┐                     │
│  │  容器 A     │         │  容器 B     │                     │
│  │ eth0:       │         │ eth0:       │                     │
│  │ 172.17.0.2  │         │ 172.17.0.3  │                     │
│  └────────────┘         └────────────┘                     │
│                                                             │
│  容器 A → 容器 B：直接通过 docker0 网桥通信（不需要 NAT）     │
│  容器 A → 公网：NAT（通过 iptables MASQUERADE）              │
└────────────────────────────────────────────────────────────┘
```

```bash
# 查看 iptables NAT 规则
iptables -t nat -L DOCKER
# 你会看到 -p 8080 的端口映射本质上是一条 DNAT 规则

# 查看网桥
brctl show docker0
ip addr show docker0
```

### 6.3 容器 DNS

```bash
# Docker 内置了 DNS 解析
docker run -d --name app-a --network mynet my-app-a
docker run -d --name app-b --network mynet my-app-b

# 在 app-a 内部可以直接 ping app-b 的容器名
docker exec app-a ping app-b
# Docker 内置 DNS 服务器（127.0.0.11）会自动解析容器名 → IP
```

### 6.4 自定义网络 vs 默认 bridge

```bash
# 创建自定义网络（推荐）
docker network create --driver bridge mynet

# 自定义 bridge 的优势：
# ✅ 容器间可以用容器名互相访问（DNS 解析）
# ✅ 更好的网络隔离
# ✅ 可以自定义子网范围
docker network create --driver bridge --subnet=172.20.0.0/16 mynet

# 默认 bridge 的缺点：
# ❌ 只能用 IP 互访，不能用容器名
# ❌ 所有容器在同一个网络（隔离性差）
```

---

## 七、Docker 存储：Volume / Bind Mount / tmpfs 彻底搞清楚

### 7.1 三种挂载方式

```
                    Docker 管理        宿主机可访问        容器间共享
                    ──────────        ────────────       ──────────
Volume:             ✅ Docker 管理     ✅（在 Docker 目录下） ✅
Bind Mount:         ❌ 用户自己管       ✅（任意路径）      ✅
tmpfs:              ✅（仅内存）        ❌                 ❌
```

### 7.2 什么时候用什么

```bash
# Volume（推荐）：数据库数据、需要持久化的应用数据
docker volume create pgdata
docker run -v pgdata:/var/lib/postgresql/data postgres:16
# 数据存在 /var/lib/docker/volumes/pgdata/_data/

# Bind Mount（开发时最常用）：代码热更新
docker run -v $(pwd)/src:/app/src my-app
# 改了本地代码 → 容器里立即生效

# tmpfs（敏感数据）：临时缓存、密钥
docker run --tmpfs /tmp my-app
# 数据只在内存里，重启即丢失，不落盘
```

### 7.3 Volume 的生命周期

```bash
docker volume create myvol
docker run -v myvol:/data my-image       # 挂载
docker run --rm -v myvol:/data my-image  # 容器删除时，volume 不删除！

# 清理孤儿 volume
docker volume prune   # 删除所有未被任何容器使用的 volume

# 备份 volume
docker run --rm -v myvol:/data -v $(pwd):/backup alpine \
  tar czf /backup/myvol-backup.tar.gz -C /data .
```

---

## 八、Docker Compose：本地多服务编排

### 8.1 从 `docker run` 到 `docker compose`

```bash
# 没有 Compose 时，启动 smart-invest 需要手动敲 7+ 条命令：
docker network create smart-invest-net
docker run -d --name mysql --network smart-invest-net \
  -e MYSQL_ROOT_PASSWORD=xxx -v mysql-data:/var/lib/mysql mysql:8.0
docker run -d --name user-service --network smart-invest-net \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/user_db \
  -p 8081:8081 user-service:latest
docker run -d --name fund-service --network smart-invest-net \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/fund_db \
  -p 8082:8082 fund-service:latest
# ... 还要记启动顺序、环境变量...太容易出错了
```

```yaml
# 有了 Compose（docker-compose.yml）：
version: "3.8"
services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: xxx
    volumes:
      - mysql-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      retries: 5

  user-service:
    image: user-service:latest
    ports:
      - "8081:8081"
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/user_db
    depends_on:
      mysql:
        condition: service_healthy   # 等 MySQL 真正就绪后再启动

  fund-service:
    image: fund-service:latest
    ports:
      - "8082:8082"
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/fund_db
    depends_on:
      mysql:
        condition: service_healthy

volumes:
  mysql-data:

# 一条命令启动所有服务
# docker compose up -d
```

### 8.2 Compose 的核心概念

| Compose 概念 | K8S 对应概念 | 说明 |
|-------------|-------------|------|
| Service | Deployment + Service | 定义了"怎么运行一个容器" |
| Network | NetworkPolicy + Service | 默认创建一个网络，所有 service 互通 |
| Volume | PVC | 持久化存储 |
| `depends_on` | Init Container / Startup Probe | 启动顺序依赖 |
| `docker compose up -d --scale svc=3` | `replicas: 3` | 水平扩容 |

**Compose 的定位：** 本地开发和简单部署。它不替代 K8S——不提供自愈、自动扩缩、滚动更新策略等生产级特性。

### 8.3 Compose Watch（热重载新方式）

Docker Compose v2.22+ 支持 `watch` 模式，比 bind mount 更优雅：

```yaml
services:
  user-service:
    build: .
    develop:
      watch:
        - action: sync
          path: ./target/classes
          target: /app/classes
        - action: rebuild
          path: pom.xml
```

- `sync`：代码变了 → 直接同步到容器（不需要重启）
- `rebuild`：依赖变了 → 自动重建镜像并重启容器
- `restart`：配置文件变了 → 重启容器

---

## 九、Registry 与镜像分发：Docker Hub / Harbor / crane / ctr

### 9.1 Registry 的作用

Registry 之于 Docker 镜像，等于 Maven Central/Nexus 之于 Java jar 包：

```
docker pull nginx:latest
#      ↑      ↑      ↑
#      |      |      └─ tag
#      |      └─ repository
#      └─ 从 registry 拉取

# 等价于：
docker pull docker.io/library/nginx:latest
#          ↑         ↑       ↑      ↑
#          |         |       |      └─ tag
#          |         |       └─ repository
#          |         └─ Docker 官方命名空间
#          └─ 默认 registry
```

### 9.2 私有 Registry

```bash
# 1. 自建最简单的 registry
docker run -d -p 5000:5000 --name registry registry:2
docker tag my-app:latest localhost:5000/my-app:latest
docker push localhost:5000/my-app:latest

# 2. 企业级：Harbor
# Harbor = Registry + Web UI + 漏洞扫描 + 镜像复制 + RBAC + 审计日志
# 大多数公司用 Harbor 做私有镜像仓库
```

### 9.3 镜像搬运实战（华硕 K3S 场景）

当 K3S 节点无法直接访问 Docker Hub 时：

```bash
# 方案 1：crane（Google 的镜像搬运工具）
# 在一台能访问外网的机器上：
crane copy docker.io/library/nginx:latest harbor.internal.com/library/nginx:latest
# K3S 节点从内网 Harbor 拉：
ctr image pull harbor.internal.com/library/nginx:latest

# 方案 2：docker pull → save → scp → ctr import（离线搬运）
# 外部机器：
docker pull nginx:latest
docker save nginx:latest -o nginx.tar
scp nginx.tar asus-ubuntu:/tmp/

# K3S 节点：
ctr image import /tmp/nginx.tar
# 如果是 K3S 的 containerd，还需要打 K3S 的 managed 标签：
# ctr image tag docker.io/library/nginx:latest docker.io/library/nginx:latest
```

### 9.4 镜像签名与验证

```bash
# Docker Content Trust（DCT）：用数字签名保证镜像未被篡改
export DOCKER_CONTENT_TRUST=1
docker pull nginx:latest
# 会自动验证签名，签名不通过则拒绝 pull
```

---

## 十、容器安全：你以为安全 ≠ 真的安全

### 10.1 容器不是 VM——共享内核是最根本的安全事实

```
┌─────────────────────────────────────────────────────────────┐
│  容器 A          容器 B          容器 C                      │
│  (app.jar)       (nginx)         (mysql)                     │
├─────────────────────────────────────────────────────────────┤
│                同一个 Linux Kernel                            │
│  如果 Kernel 有漏洞 → 三个容器全部受影响                       │
└─────────────────────────────────────────────────────────────┘

VM 的情况（对比）：
┌──────────┐  ┌──────────┐  ┌──────────┐
│  VM A     │  │  VM B     │  │  VM C     │
│  Guest OS │  │  Guest OS │  │  Guest OS │
├──────────┤  ├──────────┤  ├──────────┤
│     Hypervisor (独立的内核空间)          │
└─────────────────────────────────────────┘
```

| 维度 | 容器 | 虚拟机 |
|------|------|--------|
| 隔离级别 | 进程级（Namespace + Cgroups） | 硬件级（Hypervisor） |
| 共享 Kernel | **是**——最大的安全边界 | 否——各自有 Guest Kernel |
| 启动速度 | 毫秒级 | 秒到分钟级 |
| 内存开销 | MB 级 | GB 级 |
| 逃逸风险 | 内核漏洞可能逃逸到宿主机 | 理论上更安全 |

### 10.2 容器安全铁律

```dockerfile
# 1. 不用 root 运行
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# 2. 用只读文件系统（能跑的话）
CMD ["java", "-Djava.io.tmpdir=/tmp", "-jar", "app.jar"]
# docker run --read-only --tmpfs /tmp my-image

# 3. 限制 Linux Capabilities
# docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE my-image
# 丢掉所有特权，只保留绑定 80 端口的能力

# 4. 不要在镜像里写密码
# ❌ ENV DATABASE_PASSWORD=mysecret
# ✅ 运行时注入：docker run -e DATABASE_PASSWORD=$(cat /run/secrets/db-password)

# 5. 定期扫描镜像漏洞
docker scan my-image:latest        # Docker 官方（调用 Snyk）
trivy image my-image:latest        # Aqua Security 开源工具
```

### 10.3 Distroless 镜像

Google 的 Distroless 镜像连 shell 都没有——即使攻击者进了容器，也什么都做不了：

```dockerfile
# 最极端的生产 Dockerfile
FROM gcr.io/distroless/java21-debian12
COPY --from=builder /build/target/*.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
# 这个镜像里没有 shell，没有包管理器，没有 vim，没有 curl...
# docker exec -it my-container /bin/bash  → 失败！根本进不去
```

---

## 十一、Docker 与 K8S 的关系：为什么 K8S 要"抛弃" Docker

### 11.1 这不是"翻脸"，而是"标准化"的胜利

```
K8S 1.23 之前：

kubelet → dockershim → dockerd → containerd → runc → 容器
          │
          └─ K8S 社区维护的"转接头"，把 Docker API 翻译成 CRI 接口
             但它是 K8S 代码库里的"胶水代码"
             每次 Docker 升级，dockershim 都需要适配
```

```
K8S 1.24 及之后：

kubelet → CRI → containerd → runc → 容器
          │
          └─ 标准接口，containerd 原生支持 CRI
             不再需要任何"转接头"
             架构更简单，调用链更短
```

### 11.2 关键时间线

| 时间 | 事件 |
|------|------|
| 2014 | K8S 发布，默认用 Docker 做容器运行时 |
| 2016 | K8S 定义 CRI（Container Runtime Interface）标准接口 |
| 2017 | Docker 把 containerd 捐给 CNCF，containerd 开始原生支持 CRI |
| 2020.12 | K8S 宣布弃用 dockershim |
| 2022.5 | K8S 1.24 彻底移除 dockershim |

### 11.3 对你来说意味着什么

```bash
# 实际影响是 0——你用 docker build 构建的镜像，K8S 依然能拉取和运行
# 因为镜像是符合 OCI Image Spec 的，containerd 能直接拉 Docker Hub 的镜像

# 变的是：
# 老：kubelet → dockershim → dockerd → containerd → runc
# 新：kubelet → CRI → containerd → runc（少了两层）

# 但你的开发习惯完全不受影响——还是用 docker build / docker run
# K3S 内置的 containerd 可以直接：
crictl ps       # 等同于 docker ps
crictl images   # 等同于 docker images
crictl logs     # 等同于 docker logs
```

**一句话总结：K8S 抛弃的不是 Docker 镜像，不是 docker build，而是 dockerd 这个 daemon 进程作为运行时。你的 Dockerfile 和镜像依然能用。**

---

## 十二、Docker 替代品：Podman / containerd / nerdctl

### 12.1 为什么需要替代品

| 替代动机 | 说明 |
|----------|------|
| **没有 daemon** | Docker 依赖一个 root 权限的常驻守护进程（dockerd），出问题影响全局 |
| **Rootless** | Podman 支持完全无 root 运行 |
| **systemd 集成** | Podman 可以生成 systemd unit 文件 |
| **K8S 对齐** | nerdctl + containerd 就是 K8S 的方式 |
| **许可证** | Docker Desktop 对公司收费 |

### 12.2 Podman

```bash
# Podman 的命令与 docker 几乎 100% 兼容（alias docker=podman 就行）
podman run -d --name nginx -p 80:80 nginx:latest
podman ps
podman images
podman build -t my-app .

# Podman 的优势
# ✅ 无 daemon（每个容器是一个子进程，不是 dockerd 的子进程）
# ✅ 天然 rootless
# ✅ 可以生成 systemd service 文件
podman generate systemd --name my-app > /etc/systemd/system/my-app.service
# 这样容器就能像普通服务一样用 systemctl start/stop/enable 管理
```

### 12.3 nerdctl + containerd（K3S 用户最熟悉的组合）

```bash
# nerdctl 是 containerd 的"docker 风格"CLI
# K3S 节点上装 nerdctl 后，可以直接操作 K3S 的容器
nerdctl ps
nerdctl images
nerdctl run -d --name test nginx:latest

# 和 Docker CLI 的区别很小，主要差异在：
# - 网络默认 namespace 不同
# - compose 支持需要额外安装
```

### 12.4 你该用什么？

| 场景 | 推荐 |
|------|------|
| 本地开发 | Docker Desktop / OrbStack(Mac) |
| CI/CD 构建 | `docker build`（兼容性最好） |
| 生产 K8S 节点调试 | `crictl` / `nerdctl` |
| 追求无 daemon / rootless | Podman |
| 追求 K8S 兼容 | nerdctl + containerd |

---

## 十三、生产环境最佳实践

### 13.1 一键检查清单

```bash
# Docker 生产就绪检查（在任意运行中的容器上执行）
docker inspect my-container | jq '.[0] | {
  RootUser:          .Config.User == "" or .Config.User == "root",
  ReadOnlyRootfs:    .HostConfig.ReadonlyRootfs,
  MemoryLimitSet:    .HostConfig.Memory != 0,
  CPULimitSet:       .HostConfig.NanoCpus != 0,
  RestartPolicy:     .HostConfig.RestartPolicy.Name,
  PrivilegedMode:    .HostConfig.Privileged,
  PidMode:           .HostConfig.PidMode,
  HealthCheck:       .Config.Healthcheck != null
}'
```

### 13.2 生产 Docker 命令模板

```bash
docker run -d \
  --name user-service \
  --restart=unless-stopped \            # 自动重启
  --memory="512m" \                     # 内存限制
  --cpus="1.0" \                        # CPU 限制
  --read-only \                         # 只读文件系统
  --tmpfs /tmp \                        # 需要写的地方用 tmpfs
  --cap-drop=ALL \                      # 丢掉所有 Linux 特权
  --cap-add=NET_BIND_SERVICE \          # 只保留绑定端口的特权
  --security-opt=no-new-privileges \    # 禁止提权
  --health-cmd="curl -f http://localhost:8080/actuator/health || exit 1" \
  --health-interval=30s \
  --health-timeout=3s \
  --health-retries=3 \
  --log-driver=json-file \              # 日志驱动
  --log-opt max-size=10m \              # 日志轮转
  --log-opt max-file=3 \
  -p 8080:8080 \
  user-service:1.0.0
```

### 13.3 Docker Daemon 配置

```json
// /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "registry-mirrors": [
    "https://dockerproxy.net"    // 国内镜像加速
  ],
  "live-restore": true           // dockerd 重启时容器继续运行
}
```

### 13.4 容器日志管理

```bash
# Docker 默认日志驱动是 json-file，不会自动清理
# 不清理的话磁盘会被日志吃光

# 方案 1：配置日志轮转（推荐）
# 见上面的 daemon.json 配置

# 方案 2：把日志发给集中式日志系统
docker run --log-driver=fluentd \
  --log-opt fluentd-address=localhost:24224 \
  my-app

# 方案 3：K8S 环境用 Loki + Promtail
```

---

## 附 A、Docker 关键缩写全称速查

| 缩写 | 全称 | 含义 |
|------|------|------|
| **Docker** | (英) 码头工人 | 搬运集装箱的人 = 搬运容器的人 |
| **OCI** | Open Container Initiative | 开放容器标准组织 |
| **CRI** | Container Runtime Interface | K8S 定义的容器运行时标准接口 |
| **CNI** | Container Network Interface | 容器网络标准接口 |
| **CRI-O** | Container Runtime Interface - OCI | Red Hat 主导的轻量 CRI 实现 |
| **runc** | Run Container | OCI 标准低层运行时 |
| **UnionFS** | Union File System | 联合文件系统（分层叠加） |
| **CoW** | Copy-on-Write | 写时复制 |
| **NAT** | Network Address Translation | 网络地址转换 |
| **VXLAN** | Virtual Extensible LAN | 虚拟可扩展局域网（overlay 网络底层） |
| **DCT** | Docker Content Trust | Docker 镜像签名验证 |
| **shim** | (英) 垫片 | 放在两个组件之间的"适配层" |

---

## 附 B、smart-invest 项目 Docker 化实战复盘

### B.1 项目结构

```
smart-invest/
├── smart-invest-user-service/
│   ├── src/
│   ├── pom.xml
│   └── Dockerfile
├── smart-invest-fund-service/
│   ├── src/
│   ├── pom.xml
│   └── Dockerfile
├── ...
├── docker-compose.yml      # 本地开发
└── k8s/                     # 生产部署（K3S）
    ├── user-service/
    │   ├── deployment.yaml
    │   └── service.yaml
    └── ...
```

### B.2 构建和推送流程

```bash
# 1. 构建所有微服务镜像
SERVICES="user-service fund-service order-service trade-service \
          market-data-service gateway-service"
for svc in $SERVICES; do
  docker build -t gongchengship/smart-invest-$svc:latest \
    -t gongchengship/smart-invest-$svc:$(git rev-parse --short HEAD) \
    ./smart-invest-$svc/
done

# 2. 推送到 Docker Hub
for svc in $SERVICES; do
  docker push gongchengship/smart-invest-$svc:latest
  docker push gongchengship/smart-invest-$svc:$(git rev-parse --short HEAD)
done
# 同时打 latest 和 git commit hash 标签，方便回滚
```

### B.3 K3S 镜像导入（离线场景）

当华硕 K3S 节点无法直接从 Docker Hub 拉取时：

```bash
# 快网机（能访问外网的机器）：
crane pull docker.io/gongchengship/smart-invest-user-service:latest
crane save gongchengship/smart-invest-user-service:latest -o user-service.tar
scp user-service.tar asus-ubuntu:/tmp/

# 华硕 K3S 节点：
ctr -n k8s.io image import /tmp/user-service.tar
# K3S 的 containerd 默认使用 k8s.io namespace
```

详细的镜像搬运方案见 [[k3s-image-import-workflow]] 和 [[k3s-image-pull-solutions]]。

---

## 参考资料

- [Docker 官方文档](https://docs.docker.com/)
- [OCI 规范](https://github.com/opencontainers)
- [containerd 官方文档](https://containerd.io/)
- [Dockerfile 最佳实践](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [[Kubernetes_Core_Principles_Guide]] — K8S 核心原理指南（本系列姐妹文档）
- [[Helm_Complete_Guide]] — Helm 完全指南
- [[Docker_Commands_Reference]] — Docker 常用命令速查手册
- [[k3s-image-pull-solutions]] — K3S 镜像拉取解决方案
- [[k3s-image-import-workflow]] — K3S 镜像导入工作流程
