# 🏗️ Terraform 完全入门教程 —— 以 smart-invest 项目为例

> 面向对象：资深 Java 工程师 | 学习方法：用 Java 概念类比 Terraform

---

## 一、Terraform 到底是什么？它解决了什么问题？

### 1.0 起源故事 —— Mitchell Hashimoto 为什么要造 Terraform？

Terraform 的作者是 **Mitchell Hashimoto**（HashiCorp 联合创始人）。要理解他为什么要造 Terraform，需要先知道他之前造了什么。

**前传：Vagrant**

在 Terraform 之前，Mitchell 做了一个叫 **Vagrant** 的工具。Vagrant 解决的问题是：

> "我本机开发的虚拟机环境和同事的不一样，和线上服务器的也不一样，怎么统一？"

Vagrant 用 Ruby DSL 写一个 `Vagrantfile`，声明你要什么虚拟机（Ubuntu 18.04、4G 内存、安装好 MySQL），然后一条命令 `vagrant up` 就在你本机 VirtualBox/VMware 里启动一个标准化的开发环境。

**但 Vagrant 只解决了"本机开发环境"的问题，线上生产环境呢？**

2014 年的现实：
- 生产环境的服务器靠运维手动创建（登录 AWS 控制台点按钮、或者写 Bash 脚本调 AWS CLI）
- Bash 脚本只管创建不管后续——你改了配置，脚本不知道，你得再写一个更新脚本，或者手动上去改
- 没有"当前状态"的概念——谁也不知道现在线上到底有什么

**Mitchell 的洞见：**

> "Vagrant 用声明式 DSL 管理本机虚拟机的思路，能不能推广到管理真正的云基础设施？"

关键洞察是三个：

| 洞察 | 含义 | Java 类比 |
|------|------|----------|
| **声明式 > 命令式** | 说"我要什么"，而不是"一步一步怎么做" | Spring `@Bean` 声明 > `new` 对象再 `setXxx()` |
| **状态感知** | 知道上次改了什么，才能知道这次要改什么 | Hibernate EntityManager 跟踪 Entity 状态变化 |
| **一个工具管理一切** | AWS、Azure、GCP、DNS、监控...全是 API，一个 Provider 对接一个 | JDBC 一套接口，N 个数据库驱动 |

**于是有了 Terraform（2014 年 7 月开源）：**

```
Vagrant 的思路（声明式 + 状态管理）
    +
云平台 API 的适配（Provider 模式）
    =
Terraform（用代码定义一切基础设施，track 状态，自动收敛）
```

**Mitchell 自己怎么说：**

他曾在博客里写过大致意思（我浓缩）：

> "我们不应该把基础设施当作一个一个手动操作来管理。它应该像代码一样——可版本化、可审查、可自动化。Terraform 把 DevOps 运动中'基础设施即代码'的理念，从一个口号变成了一个可执行的工具。"

**一句话总结诞生的动机：**

> Mitchell 想把管理代码的那套方法论（写在文件里、版本控制、review 变更、自动部署），用到管理服务器上。他相信基础设施应该和应用程序代码一样被对待，而不是靠人点鼠标。

---

### 1.1 一个没有 Terraform 的世界

假设你要在 AWS 上部署 smart-invest 项目，你需要：

1. 登录 AWS 控制台，手动创建 VPC
2. 手动创建子网、安全组、路由表
3. 手动启动 EC2 实例，选 AMI、配置安全组
4. 手动创建 RDS 数据库
5. 手动创建 IAM 角色、绑定策略
6. 手动创建 S3 桶、CloudFront 分发
7. 手动创建 K3S 上的 Namespace、Deployment、Secret...

**问题**：
- 重复操作容易出错（这次漏了安全组规则，下次忘了绑定 IAM）
- 无法版本控制（谁知道上次改了什么配置？）
- 环境不一致（开发环境和生产环境手动操作，难免有差异）
- 团队协作困难（你怎么把"我创建了这些资源"告诉同事？）

### 1.2 类比：Java 领域的演进

**这就好比 Java 的发展历史：**

| 时代 | Java 中的做法 | 基础设施中的做法 |
|------|-------------|---------------|
| 石器时代 | 手动 `javac` 编译，手动 `java` 运行 | 手动点 AWS 控制台 |
| 脚本时代 | 写 `build.sh` 脚本编译打包 | 写 `aws cli` 脚本创建资源 |
| 构建工具 | Maven/Gradle —— 声明依赖，自动解析 | **Terraform** —— 声明资源，自动创建 |

**Terraform 对于基础设施，就像 Maven/Gradle 对于 Java 项目：**

```xml
<!-- Maven: 你声明"我需要 Spring Boot 3.2.0"，不用手动下载 jar、管理传递依赖 -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <version>3.2.0</version>
</dependency>
```

```hcl
# Terraform: 你声明"我需要一台 EC2 实例"，不用手动点控制台、选 AMI、配安全组
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.small"
}
```

**这个理念叫 Infrastructure as Code（IaC）** —— 用代码管理基础设施。代码可以版本控制、可以 review、可以复用、可以自动化。

---

