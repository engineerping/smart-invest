# Smart Invest 本地开发环境搭建指南

> 本指南帮助新用户在本地机器上快速搭建 Smart Invest 项目的完整开发环境，包括数据库、后端服务和前端应用，并自动注入种子数据。

---

## 一、环境要求

在开始之前，请确保已安装以下软件：

| 软件 | 版本要求 | 说明 |
|------|---------|------|
| Java | 21 | 后端运行依赖。建议使用 [SDKMAN](https://sdkman.io/) 管理多版本 |
| Maven | 3.9+ | 后端构建工具 |
| Node.js | 20+ | 前端运行依赖 |
| npm | 10+ | 前端包管理工具（随 Node.js 一同安装） |
| Docker | 最新版 | 用于启动本地 PostgreSQL 和 RabbitMQ |

**验证安装：**
```bash
java -version    # 应显示 Java 21.x
mvn -version     # 应显示 Maven 3.9+
node -v          # 应显示 v20.x 或更高
docker --version # 应显示最新版本
```

---

## 二、启动 PostgreSQL 数据库

Smart Invest 使用 PostgreSQL 16 作为数据库。本地开发通过 Docker 启动（无需 `docker-compose.yml`）。

### 启动数据库
```bash
docker run -d --name smart-invest-db \
  --restart unless-stopped \
  -p 5432:5432 \
  -e POSTGRES_DB=smartinvest \
  -e POSTGRES_USER=smartadmin \
  -e POSTGRES_PASSWORD=localdev_only \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:16-alpine
```

命令执行后，Docker 会：
- 下载 `postgres:16-alpine` 镜像（如未下载）
- 启动一个名为 `smart-invest-db` 的容器
- 将容器的 5432 端口映射到本地 5432 端口
- 创建 `smartinvest` 数据库

**数据库连接信息：**
| 配置项 | 值 |
|--------|-----|
| 主机 | localhost |
| 端口 | 5432 |
| 数据库名 | smartinvest |
| 用户名 | smartadmin |
| 密码 | localdev_only |

### 验证数据库是否正常
```bash
docker ps
# 应看到 smart-invest-db 容器状态为 "Up" 或 "healthy"
```

### 停止数据库
```bash
docker stop smart-invest-db
```
> 注意：`stop` 会停止容器，但不会删除持久化数据（数据存储在 `postgres_data` 数据卷中）。如需彻底删除数据，运行 `docker rm -v smart-invest-db`。

---

## 三、构建并启动后端

后端是多模块 Maven 项目，包含 6 个微服务：`common`、`user-service`、`fund-service`、`order-service`、`notification-worker`、`api-gateway`。

### 3.1 首次构建（必须）

```bash
cd backend
mvn install -DskipTests
```

此命令会编译并安装全部 6 个模块（包括共享库 `common`）到本地 Maven 仓库，以便各服务能解析依赖。

### 3.2 启动各服务

每个服务在独立终端窗口运行。入口是 `api-gateway`，端口 8080。

```bash
cd backend

# user-service — 负责数据库，启动时自动执行 Flyway 迁移（21 个）
mvn spring-boot:run -pl user-service

# fund-service
mvn spring-boot:run -pl fund-service

# order-service
mvn spring-boot:run -pl order-service

# notification-worker（消费 RabbitMQ 消息）
mvn spring-boot:run -pl notification-worker

# api-gateway — 入口（http://localhost:8080）
mvn spring-boot:run -pl api-gateway
```

**说明：**
- `-pl <service>` — 只运行指定模块
- `mvn spring-boot:run` — 相比 `java -jar`，此方式跳过打包、支持热重载、自动包含未打包的资源文件
- 当服务的 `application-local.yml` 需要时，通过环境变量设置 `SPRING_PROFILES_ACTIVE=local`（以及 `JWT_SECRET`）
- `order-service` → `notification-worker` 的消息传递需要 RabbitMQ（见下文）

### 3.3 验证后端启动成功

等待 20~40 秒后，观察日志输出。当看到以下内容时，表示启动成功：

```
Started SmartInvestApplication in X.XXX seconds
```

同时可通过网关访问健康检查端点：
```bash
curl http://localhost:8080/actuator/health
# 应返回 {"status":"UP"}
```

### 3.4 Flyway 自动注入种子数据

**无需手动执行任何脚本！** 当 `user-service` 启动时，Flyway 会自动：
1. 检测 `backend/user-service/src/main/resources/db/migration/` 目录下的 SQL 迁移文件
2. 按顺序执行所有未执行的迁移（当前共 21 个：V1–V21）
3. 自动注入所有种子数据（基金信息、NAV 历史、演示用户、持仓等）

**当前迁移文件列表：**
| 迁移文件 | 说明 |
|---------|------|
| V1~V13 | 表结构定义 |
| V14 | 11 只基金基础数据 |
| V15 | 演示用户（demo@smartinvest.com）及演示数据 |
| V16 | 种子 NAV 及演示数据 |
| V17 | 完整 NAV 历史（约 329 个交易日 × 11 只基金） |
| V18 | 基金资产/行业/地理配置及前 10 大持仓 |
| V19 | 演示订单 |
| V20 | 演示投资计划 |
| V21 | 通知表 |

### 3.5 停止后端服务
```bash
kill $(lsof -ti :8080) && echo "Backend server stopped"
```

---

## 四、启动 RabbitMQ（可选，用于订单 → 通知流程）

`order-service` 向 RabbitMQ 发布事件，`notification-worker` 消费事件。如不测试该流程可跳过。

```bash
docker run -d --name smart-invest-rabbitmq \
  -p 5672:5672 -p 15672:15672 \
  rabbitmq:3.13-management-alpine
```

管理界面：http://localhost:15672（guest/guest）。

---

## 五、启动前端

### 5.1 安装依赖
```bash
cd frontend
npm install
```

### 5.2 启动开发服务器
```bash
npm run dev
```

Vite 启动后，会在终端显示访问地址：
```
VITE v8.0.3  ready in XXX ms
➜  Local:   http://localhost:5173/
➜  Network: http://192.168.x.x:5173/
```

### 5.3 停止前端
```bash
lsof -ti:5173 | xargs kill
```

---

## 六、验证种子数据

### 6.1 通过浏览器验证

1. 打开浏览器访问：http://localhost:5173
2. 使用以下演示账号登录：
   - **邮箱：** demo@smartinvest.com
   - **密码：** Demo1234!

登录后应能看到：
- **首页** — 基金分类卡片
- **我的持仓** — 三只基金持仓，总市值约 HKD 96,523.25
- **基金列表** — 11 只基金，带当前 NAV
- **我的投资计划** — 一个活跃的月度定投计划

### 6.2 通过 API 验证（可选）

后端启动后，在新终端窗口执行：

```bash
# 验证基金列表（含 NAV，经 api-gateway 路由）
curl http://localhost:8080/api/funds

# 验证演示用户持仓汇总（需先登录获取 JWT token，见下方）
curl -H "Authorization: Bearer <token>" http://localhost:8080/api/portfolio/me/summary
```

**获取 JWT Token：**
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@smartinvest.com","password":"Demo1234!"}'
# 返回结果中包含 accessToken 字段
```

---

## 七、构建与部署脚本

项目根目录下的 `scripts/` 文件夹包含镜像构建和 K3S 部署相关脚本（本地开发无需使用）：

- `build-images.sh` / `build-amd64.sh` — 在 x86_64 构建机上打 Docker 镜像
- `deploy-k3s.sh` — 部署到 K3S 集群
- `setup-db.sh` — 在构建机上准备 PostgreSQL
- `deploy-rabbitmq.sh`、`deploy-monitoring.sh`、`k3s-dashboard-token.sh`、`cloudwatch-setup.sh`

完整部署流程见 `infrastructure/deployment-guide.md`。

---

## 八、常见问题

### Q1：启动后端时报 `JWT_SECRET` 错误
```
Could not resolve placeholder 'JWT_SECRET' in value "${JWT_SECRET}"
```
**解决方法：** 确保在启动命令中设置了环境变量：
```bash
JWT_SECRET=SmartInvestSecretKey2024ForJWTTokenSigning mvn spring-boot:run -pl user-service
```

### Q2：启动后端时报数据库连接错误
```
URL must start with 'jdbc'
```
**解决方法：** 确保添加了 `SPRING_PROFILES_ACTIVE=local` 参数，使用 `application-local.yml` 中配置的数据库连接信息。

### Q3：Flyway 迁移失败
如果看到类似以下错误：
```
Migration VXX__xxx.sql failed
```
**解决方法：**
1. 先停止后端服务
2. 检查数据库是否已有部分迁移执行：`docker exec smart-invest-db psql -U smartadmin -d smartinvest -c "SELECT version FROM flyway_schema_history ORDER BY installed_rank;"`
3. 如果需要重置，可以删除数据库容器及数据卷：
   ```bash
   docker rm -v smart-invest-db   # 删除容器及其数据卷
   # 重新启动数据库，再重启 user-service，Flyway 会从头执行所有迁移
   ```

### Q4：前端页面空白或显示 `No routes matched`
**解决方法：** 确保访问的是正确的路由。前端路由列表：
- `/` — 首页
- `/login` — 登录页
- `/funds` — 基金列表
- `/funds/:id` — 基金详情
- `/holdings` — 我的持仓
- `/plans` — 我的投资计划
- `/multi-asset` — 多资产组合
- `/build-portfolio` — 自建组合

### Q5：端口被占用
```bash
# 8080 端口（api-gateway）
kill $(lsof -ti :8080)

# 5173 端口（前端）
kill $(lsof -ti :5173)

# 5432 端口（数据库）
docker stop smart-invest-db
```

---

## 九、快速启动完整命令汇总

复制以下命令，按顺序执行即可完成全部搭建：

```bash
# 1. 启动数据库
docker run -d --name smart-invest-db \
  --restart unless-stopped -p 5432:5432 \
  -e POSTGRES_DB=smartinvest -e POSTGRES_USER=smartadmin \
  -e POSTGRES_PASSWORD=localdev_only \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:16-alpine

# 2. 构建后端（首次需要）
cd backend
mvn install -DskipTests

# 3. 启动各服务（每个服务在独立终端窗口）
mvn spring-boot:run -pl user-service      # 自动执行 Flyway 迁移
mvn spring-boot:run -pl fund-service
mvn spring-boot:run -pl order-service
mvn spring-boot:run -pl notification-worker
mvn spring-boot:run -pl api-gateway       # 入口 http://localhost:8080

# 4. 启动前端（新终端窗口）
cd frontend && npm install && npm run dev

# 5. 访问 http://localhost:5173
# 登录账号：demo@smartinvest.com / Demo1234!

# —— 停止服务 ——
# 各服务：在各自终端按 Ctrl+C
# 前端：lsof -ti:5173 | xargs kill
# 数据库：docker stop smart-invest-db
```

---

## 十、项目结构速览

```
smart-invest/
├── backend/                  # Spring Boot 后端（多模块 Maven 项目）
│   ├── common/              # 共享库
│   ├── user-service/        # 认证 + 用户 + 风险评估；Flyway 迁移（V1~V21）
│   ├── fund-service/        # 基金数据
│   ├── order-service/       # 订单
│   ├── notification-worker/ # RabbitMQ 消费者
│   └── api-gateway/         # Spring Cloud Gateway（入口）
├── frontend/                # React 前端
│   └── src/
│       ├── pages/           # 页面组件
│       ├── components/     # 公共组件
│       ├── api/             # API 客户端
│       └── types/           # TypeScript 类型定义
├── infrastructure/          # Terraform IaC + Helm charts
│   ├── terraform/           # VPC、EC2、S3、CloudFront、WAF
│   └── helm/                # umbrella chart + 子 chart
├── docs/                    # 文档目录
├── scripts/                 # 构建与部署脚本
└── .github/workflows/       # CI/CD（cd-k3s.yml）
```
