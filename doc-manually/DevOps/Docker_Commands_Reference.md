# Docker 常用命令速查手册（DevOps 工程师视角）

> 按使用频率从高到低排列，每个命令标注英文全称，每个参数标注含义。
> 以 smart-invest 项目（Spring Boot 微服务容器化）为上下文。

---

## 目录

| 章节 | 类别 | 使用频率 |
|------|------|----------|
| **零** | **Docker 底层原理与核心概念（初学者必读）** | — |
| 一 | 镜像管理 | ★★★★★ 每天几十次 |
| 二 | 容器生命周期 | ★★★★★ 每天几十次 |
| 三 | 容器调试 | ★★★★☆ 排查时必用 |
| 四 | 镜像构建 | ★★★★☆ 每次发版 |
| 五 | 日志与信息 | ★★★★☆ 每天若干次 |
| 六 | 网络管理 | ★★★☆☆ 配置时用 |
| 七 | 数据卷管理 | ★★★☆☆ 配置时用 |
| 八 | Docker Compose | ★★★★☆ 本地开发每天用 |
| 九 | Registry 操作 | ★★★☆☆ 发版时用 |
| 十 | 系统维护 | ★★☆☆☆ 巡检时用 |
| 附 | Dockerfile 关键指令 | — |

---

## 零、命令通式 / General Command Pattern

```bash
docker <command> [subcommand] [options] [arguments]
```

Docker CLI 将命令按管理对象分组：

| 分组 | 管理对象 |
|------|----------|
| `docker image` | 镜像 |
| `docker container` | 容器 |
| `docker volume` | 数据卷 |
| `docker network` | 网络 |
| `docker build` | 构建（独立顶级命令） |
| `docker compose` | 多容器编排 |
| `docker system` | Docker 引擎本身 |

---

## Docker 底层原理与核心概念（初学者必读）

> 你已经有 `docker images` / `docker run` / `docker exec -it` / `docker logs` 的基础。
> 这一节把这些命令串起来，让你理解 Docker **为什么**是这样工作的。

---

### 1. Docker 是什么？解决什么问题？

用一个真实的对比来说明。

**没有 Docker 时，你怎么部署 smart-invest 的 user-service？**

```
1. 在服务器上装 JDK 21
2. 装 Maven
3. git clone 代码
4. mvn clean package -DskipTests
5. 配置 application.yml（数据库地址、密码...）
6. nohup java -jar user-service.jar &
7. 祈祷：JDK 版本对吗？依赖全吗？端口冲突吗？
```

换一台服务器，上面 7 步重新来一遍，而且环境可能不一样（JDK 版本不同、系统库缺失……）。

**有了 Docker 后：**

```bash
# 一行命令，在任何装了 Docker 的机器上都一样
docker run -d --name user-service -p 8081:8081 \
  gongchengship/smart-invest-user-service:latest
```

Docker 做的事情本质上是：**把应用程序和它需要的所有东西（JDK、依赖 jar、配置文件、操作系统库）打包成一个标准化的"集装箱"，在任何地方都能原样运行。**

```
┌─────────────────────────────────────────┐
│              镜像 (Image)                │
│  ┌─────────────────────────────────┐    │
│  │      应用 jar + 配置文件          │    │
│  │  ┌───────────────────────────┐  │    │
│  │  │      JDK 21 (精简 JRE)     │  │    │
│  │  │  ┌─────────────────────┐  │  │    │
│  │  │  │  Alpine Linux 基础   │  │  │    │
│  │  │  └─────────────────────┘  │  │    │
│  │  └───────────────────────────┘  │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

---

### 2. Docker 的架构：客户端-服务端模式

Docker 不是一个大程序，而是**两个程序**协作：

```
你在终端敲的命令                 后台默默干活的守护进程
┌──────────────┐               ┌──────────────────────┐
│              │  REST API     │                      │
│ docker CLI   │ ────────────→ │  dockerd (daemon)    │
│ (客户端)      │ ←──────────── │  (服务端/守护进程)    │
│              │   Unix Socket │                      │
└──────────────┘               └──────┬───────────────┘
                                      │
                                      │ 通过 containerd
                                      │ 调用 runc
                                      ↓
                               ┌──────────────┐
                               │  容器 (Container) │
                               │  真正运行的进程   │
                               └──────────────┘
```

| 组件 | 英文 | 作用 | 类比 |
|------|------|------|------|
| **docker CLI** | Command Line Interface | 你敲命令的地方 | 遥控器 |
| **dockerd** | Docker Daemon | 管理镜像、容器、网络、卷 | 电视机本体 |
| **containerd** | Container Daemon | 管理容器生命周期（启动/停止/删除） | 电视的电源管理模块 |
| **runc** | Run Container | 真正创建和运行容器的底层工具 | 电路板 |

**对你来说意味着什么？**

```bash
# 这条命令实际上发生了什么：
docker run -d --name user-service -p 8081:8081 my-image

# Step 1: docker CLI 把这条指令打包成 REST API 请求
# Step 2: 发送给本机的 dockerd（通过 /var/run/docker.sock 这个 Unix socket）
# Step 3: dockerd 检查本地有没有 my-image 这个镜像
# Step 4: dockerd 交给 containerd：「给我创建一个容器」
# Step 5: containerd 调用 runc 真正创建容器的隔离环境
# Step 6: runc 启动容器内的 java -jar app.jar
```

这就是为什么 `docker` 命令可以在不装 Docker 的机器上通过 `-H` 参数远程操作另一台机器的 Docker。

---

### 3. 镜像（Image）和容器（Container）：类与实例

这是 Docker 最重要的一对概念。用 Java 来类比：

| Docker | Java | 说明 |
|--------|------|------|
| **Image（镜像）** | `class UserService {}` | 只读模板，定义了"这个应用长什么样" |
| **Container（容器）** | `new UserService()` | 镜像的运行实例，可以创建多个 |

**镜像 = 只读的构建产物**，从 Dockerfile `docker build` 出来，存在本地：

```bash
docker images
# REPOSITORY                                  TAG       IMAGE ID
# gongchengship/smart-invest-user-service     latest    a1b2c3d4e5f6    ← 这是一个镜像
```

**容器 = 镜像被 `docker run` 启动后的运行实例**，有独立的文件系统、进程空间、网络：

```bash
docker run -d --name user-service-1 gongchengship/smart-invest-user-service:latest
docker run -d --name user-service-2 gongchengship/smart-invest-user-service:latest
# 同一个镜像启动了 2 个容器——就像同一个 class new 了 2 个对象