### 1.3 ⭐ 关键理解：Terraform 依托于谁？—— 初学者最常混淆的概念

这是一个必须搞清楚的问题，很多人初学时都会有这个困惑：

> "Terraform 是跑在 K8S 上的吗？还是跑在 AWS 上的？它和阿里云又是什么关系？"

**答案：都不是。Terraform 是独立的 CLI 工具，不依托于任何平台。**

用 Java 领域最精准的类比：

```
┌─────────────────────────────────────────────────────────────┐
│                    你的笔记本电脑 / CI 服务器                 │
│                                                             │
│   $ terraform plan    ← 一个本地安装的 CLI 命令行工具          │
│   $ terraform apply   ← 它在你的机器上运行，不是云端            │
│                                                             │
│        │                │                │                  │
│   AWS Provider    阿里云 Provider   K8S Provider            │
│   (插件/驱动)       (插件/驱动)      (插件/驱动)              │
│        │                │                │                  │
│        ▼                ▼                ▼                  │
│   AWS API 服务器   阿里云 API 服务器   K8S API Server        │
│   (云端)           (云端)            (你的 K3S 集群)         │
│        │                │                │                  │
│        ▼                ▼                ▼                  │
│   EC2, RDS, VPC    ECS, RDS, VPC    Pod, Service, Deploy   │
│   (AWS 上的资源)    (阿里云上的资源)   (K8S 上的资源)         │
└─────────────────────────────────────────────────────────────┘
```

**Java 类比：JDBC 驱动模型**

```java
// 你问："JDBC 是依托于 MySQL 还是 PostgreSQL？"
// 答案：都不是。JDBC 是一套接口标准，你的 Java 代码通过不同的"驱动"连接不同的数据库。

// 连接 MySQL
Connection conn1 = DriverManager.getConnection("jdbc:mysql://host1/db");
// 连接 PostgreSQL
Connection conn2 = DriverManager.getConnection("jdbc:postgresql://host2/db");
// 连接 Oracle
Connection conn3 = DriverManager.getConnection("jdbc:oracle://host3/db");

// MySQL、PostgreSQL、Oracle 是平级的、互相独立的数据库。
// 你的 Java 程序不依存于任何一个数据库，只是通过对应的驱动去连接它。
```

**Terraform 完全一样：**

```hcl
# 通过 AWS Provider 管理 AWS 资源
provider "aws" {
  region = "us-east-1"
}
resource "aws_instance" "app" { ... }    # 调用 AWS API，创建 EC2

# 通过 阿里云 Provider 管理 阿里云资源
provider "alicloud" {
  region = "cn-hangzhou"
}
resource "alicloud_instance" "app" { ... } # 调用 阿里云 API，创建 ECS

# 通过 K8S Provider 管理 K8S 资源
provider "kubernetes" {
  config_path = "~/.kube/config"
}
resource "kubernetes_deployment" "app" { ... } # 调用 K8S API，创建 Deployment
```

**关键结论（务必记住）：**

| 概念 | 关系 | 类比 |
|------|------|------|
| Terraform CLI | 独立工具，不依托任何平台 | Java 程序本身（可运行在任何机器上） |
| Provider | Terraform 的插件，负责调用某个平台的 API | JDBC 驱动（`mysql-connector-java`） |
| AWS / 阿里云 / K8S | 被管理的目标平台，互相平级、独立 | MySQL / PostgreSQL / Oracle |
| Terraform State | 记录资源状态的 JSON 文件，存在本地或 S3 等远端 | Hibernate 的持久化上下文 / 数据库本身 |

**所以 smart-invest 项目的架构是这样的：**

```
Terraform（在你的机器上运行）
    │
    ├── 任务 1：用 AWS Provider 创建云基础设施
    │       创建 VPC → 创建 EC2 → 创建 RDS → 创建 S3 + CloudFront
    │       （资源在 AWS 云上）
    │
    └── 任务 2：用 K8S Provider 在已建好的 K3S 集群上部署应用
            创建 Namespace → 创建 ConfigMap → 创建 Secret → 创建 Deployment
            （资源在 K3S 集群上，K3S 集群跑在 AWS EC2 上）
```

**注意这里的层次关系：** K3S 运行在 EC2 虚拟机之上，但 Terraform 对两者的管理是**平级且独立的**——它用 `aws` provider 创建 EC2，用 `kubernetes` provider 在 K3S 上部署应用。Terraform 自己不运行在 AWS 也不运行在 K8S 上。

### 1.4 ⭐⭐ 进阶澄清：被管理的平台需要满足统一规范吗？

上一个问题解答了"Terraform 不依托于任何平台"，你可能会进一步追问：

> "那 AWS、阿里云、K8S 这些平台，是不是都要遵循某个统一规范（比如 K8S 规范），才能被 Terraform 管理？"

**答案：完全不需要。每个平台的 API 各不相同，没有任何交集。**

**Java 类比——JDBC 再一次登场：**

```java
// JDBC 定义了一套 Client 端的标准接口
public interface Connection {
    Statement createStatement();
    PreparedStatement prepareStatement(String sql);
    // ...
}

// 但 MySQL 和 PostgreSQL 的通信协议完全不同！
// MySQL 驱动：把 JDBC 调用翻译成 MySQL 二进制协议
import com.mysql.cj.jdbc.MysqlConnection;

// PostgreSQL 驱动：把 JDBC 调用翻译成 PostgreSQL 二进制协议
import org.postgresql.jdbc.PgConnection;

// MySQL 和 PostgreSQL 之间没有任何共同规范。
// JDBC 接口只存在于你的 Java 进程里，不是服务器端的要求。
```

**Terraform 完全一样：**

```
Terraform（Client 端统一语法）
    │
    │  "resource" / "variable" / "output"  ← 这些只是 .tf 文件的语法
    │  Provider 负责把这些语法翻译成目标平台的 API 调用
    │
    ├── AWS Provider
    │   翻译 .tf → AWS REST API（XML/JSON，AWS 自己的协议）
    │   AWS 服务器完全不知道 Terraform 的存在
    │
    ├── 阿里云 Provider
    │   翻译 .tf → 阿里云 REST API（JSON，阿里云自己的协议）
    │   阿里云服务器完全不知道 Terraform 的存在
    │
    └── K8S Provider
        翻译 .tf → K8S REST API（YAML/JSON，K8S 自己的协议）
        K8S API Server 完全不知道 Terraform 的存在
```

**关键结论：**

| 问题 | 答案 |
|------|------|
| Terraform 有统一的 Client 端语法吗？ | ✅ 有。`.tf` 文件的写法是统一的，`resource`/`variable`/`output` 等关键字对所有 Provider 都一样 |
| 各平台 API 有统一的规范吗？ | ❌ 完全没有。AWS API、阿里云 API、K8S API 是三个截然不同的协议 |
| Provider 存在的意义是什么？ | 做**翻译**——把统一的 HCL 语法翻译成各平台自己的 API 调用 |
| 这和 K8S 有什么关系？ | **没有任何关系。** AWS API 不需要满足 K8S 规范，阿里云 API 也不需要。K8S 只是 Terraform 可以管理的众多目标平台之一 |

**一句话总结：Terraform 的统一性只存在于 Client 端（`.tf` 语法），不对 Server 端（各平台的 API）提任何要求。**

这也是为什么每个 Provider 的资源类型完全不一样：

```hcl
# AWS 的资源类型（按 AWS 自己的产品来）
resource "aws_instance"   { ... }   # EC2 虚拟机
resource "aws_db_instance" { ... }  # RDS 数据库
resource "aws_s3_bucket"   { ... }  # S3 存储桶

# 阿里云的资源类型（按阿里云自己的产品来）
resource "alicloud_instance" { ... }  # ECS 虚拟机
resource "alicloud_db_instance" { ... } # RDS 数据库
resource "alicloud_oss_bucket" { ... }  # OSS 存储桶

# K8S 的资源类型（按 K8S 自己的资源来）
resource "kubernetes_deployment" { ... }  # Deployment
resource "kubernetes_service"     { ... }  # Service
resource "kubernetes_config_map"  { ... }  # ConfigMap
```

**三种资源类型完全不可互换**——`aws_instance` 不能用在阿里云上，`kubernetes_deployment` 不能用在 AWS 上。每个 Provider 只管理自己那个平台的东西，平台之间不需要知道彼此存在。

### 1.5 ⭐⭐⭐ 终极追问：那平台 API 到底要满足什么条件才能被 Terraform 管理？

你的追问非常精准：

> "JDBC 连接数据库，数据库好歹遵循 SQL 标准。Terraform 调用各种平台的 API，这些 API 起码得遵循一个什么标准吧？总不能去调用一个银行转账的 API 吧？"

**答案：不要求平台遵循某个 API 风格标准（REST/gRPC/SOAP 都行），只要求一个抽象契约——资源必须支持 CRUD 生命周期。**

而且，**Terraform 确实可以去调用银行转账的 API**——只要那个转账动作可以抽象为"创建一笔转账记录"的话。事实上，Terraform 能管理 GitHub Repo、Datadog 监控规则、PagerDuty 排班表、Cloudflare DNS 记录……这些完全不属于"基础设施"的东西。

---

#### 先修正 JDBC 类比

SQL 确实是一个标准（ANSI SQL-92/99），但 JDBC 不要求数据库遵循 SQL。反例：**MongoDB JDBC 驱动**——MongoDB 没有一行 SQL 解析器，它的查询语言是 BSON。JDBC 驱动之所以能工作，是因为它只需要数据库提供最底层的抽象能力：

```
往里面存数据   ──►  CREATE / INSERT
从里面读数据   ──►  READ / SELECT
修改已有数据   ──►  UPDATE
删除数据       ──►  DELETE
```

SQL 只是实现这个能力的一种方式，不是唯一方式。MongoDB 用自己的方式也一样能做 CRUD。

---

#### Terraform 的"统一标准"——Provider 侧的 CRUD 契约

**核心原理：平台不需要遵守什么标准，遵守标准的是 Provider。**

Terraform 的 Provider 开发框架（Terraform Plugin SDK）定义了一套抽象的生命周期方法，**每个 Provider 必须为它管理的每种资源类型实现这四个方法**：