docker ps
# CONTAINER ID   IMAGE                       NAMES
# f1e2d3c4b5a6   smart-invest-user-service   user-service-1    ← 这是容器 1
# a6b5c4d3e2f1   smart-invest-user-service   user-service-2    ← 这是容器 2
```

**你已有的 4 个命令在这张图里的位置：**

```
docker images          → 看我有哪些镜像（class 列表）
docker run <image>     → 用镜像创建并启动一个容器（new + 运行）
docker exec -it <容器>  → 进入一个已经 Running 的容器内部
docker logs <容器>      → 看容器的 stdout/stderr 输出
```

---

### 4. 镜像的分层结构（Layer）：为什么镜像能复用和缓存

这是 Docker 最巧妙的设计，也是 `docker build` 快的原因。

每个镜像由**多个只读层（Layer）叠加**组成。你的 smart-invest user-service 镜像大概是这样的：

```
┌────────────────────────────────────┐
│ 第 6 层: COPY target/*.jar app.jar │  ← 你的代码（经常变）
├────────────────────────────────────┤
│ 第 5 层: RUN jlink --output /jre   │  ← 精简 JRE
├────────────────────────────────────┤
│ 第 4 层: RUN mvn package           │  ← Maven 构建
├────────────────────────────────────┤
│ 第 3 层: COPY src ./src            │  ← 源码
├────────────────────────────────────┤
│ 第 2 层: RUN mvn dependency:offline│  ← 下载依赖
├────────────────────────────────────┤
│ 第 1 层: FROM amazoncorretto:21    │  ← 基础 JDK 镜像（很少变）
└────────────────────────────────────┘
```

**关键规则：**

1. **每一层都是只读的**——改代码不会改底层，只会加一层新的
2. **层是共享的**——10 个 Java 容器可以共享同一个 JDK 基础层，省磁盘
3. **构建缓存基于层**——哪一层没变化就直接用缓存，跳过重建

**用你的项目来验证：**

```bash
# 看看你的镜像有哪些层
docker history gongchengship/smart-invest-user-service:latest
# IMAGE          CREATED BY                                      SIZE
# a1b2c3d4e5f6   COPY target/*.jar app.jar                       50MB   ← 你的 jar
# b2c3d4e5f6a7   RUN jlink --add-modules ... --output /jre      40MB   ← JRE
# c3d4e5f6a7b8   RUN mvn clean package -DskipTests              0B     ← 这一步不占额外空间
# ...
```

**这就是为什么改了源码后 `docker build` 很快：** 只有变化的层和它上面的层需要重建，下面的层全部命中缓存。

---

### 5. 容器的本质：不是虚拟机，是隔离的进程

这是初学者最常搞混的地方。Docker 容器**不是轻量级虚拟机**。

| | 虚拟机 (VM) | Docker 容器 |
|---|---|---|
| 虚拟化层级 | 硬件层虚拟化 | 操作系统层虚拟化 |
| 每个实例有自己独立的 | 完整 OS 内核 | 共享宿主机内核 |
| 启动时间 | 分钟级 | 秒级 |
| 内存开销 | GB 级（每个 VM 一个完整 OS） | MB 级（只跑应用进程） |
| 隔离机制 | Hypervisor（如 KVM、VMware） | Linux Namespace + Cgroups |

```
虚拟机模式：                        容器模式：
┌──────┬──────┬──────┐              ┌──────┬──────┬──────┐
│App A │App B │App C │              │App A │App B │App C │
├──────┼──────┼──────┤              ├──────┼──────┼──────┤
│Guest │Guest │Guest │              │  Bin/Libs  │       │
│OS    │OS    │OS    │              ├─────────────┤       │
├──────┼──────┼──────┤              │  Docker Engine      │
│  Hypervisor (VMware/KVM) │        ├─────────────────────┤
├─────────────────────────┤        │  Host OS (Linux)     │
│  Host OS (Linux)        │        ├─────────────────────┤
├─────────────────────────┤        │  Physical Server     │
│  Physical Server        │        └─────────────────────┘
└─────────────────────────┘

每个 VM 是一个完整的 OS        每个容器只是一个普通进程
```

**在你的服务器上验证：**

```bash
# 容器里的进程，在宿主机上直接能看到！
docker top user-service
# UID   PID   PPID  CMD
# 1001  12345 12344 java -jar app.jar

# 宿主机上直接看这个 PID
ps aux | grep 12345
# 1001     12345  ... java -jar app.jar    ← 跟上面的是同一个进程！

# 所以容器不是虚拟机，容器里的 java 进程就是宿主机上的一个普通进程
# 只不过这个进程被 Linux Namespace "隔离"了：
#   - 它只能看到自己的文件系统（挂载命名空间）
#   - 它只能看到自己的进程树（PID 命名空间）
#   - 它只能看到自己的网络接口（网络命名空间）
```

---

### 6. 隔离是怎么实现的：Namespace（命名空间）——"你看不到别人"

Linux Namespace 是容器隔离的核心技术，给进程一个"被裁剪过的世界视图"。

| Namespace 类型 | 全称 | 隔离了什么 | 效果 |
|---------------|------|-----------|------|
| **PID** | Process ID | 进程 ID 编号 | 容器内 `ps aux` 只能看到容器自己的进程，PID 从 1 开始 |
| **NET** | Network | 网络接口、IP、路由表 | 每个容器有自己独立的 IP 地址和端口空间 |
| **MNT** | Mount | 文件系统挂载点 | 容器只能看到自己的文件系统（镜像层 + 可写层） |
| **UTS** | Unix Timesharing | 主机名和域名 | 容器的 hostname 可以不同于宿主机 |
| **IPC** | Inter-Process Communication | 共享内存、信号量 | 容器间 IPC 隔离 |
| **USER** | User | 用户和组 ID | 容器内的 root 可以不是宿主机的 root |

**你在项目中的实际感受：**

```bash
# 容器里看，PID 是 1
docker exec user-service ps aux
# PID   USER     COMMAND
#   1   1001     java -jar app.jar          ← 容器内 PID=1
#  25   1001     ps aux

# 但宿主机上看，同一个进程 PID 是 12345
docker inspect -f '{{.State.Pid}}' user-service
# 12345                                     ← 宿主机 PID=12345
```

**这就是 PID Namespace 的效果：** 同一个进程，容器外看是 12345，容器内看是 1。你在容器内 `kill 1`，只影响这个容器。

---

### 7. 资源限制是怎么实现的：Cgroups（控制组）——"你不能超过配额"

Namespace 管"能不能看到别人"，Cgroups 管"能用多少资源"。

| Cgroup 子系统 | 全称/说明 | 限制什么 |
|--------------|-----------|---------|
| **cpu** | CPU | CPU 使用时间配额 |
| **memory** | Memory | 内存使用上限（超了就 OOM Kill） |
| **blkio** | Block I/O | 磁盘读写速度 |
| **pids** | Process IDs | 容器内最大进程数量 |

```bash
# docker run 时限制资源
docker run -d --name user-service \
  --cpus="1.5" \                    # 最多用 1.5 个 CPU 核心
  --memory="512m" \                 # 最多用 512MB 内存（超了就杀！）
  my-image
```

**这就是为什么 K8s Pod 的 `resources.limits.memory` 能生效：** K8s 通过 Docker（更准确说是 containerd）给容器设置 Cgroup 限制。超出 limit → OOM Kill → Pod CrashLoopBackOff。

---

### 8. 容器文件系统：UnionFS（联合文件系统）——"只读层 + 可写层"

每个容器启动时，Docker 在镜像的**只读层**之上叠加一个**可写层（Container Layer）**。

```
┌──────────────────────────────┐
│  可写层 (Container Layer)     │  ← 你对容器的所有修改都在这
│  - docker exec 进去改的文件   │     容器删除 = 这层也删除
│  - 运行时产生的日志/tmp       │
├──────────────────────────────┤
│  第 N 层: 应用 jar            │
├──────────────────────────────┤  ← 镜像层（只读，所有容器共享）
│  ...                         │
├──────────────────────────────┤
│  第 1 层: Alpine Linux 基础    │
└──────────────────────────────┘
```

**关键理解：** 你 `docker exec -it` 进容器后 `rm -rf /` 不会破坏基础镜像——你删的只是可写层的数据。容器删除重来就恢复了。

这就是为什么：
- 数据该放在 Volume 里（绕过 UnionFS，持久化到宿主机）
- 同一个镜像启动 10 个容器，只读层只存一份，写层各有一份
- 日志该写到 stdout/stderr（`docker logs` 能读到），不要写到容器内的文件

---

### 9. Docker 网络：容器怎么互相访问

Docker 默认创建一个叫 `bridge` 的虚拟网络（网桥），每个容器连上去拿到一个内部 IP。

```
宿主机 (192.168.31.192)
    │
    ├── docker0 (虚拟网桥, 172.17.0.1)
    │     │
    │     ├── 容器 user-service   172.17.0.2:8081
    │     │   -p 8081:8081 → 宿主机 8081 转发到 172.17.0.2:8081
    │     │
    │     ├── 容器 fund-service   172.17.0.3:8082
    │     │
    │     └── 容器 order-service  172.17.0.4:8083
```

在你的项目中，`user-service` 要连 `fund-service`：
- 通过 Docker DNS（容器名 → IP）：`curl http://fund-service:8082`
- 通过宿主机的 hosts 映射（你项目中的 `--add-host` 就是干这个的）

```bash
docker run --add-host postgres-host:192.168.31.192 ...
# 这会在容器的 /etc/hosts 里加一行：
# 192.168.31.192  postgres-host
# 这样容器内的 jdbc:postgresql://postgres-host:5432 就能解析到宿主机 IP
```

---

### 10. 全貌总览：一个 `docker run` 到底发生了什么

把上面所有概念串起来，当你执行：

```bash
docker run -d --name user-service \
  -p 8081:8081 \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://postgres-host:5432/smartinvest \
  --memory="768m" \
  --add-host postgres-host:192.168.31.192 \
  gongchengship/smart-invest-user-service:latest
```

```
1. docker CLI → 发送 REST 请求给 dockerd

2. dockerd: 「检查本地有没有 gongchengship/smart-invest-user-service:latest 镜像」
   → 没有就 docker pull 去 Docker Hub 拉
   → 镜像由多个只读层叠加而成

3. dockerd → containerd: 「用这个镜像创建并启动一个容器」

4. containerd → runc:
   ├── 创建 Namespace（PID/NET/MNT/UTS...）——隔离
   ├── 设置 Cgroups（memory=768m）——资源限制
   ├── 在镜像只读层之上叠加可写层（UnionFS）——文件系统
   ├── 分配 IP（172.17.0.x）并加入 docker0 网桥——网络
   ├── 注入环境变量（-e）——配置
   ├── 添加 /etc/hosts 条目（--add-host）——DNS 辅助
   ├── 映射端口（-p 8081:8081）——端口转发
   └── 启动进程：java -jar app.jar（PID=1）

5. 容器内 java 进程启动 → 监听 0.0.0.0:8081

6. 外部请求 → 宿主机:8081 → docker0 → 172.17.0.2:8081 → 容器内 java 进程
```

**这就是你敲的每一条 `docker run` 背后发生的事情。** 现在你知道为什么 `docker images` 看到的是镜像（模板），`docker ps` 看到的是容器（运行实例），`docker exec` 进的是容器隔离环境里的一个 shell 进程。

---

## 一、镜像管理 / Image Management

### `docker pull` — pull（从 Registry 拉取镜像）

```bash
docker pull [options] <image>[:tag]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `--platform` | — | 指定 CPU 架构 | `--platform linux/amd64`（Mac M1 交叉拉取） |
| `--all-tags` / `-a` | **a**ll | 拉取该镜像的所有 tag |
| `--quiet` / `-q` | **q**uiet | 安静模式，只输出 digest |

```bash
docker pull gongchengship/smart-invest-user-service:latest
docker pull gongchengship/smart-invest-user-service:v1

# 你的 smart-invest 项目：在 K3S 节点上拉镜像
docker pull --platform linux/amd64 gongchengship/smart-invest-user-service:latest
# 注意：--platform 是 Mac M1/M2 上构建 linux/amd64 镜像时的常见需求
```

---

### `docker images` / `docker image ls` — 列出本地镜像

```bash
docker images [options] [repository[:tag]]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-a` / `--all` | **a**ll | 显示中间层镜像（含 `<none>` 的悬空镜像） |
| `-q` / `--quiet` | **q**uiet | 只显示镜像 ID |
| `--filter` / `-f` | **f**ilter | 按条件过滤 |
| `--format` | — | 用 Go template 自定义输出格式 |
| `--digests` | — | 显示 digest（SHA256） |
| `--no-trunc` | — | 不截断输出 |

```bash
docker images                                        # 列出所有本地镜像
docker images gongchengship/smart-invest-*           # 看 smart-invest 项目的所有镜像
docker images -f "dangling=true"                     # 找悬空镜像（tag 为 <none>）
docker images -q                                     # 只输出镜像 ID
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

**输出列含义：**
```
REPOSITORY                                  TAG       IMAGE ID       CREATED        SIZE
gongchengship/smart-invest-user-service     latest    a1b2c3d4e5f6   2 hours ago    250MB
```
| 列 | 含义 |
|----|------|
| REPOSITORY | 镜像仓库名（即镜像名） |
| TAG | 标签（版本），不指定则默认为 `latest` |
| IMAGE ID | 镜像唯一标识（SHA256 前 12 位） |
| CREATED | 构建时间 |
| SIZE | 镜像大小（含所有层） |

---

### `docker rmi` — remove image（删除镜像）

```bash
docker rmi [options] <image> [image...]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-f` / `--force` | **f**orce | 强制删除（即使有容器在用） |
| `--no-prune` | — | 不删除悬空的父镜像 |

```bash
docker rmi a1b2c3d4e5f6                                    # 按 IMAGE ID 删
docker rmi gongchengship/smart-invest-user-service:old-tag  # 按 REPO:TAG 删
docker rmi $(docker images -q -f "dangling=true")            # 批量删悬空镜像
```

---

### `docker tag` — tag（给镜像打标签）

```bash
docker tag <source-image>[:tag] <target-image>[:tag]
```

**作用：** 镜像本身不变，只是多了一个名字/标签。同一个 IMAGE ID 可以有多个 REPO:TAG。

```bash
docker tag a1b2c3d4e5f6 gongchengship/smart-invest-user-service:v1.2.0
docker tag user-service:latest gongchengship/smart-invest-user-service:latest
# CI/CD 中常见的双 tag 策略：
docker build -t app:${COMMIT_SHA} -t app:latest .
# 同一个镜像两个 tag — 不占额外磁盘空间
```

---

### `docker push` — push（推送镜像到 Registry）

```bash
docker push [options] <image>[:tag]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-q` / `--quiet` | **q**uiet | 安静模式 |
| `--all-tags` / `-a` | **a**ll | 推送该镜像所有 tag |

```bash
docker push gongchengship/smart-invest-user-service:latest
docker push gongchengship/smart-invest-user-service:v1

# 你的 CI/CD 中的实际写法：
docker push ${REGISTRY}/smart-invest-${svc}:${IMAGE_TAG}
docker push ${REGISTRY}/smart-invest-${svc}:latest
```

---

### `docker save` / `docker load` — 镜像导出/导入（离线传输）

```bash
docker save -o <tar-file> <image>[:tag]         # 导出为 tar 文件
docker load -i <tar-file>                       # 从 tar 文件导入
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-o` | **o**utput | `save`：指定输出文件 |
| `-i` | **i**nput | `load`：指定输入文件 |

```bash
# K3S 离线部署场景（镜像源受限时）
docker save -o smart-invest-images.tar \
  gongchengship/smart-invest-user-service:latest \
  gongchengship/smart-invest-fund-service:latest

# 传到 K3S 节点后
docker load -i smart-invest-images.tar
# 如果 K3S 用 containerd，需要用 ctr/crictl 导入而非 docker
```

**`save` vs `export` 的区别：**
| | `docker save` | `docker export` |
|---|---|---|
| 对象 | 镜像（Image） | 容器（Container） |
| 内容 | 包含所有层 + 元数据 + tag | 只有文件系统快照（扁平化，丢失层信息） |
| 场景 | 镜像迁移/备份 | 导出容器的文件系统 |

---

### `docker history` — history（查看镜像构建历史/层信息）

```bash
docker history [options] <image>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-H` / `--human` | **h**uman-readable | 人类可读大小 |
| `-q` / `--quiet` | **q**uiet | 只显示 IMAGE ID |
| `--no-trunc` | — | 不截断命令 |

```bash
docker history gongchengship/smart-invest-user-service:latest
# 可以看 Dockerfile 每一层的大小——排查哪一层让镜像变大了
```

---

### `docker image inspect` — inspect（查看镜像详细信息）

```bash
docker image inspect [options] <image>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-f` / `--format` | **f**ormat | 用 Go template 提取字段 |

```bash
docker image inspect user-service:latest
docker image inspect -f '{{.Os}}/{{.Architecture}}' user-service    # → linux/amd64
docker image inspect -f '{{.ContainerConfig.Env}}' user-service     # 查看镜像内嵌环境变量
```

---

## 二、容器生命周期 / Container Lifecycle

### `docker run` — run（创建并启动新容器）

**每天使用次数：30+**

```bash
docker run [options] <image>[:tag] [command] [args...]
```

`docker run` = `docker create` + `docker start` + `docker attach` 三合一。是最复杂的命令，必须熟练掌握每个参数。

| 参数 | 全称 | 作用 |
|------|------|------|
| `--name` | — | 给容器起名（不指定则随机生成） |
| `-d` | **d**etach | 后台运行（不阻塞终端） |
| `-it` | **i**nteractive + **t**ty | 交互模式 + 伪终端（进容器跑命令必加） |
| `--rm` | **r**e**m**ove | 容器退出后自动删除（不留垃圾容器） |
| `-p H:P` | **p**ublish | 端口映射 `主机端口:容器端口` | `-p 8080:8080` |
| `-P` | **P**ublish-all | 随机映射容器所有端口到主机 |
| `-e KEY=VALUE` | **e**nv | 设置环境变量（可多次使用） |
| `--env-file` | **env**ironment **file** | 从文件读取环境变量 |
| `-v H:C` | **v**olume | 挂载目录/卷 `主机路径:容器路径` |
| `-v name:C` | — | 挂载命名卷 |
| `--mount` | — | 更详细的挂载语法（推荐，比 `-v` 更明确） |
| `-w` | **w**orkdir | 设置容器内工作目录 |
| `-u` | **u**ser | 以指定用户运行（UID 或 用户名） |
| `--restart` | — | 重启策略 | `no`/`on-failure`/`always`/`unless-stopped` |
| `--network` | — | 连接到指定 Docker 网络 |
| `--add-host` | — | 添加 hosts 映射 | `--add-host postgres-host:192.168.31.192` |
| `--cpus` | — | 限制 CPU 核数 | `--cpus="1.5"` |
| `-m` / `--memory` | **m**emory | 限制内存 | `--memory="512m"` |
| `--entrypoint` | — | 覆盖镜像默认 ENTRYPOINT |

```bash
# DevOps 最常用组合
docker run -d --name user-service -p 8081:8081 \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://postgres-host:5432/smartinvest \
  -e SPRING_DATASOURCE_PASSWORD=localdev_only \
  --add-host postgres-host:192.168.31.192 \
  --restart unless-stopped \
  gongchengship/smart-invest-user-service:latest

# 临时调试容器（用了 --rm，退出自动删除）
docker run -it --rm alpine:latest /bin/sh

# 覆盖 ENTRYPOINT 排查
docker run -it --rm --entrypoint /bin/sh my-image
```

**`-d` vs `-it`：**
| 场景 | 用哪个 |
|------|--------|
| 启动后台服务（API/Worker） | `-d` |
| 进容器执行命令/调试 | `-it` |
| CI 中跑一次性脚本 | `--rm -it` |

**`--restart` 策略：**
| 策略 | 行为 |
|------|------|
| `no` | 默认——不自动重启 |
| `on-failure[:N]` | 退出码非 0 时重启（可限最多 N 次） |
| `always` | 总是重启（Docker daemon 启动时也会拉起来） |
| `unless-stopped` | 和 `always` 类似，但手动 `docker stop` 后不自动拉起来 |

---

### `docker ps` — process status（列出容器）

**每天使用次数：50+**

```bash
docker ps [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-a` / `--all` | **a**ll | 显示所有容器（含已停止的） |
| `-q` / `--quiet` | **q**uiet | 只显示容器 ID |
| `-f` / `--filter` | **f**ilter | 按条件过滤 |
| `-n N` | **n**umber | 显示最近创建的 N 个容器 |
| `-l` / `--latest` | **l**atest | 显示最近创建的容器 |
| `-s` / `--size` | **s**ize | 显示容器磁盘占用 |
| `--format` | — | Go template 自定义输出 |

```bash
docker ps                                  # 只看运行中的
docker ps -a                               # 包含已停止的
docker ps -a -f "status=exited"            # 只看已退出的
docker ps -q                               # 只输出容器 ID
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker ps -a -f "name=smart-invest"        # 按名字过滤
```

**输出列含义：**
```
CONTAINER ID   IMAGE                     STATUS          PORTS                    NAMES
a1b2c3d4e5f6   user-service:latest       Up 2 hours      0.0.0.0:8081->8081/tcp   user-service
```
| 列 | 含义 |
|----|------|
| CONTAINER ID | 容器唯一 ID（SHA256 前 12 位） |
| IMAGE | 使用的镜像 |
| STATUS | `Up`（运行中，含运行时长）/ `Exited`（退出，含退出码）/ `Created` |
| PORTS | 端口映射 `主机端口->容器端口/协议` |
| NAMES | 容器名（可自定义或随机生成） |

---

### `docker start` / `docker stop` / `docker restart` — 启停容器

```bash
docker start [options] <container>       # 启动已停止的容器
docker stop [options] <container>        # 优雅停止（SIGTERM → 等待 → SIGKILL）
docker restart [options] <container>     # = stop + start
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-t` / `--time` | **t**ime | `stop`：SIGTERM 后等多少秒再发 SIGKILL（默认 10） |

```bash
docker stop user-service                        # 优雅停止
docker stop -t 30 user-service                  # 等 30 秒再强杀
docker stop $(docker ps -q)                     # 停止所有运行中的容器
docker restart user-service                     # 重启
```

**`docker stop` 的信号流程（面试考点，和 K8s 优雅停机原理一致）：**
```
docker stop 命令
  ↓
SIGTERM → 容器内进程（对应 K8s terminationGracePeriod）
  ↓ 等待 --time 秒（默认 10s）
SIGKILL → 强制杀死
```
→ 这就是为什么要在 Dockerfile 中用 `exec` 形式的 ENTRYPOINT（PID 1 能收到信号）。

---

### `docker rm` — remove（删除容器）

```bash
docker rm [options] <container> [container...]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-f` / `--force` | **f**orce | 强制删除（即使是运行中的） |
| `-v` / `--volumes` | **v**olumes | 同时删除挂载的匿名卷 |
| `-l` / `--link` | **l**ink | 只删除链接，不删容器 |

```bash
docker rm user-service                                       # 删除已停止的容器
docker rm -f user-service                                    # 强制删（不管运行与否）
docker rm $(docker ps -aq -f "status=exited")                 # 批量删已退出的容器
docker rm -f $(docker ps -aq)                                # 强制删所有容器（危险！）
```

---

### `docker pause` / `docker unpause` — 暂停/恢复容器

```bash
docker pause <container>         # 暂停容器内所有进程（cgroup freezer）
docker unpause <container>       # 恢复
```

---

## 三、容器调试 / Container Debugging

### `docker exec` — execute（在运行中的容器里执行命令）

**每天使用次数：20+**（进容器排查必用）

```bash
docker exec [options] <container> <command> [args...]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-d` | **d**etach | 后台运行（不连 STDIN） |
| `-it` | **i**nteractive + **t**ty | 交互模式（进 shell 必加） |
| `-e KEY=VALUE` | **e**nv | 设置环境变量 |
| `-w` | **w**orkdir | 执行命令时的工作目录 |
| `-u` | **u**ser | 以指定用户执行 |

```bash
# 最常见：进去看配置、看日志文件
docker exec -it user-service /bin/sh

# 执行单条命令
docker exec user-service cat /app/application.yml            # 看配置文件
docker exec user-service jstack 1                            # JVM 线程 dump
docker exec user-service jmap -heap 1                        # JVM 堆信息
docker exec user-service curl localhost:8081/actuator/health # 健康检查
docker exec user-service env                                 # 看容器内环境变量
```

**`docker exec` vs `docker attach`：**
| | `docker exec` | `docker attach` |
|---|---|---|
| 进入方式 | 在新进程中运行命令 | 连接到容器的 PID 1 的 STDIN |
| 退出影响 | `exit` 只退出 exec 进程，容器继续运行 | `exit` 或 Ctrl+C **会停止容器**！ |
| 推荐 | ✓ 日常首选 | 极少用，一般用 `logs -f` 替代 |

---

### `docker cp` — copy（容器和主机之间拷贝文件）

```bash
docker cp [options] <src> <dest>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-a` / `--archive` | **a**rchive | 保留文件权限、所有者 |

```bash
# 主机 → 容器
docker cp ./values.yaml user-service:/app/config/

# 容器 → 主机
docker cp user-service:/app/logs/application.log ./

# 容器 → 容器（不行！先拷到主机，再拷进另一个容器）
```

---

### `docker inspect` — inspect（查看容器/镜像/网络/卷的底层配置）

```bash
docker inspect [options] <object>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-f` / `--format` | **f**ormat | Go template 提取字段 |

```bash
# 最常用：快速获取关键信息
docker inspect -f '{{.State.Status}}' user-service             # 容器状态
docker inspect -f '{{.State.Pid}}' user-service                # 容器 Pid
docker inspect -f '{{.NetworkSettings.IPAddress}}' user-service # 容器 IP
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' user-service

# 看挂载信息
docker inspect -f '{{json .Mounts}}' user-service | python3 -m json.tool

# 看完整信息
docker inspect user-service | less
```

---

### `docker top` — top（查看容器内进程）

```bash
docker top <container> [ps options]
```

```bash
docker top user-service                              # 容器内所有进程
docker top user-service aux                          # 等价于 ps aux
```

---

## 四、镜像构建 / Image Build

### `docker build` — build（根据 Dockerfile 构建镜像）

```bash
docker build [options] <context-path>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-t` / `--tag` | **t**ag | 给镜像命名和打 tag（可多次使用，多 tag 不占额外空间） |
| `-f` / `--file` | **f**ile | 指定 Dockerfile 路径（默认当前目录下的 `Dockerfile`） |
| `--platform` | — | 目标 CPU 架构 | `--platform linux/amd64` |
| `--build-arg` | — | 传递构建参数（对应 `ARG` 指令） |
| `--no-cache` | — | 不使用构建缓存（全量重新构建） |
| `--pull` | — | 强制拉取最新基础镜像 |
| `-q` / `--quiet` | **q**uiet | 构建完只输出 IMAGE ID |
| `--target` | — | 只构建到指定阶段（Multi-stage 调试用） |
| `--label` | — | 添加元数据标签 |

```bash
# 你的 smart-invest 项目实际构建命令
docker build -t gongchengship/smart-invest-user-service:latest \
  -f backend/user-service/Dockerfile backend/

# CI/CD 中双 tag + 指定平台
docker build -t ${REGISTRY}/smart-invest-${svc}:${IMAGE_TAG} \
  -t ${REGISTRY}/smart-invest-${svc}:latest \
  -f backend/${svc}/Dockerfile backend/

# 构建时传参
docker build --build-arg JAVA_VERSION=21 -t app:latest .

# Multi-stage 调试：只看 build 阶段
docker build --target builder -t app:build-stage .
```

**`context-path`（构建上下文）是什么？**
→ 你指定的目录会被打包发送给 Docker daemon，作为构建时的根目录。`COPY`/`ADD` 只能访问上下文内的文件。所以要选好上下文路径——太大则构建慢。

---

### `docker buildx build` — 增强版构建（多架构支持）

```bash
docker buildx build [options] <context-path>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `--platform` | — | 目标架构列表 | `--platform linux/amd64,linux/arm64` |
| `--push` | — | 构建完自动 push |
| `--load` | — | 构建完加载到本地镜像（仅单架构） |
| `--cache-from` | — | 从远程 registry 读取缓存 |
| `--cache-to` | — | 将缓存写入远程 registry |

```bash
# 多架构构建 + 推送（GitHub Actions CI 中常用）
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t gongchengship/smart-invest-user-service:latest \
  --push \
  -f backend/user-service/Dockerfile backend/
```

---

## 五、日志与信息 / Logs & Information

### `docker logs` — logs（查看容器日志）

**每天使用次数：20+**

```bash
docker logs [options] <container>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-f` / `--follow` | **f**ollow | 持续追踪（类似 `tail -f`） |
| `--tail N` | **tail** | 显示最后 N 行 |
| `-t` / `--timestamps` | **t**imestamps | 显示时间戳 |
| `--since` | — | 显示某个时间之后的日志 | `--since 5m`, `--since 2026-08-05T10:00:00` |
| `--until` | — | 显示某个时间之前的日志 |
| `-n N` | **n**umber | 同 `--tail N` |

```bash
docker logs user-service                                 # 全部日志
docker logs -f --tail 200 user-service                   # 最近 200 行 + 持续追踪
docker logs --since 10m user-service                     # 最近 10 分钟的日志
docker logs --since 10m user-service | grep ERROR        # 最近 10 分钟的 ERROR
docker logs -t user-service 2>&1 | grep -C5 OOM          # 带时间戳看 OOM 上下文

# 注意：docker logs 只收集 stdout/stderr，
# 所以 Dockerfile 中 CMD 不要把日志输出到文件！
```

---

### `docker stats` — statistics（容器资源使用统计）

```bash
docker stats [options] [container...]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-a` / `--all` | **a**ll | 显示所有容器（含已停止） |
| `--no-stream` | — | 只输出一次（默认持续刷新） |
| `--no-trunc` | — | 不截断容器名 |
| `--format` | — | Go template 自定义输出 |

```bash
docker stats                                  # 实时刷新所有容器
docker stats --no-stream                      # 快照——只看一次
docker stats user-service fund-service        # 只看指定容器
```

---

### `docker info` — info（Docker daemon 系统信息）

```bash
docker info [options]
```

| 参数 | 作用 |
|------|------|
| `-f` / `--format` | 用 Go template 提取字段 |

```bash
docker info                              # 总览：容器数、镜像数、存储驱动、CPU/内存等
docker info -f '{{.OSType}}/{{.Architecture}}'
```

---

### `docker version` — 查看 Docker 客户端和 daemon 版本

```bash
docker version
docker version --format '{{.Server.Version}}'    # 只看 server 版本
```

---

## 六、网络管理 / Network Management

### `docker network ls` — 列出网络

```bash
docker network ls [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-f` / `--filter` | **f**ilter | 过滤 |
| `-q` / `--quiet` | **q**uiet | 只输出网络 ID |
| `--no-trunc` | — | 不截断 ID |

```bash
docker network ls                              # 列出所有网络
```

**Docker 内置网络驱动：**
| 驱动 | 全称/说明 | 作用 |
|------|-----------|------|
| `bridge` | 默认网桥 | 单机容器互通（默认驱动） |
| `host` | 主机网络 | 容器直接用宿主机的网络栈（无隔离） |
| `overlay` | 覆盖网络 | 跨多台 Docker 主机的容器互通（Swarm 用） |
| `none` | 无网络 | 容器没有网络接口 |
| `macvlan` | MAC VLAN | 容器拥有独立 MAC 地址，直接接入物理网络 |

---

### `docker network create` — 创建网络

```bash
docker network create [options] <name>
```

| 参数 | 作用 | 示例 |
|------|------|------|
| `-d` / `--driver` | 指定驱动 | `-d bridge` |
| `--subnet` | 指定子网 | `--subnet 172.20.0.0/16` |

---

### `docker network inspect` — 查看网络详情

```bash
docker network inspect <name>
```

**用途：** 看哪些容器连到了这个网络，各自的 IP 是什么。

```bash
docker network inspect bridge | jq '.[].Containers'    # 看 bridge 上的所有容器
```

---

### `docker network connect` / `docker network disconnect` — 连接/断开网络

```bash
docker network connect <network> <container>
docker network disconnect <network> <container>
```

**用途：** 把运行中的容器加入/移出网络。

---

### `docker port` — port（查看容器端口映射）

```bash
docker port <container> [private-port]
```

```bash
docker port user-service                  # 看所有端口映射
docker port user-service 8081             # 只看 8081
```

---

## 七、数据卷管理 / Volume Management

### `docker volume ls` — 列出卷

```bash
docker volume ls [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-f` / `--filter` | **f**ilter | 过滤 | `-f dangling=true` |
| `-q` / `--quiet` | **q**uiet | 只输出卷名 |

---

### `docker volume create` — 创建卷

```bash
docker volume create [options] <name>
```

| 参数 | 作用 |
|------|------|
| `-d` / `--driver` | 存储驱动（默认 `local`） |
| `--label` | 添加元数据 |
| `-o` / `--opt` | 驱动特定选项 |

---

### `docker volume inspect` — 查看卷详情

```bash
docker volume inspect <name>
# 关键信息：Mountpoint（宿主机上实际存放数据的路径）
```

---

### `docker volume rm` — 删除卷

```bash
docker volume rm <name>
docker volume prune           # 删除所有未被任何容器使用的卷
```

---

### `docker volume prune` — 清理未使用的卷

```bash
docker volume prune [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-f` / `--force` | **f**orce | 不提示确认 |
| `--filter` | — | 按条件过滤 |

---

## 八、Docker Compose / docker compose

### `docker compose up` — 启动多容器应用

```bash
docker compose [options] up [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-d` / `--detach` | **d**etach | 后台运行 |
| `--build` | — | 启动前先重新构建镜像 |
| `--force-recreate` | — | 强制重建容器（即使配置没变） |
| `--no-deps` | — | 不启动依赖的服务 |
| `-f` / `--file` | **f**ile | 指定 compose 文件（默认 docker-compose.yml） |

```bash
docker compose up -d                                 # 后台启动所有服务
docker compose up -d --build                         # 重新构建 + 启动
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d  # 合并多个 compose 文件
```

---

### `docker compose down` — 停止并删除

```bash
docker compose down [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-v` / `--volumes` | **v**olumes | 同时删除 volumes |
| `--rmi` | **r**e**m**ove **i**mages | 同时删除镜像 | `--rmi all` / `--rmi local` |
| `-t` / `--timeout` | **t**imeout | 停止超时时间 |
| `--remove-orphans` | — | 删除 compose 文件中不存在的服务的容器 |

```bash
docker compose down                        # 停止 + 删除容器 + 网络
docker compose down -v                     # 连 volume 一起删（数据库数据会丢！）
```

---

### `docker compose ps` — 查看 compose 项目中的容器

```bash
docker compose ps [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-a` / `--all` | **a**ll | 含已停止的 |
| `--format` | — | 自定义格式 |

```bash
docker compose ps                          # compose 项目的所有容器状态
```

---

### `docker compose logs` — 查看 compose 项目日志

```bash
docker compose logs [options] [service...]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-f` / `--follow` | **f**ollow | 持续追踪 |
| `--tail N` | — | 最后 N 行 |
| `-t` / `--timestamps` | **t**imestamps | 时间戳 |

```bash
docker compose logs -f --tail 100 user-service    # 只看某服务日志
docker compose logs -f                            # 所有服务日志（多容器混合输出）
```

---

### `docker compose exec` — compose 版 exec

```bash
docker compose exec [options] <service> <command>
```

比 `docker exec` 更方便——直接用 service 名，不用找容器名。

```bash
docker compose exec user-service /bin/sh
docker compose exec -T postgres psql -U smartadmin -d smartinvest
# -T 禁用伪终端（脚本中用）
```

---

### `docker compose restart` / `docker compose stop` / `docker compose start`

```bash
docker compose restart [service...]          # 重启指定服务
docker compose stop [service...]             # 停止
docker compose start [service...]            # 启动
```

---

### `docker compose build` — 构建 compose 中的镜像

```bash
docker compose build [options] [service...]
```

| 参数 | 作用 |
|------|------|
| `--no-cache` | 不用缓存 |
| `--pull` | 拉最新基础镜像 |

```bash
docker compose build --no-cache user-service     # 只重建 user-service 的镜像
```

---

## 九、Registry 操作 / Registry Operations

### `docker login` — 登录 Registry

```bash
docker login [options] [server]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-u` / `--username` | **u**sername | 用户名 |
| `-p` / `--password` | **p**assword | 密码（不推荐明文，用 `--password-stdin`） |
| `--password-stdin` | — | 从 stdin 读密码（安全方式） |

```bash
# CI/CD 中安全做法
echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

# GitHub Actions 中的标准写法（你的 cd-k3s.yml 也在用）
- name: Login to Docker Hub
  uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_PASSWORD }}
```

---

### `docker logout` — 登出 Registry

```bash
docker logout [server]
```

---

### `docker search` — 搜索 Docker Hub

```bash
docker search [options] <term>
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `--filter` / `-f` | **f**ilter | 过滤 | `-f stars=100` |
| `--limit N` | — | 最多显示 N 条 |
| `--no-trunc` | — | 不截断描述 |

```bash
docker search nginx --limit 10
docker search --filter=is-official=true openjdk
```

---

## 十、系统维护 / System Maintenance

### `docker system prune` — 一键清理

```bash
docker system prune [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-a` / `--all` | **a**ll | 清理所有未使用的镜像（不仅是悬空镜像） |
| `-f` / `--force` | **f**orce | 不提示确认 |
| `--volumes` | — | 同时清理未使用的卷 |
| `--filter` | — | 按条件过滤 |

```bash
docker system prune                          # 删停止的容器 + 未用网络 + 悬空镜像 + 构建缓存
docker system prune -a                       # 更彻底：所有未用镜像也删
docker system prune -a -f --volumes          # 最彻底：一卷到底（慎用！）
docker system df                             # 先看看占了多少空间再 prune
```

---

### `docker system df` — 查看磁盘占用

```bash
docker system df [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-v` / `--verbose` | **v**erbose | 详细输出（每个镜像/容器/卷的占用） |

```bash
docker system df                              # 总览
docker system df -v                           # 看每个镜像占多少
```

---

### `docker container prune` — 清理已停止的容器

```bash
docker container prune [options]
```

### `docker image prune` — 清理未使用的镜像

```bash
docker image prune [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-a` / `--all` | **a**ll | 所有未用镜像（不仅是悬空） |
| `-f` / `--force` | **f**orce | 不提示 |
| `--filter` | — | 过滤 | `--filter "until=24h"` — 只删 24h 前的 |

### `docker network prune` — 清理未使用的网络

```bash
docker network prune [options]
```

### `docker builder prune` — 清理构建缓存

```bash
docker builder prune [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `-a` / `--all` | **a**ll | 所有缓存（不仅是未用的） |
| `-f` / `--force` | **f**orce | 不提示 |
| `--filter` | — | 过滤 | `--filter "until=48h"` |

```bash
docker builder prune -a -f                    # CI 中构建前清缓存（确保干净的构建）
```

---

### `docker events` — 实时监听 Docker daemon 事件

```bash
docker events [options]
```

| 参数 | 全称 | 作用 |
|------|------|------|
| `--filter` | — | 过滤事件类型 | `--filter event=die` |
| `--since` | — | 从指定时间开始 |
| `--until` | — | 到指定时间 |
| `--format` | — | Go template 格式化 |

```bash
docker events --filter event=die --format '{{.Time}} {{.Actor.Attributes.name}} died'
# 实时看哪些容器挂了
```

---

## 附录一：Dockerfile 关键指令 / Key Dockerfile Instructions

| 指令 | 全称/含义 | 作用 | 备注 |
|------|-----------|------|------|
| `FROM` | — | 指定基础镜像 | 必须是第一条指令；Multi-stage 用 `FROM ... AS stage` |
| `RUN` | — | 在构建时执行命令 | 每条 RUN 创建一个新层，尽量合并（`&&` 链式） |
| `COPY` | — | 从构建上下文拷贝文件到镜像 | 推荐用 COPY（ADD 有额外行为） |
| `ADD` | — | 类似 COPY，但额外支持 URL 下载和 tar 自动解压 | 避免用，除非确实需要 tar 自动解压 |
| `WORKDIR` | **work**ing **dir**ectory | 设置工作目录 | 不存在则自动创建 |
| `ENV` | **env**ironment | 设置环境变量（持久化） | 运行时也可覆盖 |
| `ARG` | **arg**ument | 构建参数（只在构建时有效） | `--build-arg` 传入，镜像中不存在 |
| `EXPOSE` | — | 声明容器监听的端口 | **纯文档作用**——不实际发布端口，`-P` 依赖它 |
| `CMD` | **c**o**m**man**d** | 容器启动时的默认命令 | 可被 `docker run` 后面的命令覆盖 |
| `ENTRYPOINT` | — | 容器启动时执行的入口程序 | 不被覆盖（除非 `--entrypoint`），CMD 作为它的参数 |
| `VOLUME` | — | 声明匿名卷挂载点 | 数据会存在 Docker 管理的卷中 |
| `USER` | — | 指定运行用户 | 生产环境应用不要用 root！ |
| `HEALTHCHECK` | — | 健康检查指令 | 配合 `docker ps` 的 `(healthy)` 状态 |
| `LABEL` | — | 添加元数据 | 如 `org.opencontainers.image.source` |

**CMD 的三种写法：**
```dockerfile
# exec 形式——推荐！PID 1 能正确收到信号
CMD ["java", "-jar", "app.jar"]

# shell 形式——实际执行 /bin/sh -c "java -jar app.jar"
# PID 1 是 sh 而不是 java，SIGTERM 不会被 java 收到！
CMD java -jar app.jar

# 给 ENTRYPOINT 传默认参数
ENTRYPOINT ["java", "-jar", "app.jar"]
CMD ["--spring.profiles.active=dev"]
```

**ENTRYPOINT + CMD 组合原理：**
```dockerfile
ENTRYPOINT ["java", "-jar", "app.jar"]
CMD ["--server.port=8080"]
# 默认执行：java -jar app.jar --server.port=8080
# docker run my-image --server.port=9090
# → 执行：java -jar app.jar --server.port=9090  （CMD 被覆盖，ENTRYPOINT 不动）
```

---

## 附录二：完整实操流程 / Complete Operational Flow

### 从代码到容器运行（全流程）

```bash
# 1. 构建镜像
docker build -t gongchengship/smart-invest-user-service:latest \
  -f backend/user-service/Dockerfile backend/

# 2. 检查镜像
docker images gongchengship/smart-invest-user-service
docker history gongchengship/smart-invest-user-service:latest

# 3. 运行
docker run -d --name user-service \
  -p 8081:8081 \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://postgres-host:5432/smartinvest \
  gongchengship/smart-invest-user-service:latest

# 4. 验证
docker ps | grep user-service
docker logs --tail 50 user-service
curl localhost:8081/actuator/health

# 5. 推送
docker login -u gongchengship
docker push gongchengship/smart-invest-user-service:latest
```

### 排查容器异常

```bash
# 1. 看状态
docker ps -a | grep user-service

# 2. 看日志
docker logs --tail 100 user-service

# 3. 看详情
docker inspect user-service | grep -A5 State

# 4. 如果容器能跑但应用有问题——exec 进去排查
docker exec -it user-service /bin/sh
docker exec user-service env                    # 环境变量对不对？
docker exec user-service cat /app/application.yml

# 5. 如果容器起不来——看日志 + 加 shell 覆盖启动命令
docker run -it --rm --entrypoint /bin/sh my-image
# 手动跑启动脚本看看报什么错
```

### 清理磁盘

```bash
# 先看
docker system df

# 再清
docker system prune -a --volumes -f
```

---

> **面试要点 / Key Interview Takeaways:**
>
> 1. `docker run -d --rm --name -p -e -v` 是最常用的组合，参数含义必须全知道
> 2. `docker exec` vs `docker attach` — exec 不会影响容器生命周期
> 3. `docker stop` 的信号流程：SIGTERM → 等待 → SIGKILL，跟 K8s 优雅停机原理一致
> 4. `docker build` 的 Multi-stage 和 layer caching — 为什么先 COPY 依赖文件再 COPY 源码
> 5. CMD 的 exec 形式 vs shell 形式 — PID 1 信号处理的区别
> 6. `docker system prune` 和 `docker system df` — 磁盘清理巡检
> 7. `docker save/load` — K3S 离线环境镜像导入的关键命令