```go
// 这是 Terraform Plugin SDK 定义的 Provider 内部接口（Go 代码示意）
// 每个 Provider 都要为每种资源实现这些方法

type Resource interface {
    // CREATE —— 对应 terraform apply（资源在 .tf 里有，state 里没有）
    //     Provider 调用平台的"创建资源"API
    Create(ctx context.Context, req CreateRequest) (*CreateResponse, error)

    // READ —— 对应 terraform refresh / plan（把实际状态读回来对比）
    //     Provider 调用平台的"查询资源详情"API
    Read(ctx context.Context, req ReadRequest) (*ReadResponse, error)

    // UPDATE —— 对应 terraform apply（资源属性变了，但资源本身还在）
    //     Provider 调用平台的"修改资源"API
    Update(ctx context.Context, req UpdateRequest) (*UpdateResponse, error)

    // DELETE —— 对应 terraform destroy 或 .tf 里删除了某个 resource 块
    //     Provider 调用平台的"删除资源"API
    Delete(ctx context.Context, req DeleteRequest) error
}
```

**这就是你要找的"标准"。** 但不是平台 API 的标准，而是 **Terraform Provider SDK 的标准**。

---

#### 用这张图彻底讲清楚

```
┌──────────────────────────────────────────────────────────────┐
│                    Terraform 世界                              │
│                                                              │
│  .tf 文件（用户写的期望状态）                                    │
│      resource "aws_instance" "app" { ... }                   │
│                                                              │
│  Terraform Core                                              │
│      对比 state vs .tf → 算出哪个资源要 Create/Update/Delete    │
│      然后调用 Provider 的对应方法                               │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Provider SDK（Terraform 的内部标准！这就是你要找的东西）│    │
│  │                                                      │    │
│  │  func Create() { ... }     ← CREATE                  │    │
│  │  func Read()   { ... }     ← READ                    │    │
│  │  func Update() { ... }     ← UPDATE                  │    │
│  │  func Delete() { ... }     ← DELETE                  │    │
│  │                                                      │    │
│  │  ↑ 这个 CRUD 接口是 Terraform 对 Provider 的唯一要求  │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                         │                                     │
│        每个 Provider 的实现各不相同                             │
│                         │                                     │
│  ┌──────────────────────┼───────────────────────────────┐    │
│  │  AWS Provider    │  阿里云 Provider  │  K8S Provider  │    │
│  │  (Go 代码)       │  (Go 代码)         │  (Go 代码)     │    │
│  │                  │                    │               │    │
│  │  Create() {      │  Create() {        │  Create() {   │    │
│  │    call AWS      │    call 阿里云     │    call K8S   │    │
│  │    REST API      │    REST API        │    REST API   │    │
│  │    POST /ec2     │    POST /ecs       │    POST /api  │    │
│  │  }               │  }                 │  }            │    │
│  └──────┬───────────┴──────┬─────────────┴──────┬────────┘    │
└─────────┼──────────────────┼───────────────────┼─────────────┘
          │                  │                    │
          ▼                  ▼                    ▼
     AWS API Server    阿里云 API Server    K8S API Server
     (AWS 自己的协议)   (阿里云自己的协议)   (K8S 自己的协议)
```

**拆解这张图的关键信息：**

| 层级 | 谁规定的 | 类比 |
|------|---------|------|
| `.tf` 文件语法 | Terraform 自己 | Java 语法规范 |
| Provider SDK 的 CRUD 接口 | Terraform Plugin SDK | JDBC 接口规范（`Connection`, `Statement`, `ResultSet`） |
| 每个 Provider 的 Create/Read/Update/Delete 实现 | Provider 开发者（HashiCorp 或社区） | MySQL JDBC 驱动、PostgreSQL JDBC 驱动 |
| 各平台的 HTTP API | 平台自己（AWS/阿里云/K8S/...） | MySQL Wire Protocol、PostgreSQL Wire Protocol |

---

#### 回到你的核心问题："这些提供 API 的平台，要满足一个什么标准？"

**答案拆成两点：**

**1. 平台 API 层面——不需要遵守任何单一的 API 协议标准**

AWS 的 API 可以是用 XML/JSON 的 REST、阿里云的 API 可以是用 JSON 的 REST、K8S 的 API 是 YAML/JSON 的 RESTful 风格——它们互不兼容，没有共同规范。也可以不是 REST！只要 Provider 的 Go 代码能通过 HTTP/gRPC/命令行调用它就行。

**2. 抽象层面——只要求平台提供的功能能被映射为"有状态的资源 + CRUD 操作"**

这才是真正的门槛。如果一个平台（比如纯计算的函数）没有"状态"的概念，就很难做 Terraform Provider。

| 能包装成 Terraform Provider | 不能 / 很难包装成 Terraform Provider |
|---------------------------|----------------------------------|
| AWS EC2（有状态：创建/查询/修改/删除虚拟机） | 纯 Serverless 函数的单次调用（无状态，调完就没了） |
| GitHub Repo（有状态：创建/查/修改/删除仓库） | 银行转账 API（有状态，但不是"资源"，是"动作"） |
| Datadog Monitor（有状态：创建/查/修改/删除告警） | Slack 发一条消息（更接近一次性动作） |
| Cloudflare DNS（有状态：创建/查/修改/删除 DNS 记录） | 调用一个 OCR 识别 API（无状态转换） |

**注意边界：** 银行转账确实不适合直接用 Terraform 管理，但 Terraform 管理的 GitHub Actions 可能**触发**这个转账 API。Terraform 管的不是"转账动作"，而是"这个 GitHub Actions 流水线的配置"。

---

#### 总结：三句话让你彻底不困惑

| 问题 | 一句话答案 |
|------|----------|
| Terraform 有统一标准吗？ | 有，在 **Provider SDK** 层（CRUD 四个方法），不在平台 API 层 |
| 平台要满足什么条件？ | 提供的功能能抽象成**有状态的资源**（创建后持续存在、能查、能改、能删） |
| Provider 是干什么的？ | 把平台的 HTTP 请求/响应包进 SDK 规定的 CRUD 方法里，做协议翻译 |

---

## 二、核心概念 —— 用 Java 来理解

### 2.1 四个核心概念

| Terraform 概念 | Java 类比 | 解释 |
|---------------|----------|------|
| **Provider** | JDBC 驱动 | 连接某个平台的"驱动"。AWS Provider 连 AWS，Kubernetes Provider 连 K8S。就像 `mysql-connector-java` 让 Java 能操作 MySQL |
| **Resource** | `new` 一个对象 | 你要创建的东西。`resource "aws_instance"` ≈ `new EC2Instance()` |
| **Variable** | 方法参数 / `application.yml` | 可配置的输入。`variable "region"` ≈ `application.yml` 里的 `app.region` |
| **Output** | 方法返回值 | 创建后暴露给外部的信息。`output "public_ip"` ≈ `getPublicIp()` |
| **Module** | Java Package / 工具类 | 把一组资源封装成可复用的组件。`module "vpc"` ≈ 引入一个 `VpcUtils` 工具类 |

### 2.2 State（状态文件）—— Terraform 的"数据库"

这是最重要的概念，很多人都忽略它。

**类比：Hibernate 的持久化上下文**

Hibernate 管理 Entity 的状态（transient → persistent → detached），通过 EntityManager 跟踪哪些对象被修改了，最后生成 UPDATE SQL。

Terraform 也一样：它有一个 **state 文件**（`terraform.tfstate`），记录了"上次 apply 之后，实际创建了哪些资源、它们的属性是什么"。当你修改 `.tf` 文件后执行 `terraform plan`，Terraform 会：

1. 读 state 文件（上次的实际状态）
2. 读 `.tf` 文件（你期望的新状态）
3. **对比两者**，计算出需要执行的操作（CREATE / UPDATE / DELETE）

```
.tf 文件（期望状态）──┐
                      ├──► Terraform Core ──► 差异计划 (plan)
state 文件（实际状态）──┘
```

**就像 Hibernate 的 dirty checking：** 你修改了 Entity 的属性，Hibernate 自动算出需要生成哪些 UPDATE 语句。Terraform 也一样，你改了 `.tf` 里的 `instance_type`，它知道只需要 UPDATE 这个属性。

---

## 三、动手看代码 —— 逐文件解析

让我们用这个项目的真实代码来学习。先看目录结构：

```
infrastructure/
├── providers.tf          ← 声明用哪些 Provider（类似 pom.xml 的 <dependencies>）
├── variables.tf          ← 全局变量（类似 application.yml）
├── main.tf               ← 组装所有模块（类似 Spring 的 @Configuration + @Bean）
├── outputs.tf            ← 全局输出（类似 Actuator 的 /info 端点）
├── modules/              ← 可复用的模块（类似 Java 的 package）
│   ├── vpc/              ← VPC 网络模块
│   │   ├── main.tf       ←   资源定义
│   │   ├── variables.tf  ←   输入参数
│   │   └── outputs.tf    ←   输出值
│   ├── ec2/              ← EC2 服务器模块
│   ├── rds/              ← RDS 数据库模块
│   ├── iam/              ← IAM 权限模块
│   └── s3-cloudfront/    ← S3 + CDN 模块
└── terraform-k3s/        ← K3S 集群管理（另一个 Terraform 项目）
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

### 3.1 `providers.tf` —— 声明 Provider

```hcl
# 类比：pom.xml 里声明依赖
# <dependency>
#   <groupId>com.amazonaws</groupId>
#   <artifactId>aws-sdk-java</artifactId>
#   <version>2.0</version>
# </dependency>

terraform {
  required_version = ">= 1.9"        # 要求 Terraform CLI 版本 ≥ 1.9
  required_providers {
    aws = {
      source  = "hashicorp/aws"      # Provider 来源（类似 Maven 的 groupId/artifactId）
      version = "~> 5.0"             # 版本约束：≥ 5.0 且 < 6.0
    }
  }
}

provider "aws" {
  region = var.aws_region            # 配置这个 Provider（类似 application.yml）
}
```

**关键理解：** `terraform {}` 块声明"我需要哪些 Provider"（编译期依赖），`provider {}` 块配置 Provider 的具体参数（运行时配置）。

### 3.2 `variables.tf` —— 输入变量

```hcl
# 类比：Spring Boot 的 @ConfigurationProperties
# @ConfigurationProperties(prefix = "app")
# public class AppConfig {
#     private String region = "us-east-1";    // 默认值
#     private String environment = "prod";
#     private String adminCidr;               // 必填，无默认值
# }

variable "aws_region"   { default = "us-east-1" }
variable "environment"  { default = "prod" }
variable "admin_cidr"   { description = "Your IP in CIDR format, e.g. 1.2.3.4/32" }
variable "key_pair_name"{ description = "EC2 SSH key pair name (created in AWS console)" }
variable "account_id"   { description = "AWS account ID" }
```

变量的值可以通过以下方式传入（优先级从高到低）：

```bash
# 方式 1：命令行（最高优先级）
terraform apply -var="aws_region=us-west-2"

# 方式 2：tfvars 文件（推荐）
# terraform.tfvars:
aws_region  = "us-west-2"
environment = "staging"

# 方式 3：环境变量
export TF_VAR_aws_region=us-west-2

# 方式 4：默认值（最低优先级）
# 即 variables.tf 里的 default
```

### 3.3 Module —— 最重要的复用机制

这是整个项目最精彩的部分。让我们深入看 VPC 模块。

#### 模块定义：`modules/vpc/main.tf`

```hcl
# ============================================
# 类比：一个 Java 工具类 VpcBuilder
# public class VpcBuilder {
#     public VpcResult build(String region, String adminCidr) {
#         // 创建 VPC、子网、网关、安全组...
#         return new VpcResult(vpcId, publicSubnetId, ...);
#     }
# }
# ============================================

# 1️⃣ 创建一个 VPC —— 类比：创建一个网络容器
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"        # IP 范围：10.0.0.0 ~ 10.0.255.255（65536 个 IP）
  enable_dns_hostnames = true
  tags = { Name = "smart-invest-vpc" }
}

# 2️⃣ 创建公有子网 —— 类比：VPC 内的一个网段
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id   # 引用上面 VPC 的 ID（自动计算依赖顺序！）
  cidr_block              = "10.0.1.0/24"     # 256 个 IP
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true              # 这个子网里的实例自动获得公网 IP
}

# 3️⃣ 创建私有子网 —— 数据库放这里，不暴露公网
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}a"
}

# 4️⃣ 互联网网关 —— 让公有子网能访问互联网
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# 5️⃣ 路由表 —— 定义流量怎么走
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"                 # 所有出站流量
    gateway_id = aws_internet_gateway.igw.id  # 走互联网网关
  }
}

# 6️⃣ 安全组（EC2）—— 类比：Linux 的 iptables 防火墙规则
resource "aws_security_group" "ec2" {
  name   = "smart-invest-ec2-sg"
  vpc_id = aws_vpc.main.id

  ingress {                                   # 入站规则
    from_port   = 443                         # HTTPS
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]              # 允许所有人访问 HTTPS
  }
  ingress {
    from_port   = 22                          # SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]            # 只有管理员 IP 能 SSH
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"                        # -1 = 所有协议
    cidr_blocks = ["0.0.0.0/0"]              # 允许所有出站流量
  }
}

# 7️⃣ 安全组（RDS）—— 数据库安全组
resource "aws_security_group" "rds" {
  name   = "smart-invest-rds-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 5432                    # PostgreSQL 端口
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]  # 只允许 EC2 的安全组访问数据库
  }
}
```

#### 模块输入：`modules/vpc/variables.tf`

```hcl
variable "region"     {}   # 没有 default，调用者必须传值
variable "admin_cidr" {}
```

#### 模块输出：`modules/vpc/outputs.tf`

```hcl
# 类比：Java 方法的返回值
# public VpcResult build(...) {
#     return new VpcResult(vpcId, publicSubnetId, ec2SgId, ...);
# }

output "vpc_id"            { value = aws_vpc.main.id }
output "public_subnet_id"  { value = aws_subnet.public.id }
output "private_subnet_id" { value = aws_subnet.private.id }
output "ec2_sg_id"        { value = aws_security_group.ec2.id }
output "rds_sg_id"        { value = aws_security_group.rds.id }
```

#### 模块调用：`main.tf` 组装一切

```hcl
# 类比：Spring 的依赖注入
# @Configuration
# public class InfraConfig {
#     @Bean
#     public VpcResult vpc() {
#         return new VpcBuilder().build(region, adminCidr);
#     }
#
#     @Bean
#     public DatabaseResult database(VpcResult vpc) {  // 自动注入 VpcResult
#         return new DatabaseBuilder()
#             .subnetIds(vpc.publicSubnetId, vpc.privateSubnetId)
#             .securityGroup(vpc.rdsSgId)
#             .build();
#     }
#
#     @Bean
#     public Ec2Result ec2(VpcResult vpc, DatabaseResult db, IamResult iam) {
#         return new Ec2Builder()
#             .subnet(vpc.publicSubnetId)
#             .securityGroup(vpc.ec2SgId)
#             .instanceProfile(iam.instanceProfileName)
#             .dbSecret(db.dbSecretArn)
#             .build();
#     }
# }

module "vpc" {
  source     = "./modules/vpc"          # 模块路径
  region     = var.aws_region           # 传入参数
  admin_cidr = var.admin_cidr
}

module "iam" {
  source = "./modules/iam"
}

module "rds" {
  source     = "./modules/rds"
  subnet_ids = [module.vpc.public_subnet_id, module.vpc.private_subnet_id]  # 引用 VPC 模块的输出！
  rds_sg_id  = module.vpc.rds_sg_id                                          # 引用 VPC 模块的输出！
}

module "ec2" {
  source                = "./modules/ec2"
  public_subnet_id      = module.vpc.public_subnet_id
  ec2_sg_id             = module.vpc.ec2_sg_id
  instance_profile_name  = module.iam.instance_profile_name
  db_secret_arn         = module.rds.db_secret_arn    # 也引用了 RDS 模块的输出
  # ...
}
```

**这就是 Terraform 最强大的地方：依赖自动推导。**

你看代码里没有显式的 `depends_on`，但 Terraform 通过 `module.vpc.public_subnet_id` 这个引用，自动算出执行顺序：

```
1. 先创建 VPC 模块（没有依赖）
2. 然后创建 IAM 模块（没有依赖，可以与 VPC 并行）
3. 然后创建 RDS 模块（依赖 VPC 的输出）
4. 最后创建 EC2 模块（依赖 VPC + IAM + RDS 的输出）
```

这就像 Spring 的依赖图自动决定 Bean 的初始化顺序，不需要你手动排序。

### 3.4 Data Source —— 读取已有资源

```hcl
# 类比：JPA Repository 的 findById()
# Optional<Ami> ami = amiRepository.findLatest("al2023");

data "aws_ami" "al2023" {
  most_recent = true                    # 取最新的
  owners      = ["amazon"]              # 官方 Amazon 发布的 AMI
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]   # 按名称过滤
  }
}

# 然后可以像 resource 一样引用它
resource "aws_instance" "app" {
  ami = data.aws_ami.al2023.id         # 使用 Data Source 查到的 AMI ID
  # ...
}
```

**Resource vs Data Source 的区别：**

| | Resource | Data Source |
|---|---|---|
| 类比 | `new User("张三")` — 创建新的 | `userRepo.findById(1)` — 查询已有的 |
| 操作 | CREATE / UPDATE / DELETE | READ ONLY |
| 例子 | 我要创建一台 EC2 | 我要查询已有的 AMI ID |
| 关键词 | `resource` | `data` |

---

## 四、常用命令 —— 你的日常工具箱

### 4.1 核心工作流

```bash
# ============================================
# 类比 Maven：mvn clean compile test package
# ============================================

# 1️⃣ 初始化 —— 类比 mvn clean install（下载依赖）
# 下载需要的 Provider 插件（aws, kubernetes, helm 等）
terraform init

# 2️⃣ 格式化 —— 类比 IDE 的 Ctrl+Alt+L
# HCL 代码自动格式化
terraform fmt

# 3️⃣ 校验 —— 类比 mvn compile（检查语法）
# 检查 .tf 文件语法是否正确
terraform validate

# 4️⃣ 计划 —— 类比 mvn test（只跑不部署）
# 预览将要执行的操作（不会真的创建/修改资源）
# ⭐ 这是 Terraform 最重要的命令，每次 apply 前必跑！
terraform plan

# 5️⃣ 应用 —— 类比 mvn deploy（真正部署）
# 真正执行变更，创建/修改/删除云资源
terraform apply

# 6️⃣ 销毁 —— 类比 Maven 没有这个，相当于删除所有资源
# 删除所有创建的资源（慎用！）
terraform destroy
```

### 4.2 `terraform plan` 输出示例（非常重要！）

当你运行 `terraform plan`，你会看到类似这样的输出：

```
Terraform will perform the following actions:

  # aws_instance.app will be created
  + resource "aws_instance" "app" {
      + ami                    = "ami-0c55b159cbfafe1f0"
      + instance_type          = "t3.small"
      + subnet_id              = "subnet-abc123"
      ...
    }

  # aws_security_group.ec2 will be updated in-place
  ~ resource "aws_security_group" "ec2" {
        id   = "sg-xyz789"
      ~ ingress {
          - from_port   = 80  -> null         # 删除 80 端口
          + from_port   = 443                 # 新增 443 端口
        }
    }

Plan: 1 to add, 1 to change, 0 to destroy.
```

**符号含义：**
- `+` — 将要创建（CREATE）
- `~` — 将要原地修改（UPDATE in-place，不重建）
- `-/+` — 将要先删后建（DELETE then CREATE，资源必须重建）
- `-` — 将要删除（DELETE）

### 4.3 其他常用命令

```bash
# 查看当前 State 中的所有资源
terraform state list

# 查看某个资源的详细信息
terraform state show aws_instance.app

# 查看所有 Output 的值
terraform output

# 查看某个 Output
terraform output ec2_public_ip

# 手动导入已有资源（把已经在 AWS 上的资源纳入 Terraform 管理）
terraform import aws_instance.app i-0c55b159cbfafe1f0

# 刷新 State（只读操作，更新 state 文件以反映实际资源状态）
terraform refresh

# 解锁被中断操作锁定的 State
terraform force-unlock <LOCK_ID>
```

---

## 五、Terraform 的 K8S/K3S 管理

这个项目还有一个 `terraform-k3s/` 目录，展示了 Terraform 的另一面——不只管理云资源。

```hcl
# 用 Kubernetes Provider 管理 K3S 集群内的资源
# 类比：不只用 AWS SDK 管理 EC2，还用 kubectl 管理 Pod

provider "kubernetes" {
  config_path = var.kubeconfig_path    # 指向 K3S 的 kubeconfig
}

# 创建 Namespace —— 类比 kubectl create namespace smart-invest
resource "kubernetes_namespace" "app" {
  metadata {
    name = "smart-invest"
  }
}

# 创建 Deployment —— 类比 kubectl apply -f deployment.yaml
resource "kubernetes_deployment" "user_service" {
  metadata {
    name      = "user-service"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  spec {
    replicas = var.replicas
    # ...
    template {
      spec {
        container {
          name  = "user-service"
          image = "gongchengship/smart-invest-user-service:${var.image_tag}"
          port {
            container_port = 8081
          }
        }
      }
    }
  }
}
```

**关键启示：** Terraform 的能力不限于 AWS。只要有 Provider，就能管理。就像 JDBC 让 Java 能操作 MySQL、PostgreSQL、Oracle —— Provider 让 Terraform 能管理 AWS、Azure、GCP、Kubernetes、GitHub、Datadog、Cloudflare...

---

## 六、最佳实践总结

### 6.1 文件组织规范

| 文件 | 放什么 | 类比 |
|------|-------|------|
| `providers.tf` | Provider 声明和配置 | `pom.xml` 的 `<dependencies>` |
| `variables.tf` | 输入变量 | `application.yml` |
| `outputs.tf` | 输出值 | Controller 的 `@GetMapping` 返回值 |
| `main.tf` | 组装模块 | `@Configuration` + `@Bean` |
| `terraform.tfvars` | 具体变量值（不提交 Git） | `application-prod.yml` |
| `versions.tf` | 版本约束（也可以合到 providers.tf） | `pom.xml` 的 `<properties>` |

### 6.2 模块化原则

```
❌ 不好的做法：一个巨大的 main.tf，几百行资源定义
✅ 好的做法：按功能拆成模块

infrastructure/
└── modules/
    ├── vpc/         ← 网络层（可复用于其他项目）
    ├── ec2/         ← 计算层
    ├── rds/         ← 数据库层
    ├── iam/         ← 权限层
    └── s3-cloudfront/ ← CDN 层
```

### 6.3 安全规则

```hcl
# ❌ 不要把敏感信息硬编码
variable "db_password" {
  default = "MySecret123"    # 密码会进 Git 历史！
}

# ✅ 用 sensitive 标记 + 从外部传入
variable "db_password" {
  type      = string
  sensitive = true             # 不会在 plan/apply 输出中显示
  # 没有 default，强制从外部传入
}

# ✅ 或使用 Terraform Vault / AWS Secrets Manager
```

### 6.4 State 管理

```
❌ 本地 State（单兵作战）：terraform.tfstate 在本地
✅ 远程 State（团队协作）：State 存 S3/DynamoDB，多人共享 + 并发锁

# 配置远程 State（类比：共享数据库而不是本地文件）
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "smart-invest/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"  # 并发锁，防止两人同时 apply
  }
}
```

---

## 七、一张图总结

```
                        你的 .tf 代码
                    （声明你想要什么状态）
                            │
                            ▼
                    ┌───────────────┐
                    │  Terraform    │
                    │    Core       │
                    │               │
                    │  对比期望 vs 实际  │◄──── terraform.tfstate
                    │  生成执行计划     │     （记录当前实际状态）
                    └───────┬───────┘
                            │
                   ┌────────┼────────┐
                   ▼        ▼        ▼
               AWS API   Azure API  K8S API
              (Provider) (Provider) (Provider)
                   │        │        │
                   ▼        ▼        ▼
                云资源 1   云资源 2   K8S 资源
```

**核心理念：** 你写代码描述你想要的最终状态（Declarative），Terraform 负责算出从当前状态到目标状态的路径（Reconciliation）。你不需要写"第一步创建 VPC，第二步创建子网..."——你只写"我要一个 VPC 和一个子网"，Terraform 自动处理顺序和依赖。

---

## 八、下一步学什么

1. **动手实验** —— 在这个项目的 `infrastructure/` 目录跑一遍 `terraform init && terraform plan`（不会创建资源，只是预览）
2. **学 HCL 表达式** —— 条件 `count`、循环 `for_each`、函数 `lookup()`、模板 `templatefile()`
3. **学 State 管理** —— 远程 Backend（S3 + DynamoDB）、State 导入/迁移
4. **学 CI/CD 集成** —— Terraform Cloud、Atlantis、GitHub Actions 自动 apply
