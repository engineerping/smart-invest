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
| Docker | 最新版 | 用于启动本地 PostgreSQL 数据库 |
| Python | 3.10+ | 用于运行数据填充脚本（可选） |

**验证安装：**
```bash
java -version    # 应显示 Java 21.x
mvn -version     # 应显示 Maven 3.9+
node -v          # 应显示 v20.x 或更高
docker --version # 应显示最新版本
```

---

## 二、启动 PostgreSQL 数据库

Smart Invest 使用 PostgreSQL 16 作为数据库。本地开发通过 Docker 启动。

### 启动数据库
```bash
cd /path/to/smart-invest   # 项目根目录
docker compose up -d postgres
```

命令执行后，Docker 会：
- 下载 `postgres:16-alpine` 镜像（如未下载）
- 启动一个名为 `smart-invest-db` 的容器
- 将容器的 5432 端口映射到本地 5432 端口
- 创建 `smartinvest` 数据库

**数据库连接信息（已写在 `docker-compose.yml` 中）：**
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
docker compose down
```
> 注意：`down` 会停止并删除容器，但不会删除持久化数据（数据存储在 Docker Volume 中）。

---

## 三、构建并启动后端

### 3.1 首次构建（必须）

由于项目采用多模块 Maven 结构，必须先将各子模块安装到本地 Maven 仓库，主模块才能找到依赖。


```bash
#### 方式 3.1.1: 单行命令
cd backend && mvn install -DskipTests && cd app && mvn spring-boot:run -Dspring-boot.run.profiles=local 2>&1 | tail -40;

#### 或者
#### 方式 3.1.2: 分步骤命令
cd backend
mvn install -DskipTests
```

### 3.2 启动后端服务

```bash
cd backend
SPRING_PROFILES_ACTIVE=local JWT_SECRET=SmartInvestSecretKey2024ForJWTTokenSigning mvn spring-boot:run -pl app
```

**启动参数说明：**
- `SPRING_PROFILES_ACTIVE=local` — 激活 `application-local.yml` 配置，使用本地数据库连接
- `JWT_SECRET=...` — JWT 签名密钥，必须设置否则服务无法启动
- `-pl app` — 只运行 `app` 模块
- `mvn spring-boot:run` — 相比 `java -jar`，此方式跳过打包、支持热重载、自动包含未打包的资源文件

### 3.3 验证后端启动成功

等待 20~40 秒后，观察日志输出。当看到以下内容时，表示启动成功：

```
Started SmartInvestApplication in X.XXX seconds
```

同时可以访问健康检查端点：
```bash
curl http://localhost:8080/actuator/health
# 应返回 {"status":"UP"}
```

### 3.4 Flyway 自动注入种子数据

**无需手动执行任何脚本！** 当 Spring Boot 启动时，Flyway 会自动：
1. 检测 `backend/app/src/main/resources/db/migration/` 目录下的 SQL 迁移文件
2. 按顺序执行所有未执行的迁移（当前共 17 个）
3. 自动注入所有种子数据（基金信息、NAV 历史、演示用户、持仓等）

**当前迁移文件列表：**
| 迁移文件 | 说明 |
|---------|------|
| V1~V12 | 表结构定义 |
| V13 | 11 只基金基础数据 |
| V14 | 演示用户（demo@smartinvest.com）及初始持仓 |
| V15 | 回填基金当前 NAV |
| V16 | 完整 NAV 历史（约 329 个交易日 × 11 只基金） |
| V17 | 基金资产/行业/地理配置及前 10 大持仓 |

### 3.5 停止后端服务
```bash
kill $(lsof -ti :8080) && echo "Backend server stopped"
```

---

## 四、启动前端

### 4.1 安装依赖
```bash
#### 方式 4.1.1: 单行命令
cd frontend && npm install && npm run dev;

#### 或者
#### 方式 4.1.2: 分步骤命令
cd frontend
npm install
```

### 4.2 启动开发服务器
```bash
npm run dev
```

Vite 启动后，会在终端显示访问地址：
```
VITE v8.0.3  ready in XXX ms
➜  Local:   http://localhost:5173/
➜  Network: http://192.168.x.x:5173/
```

### 4.3 停止前端
```bash
lsof -ti:5173 | xargs kill
```

---

## 五、验证种子数据

### 5.1 通过浏览器验证

1. 打开浏览器访问：http://localhost:5173
2. 使用以下演示账号登录：
   - **邮箱：** demo@smartinvest.com
   - **密码：** Demo1234!

登录后应能看到：
- **首页** — 基金分类卡片
- **我的持仓** — 三只基金持仓，总市值约 HKD 96,523.25
- **基金列表** — 11 只基金，带当前 NAV
- **我的投资计划** — 一个活跃的月度定投计划

### 5.2 通过 API 验证（可选）

后端启动后，在新终端窗口执行：

```bash
# 验证基金列表（含 NAV）
curl http://localhost:8080/api/funds

# 验证演示用户持仓汇总
# 需要先登录获取 JWT token（见下方）
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

## 六、补充脚本说明

项目根目录下的 `scripts/` 文件夹包含额外的实用脚本：

### 创建演示用户（通常不需要手动运行）
```bash
./scripts/create-demo-user.sh
```
> 此脚本用于重新创建演示用户账户。如果 V14 迁移已成功执行，数据已存在，此脚本无需运行。

### 补充 NAV 历史数据（可选）
```bash
./scripts/seed-nav-history.py
```
> 此脚本可补充更长时间跨度（5 年）的 NAV 历史数据，供图表展示更长周期的历史收益。当前 V16 已包含 2025-01-02 至 2026-04-07 的数据（约 329 个交易日），对于大部分场景已足够。

---

## 七、常见问题

### Q1：启动后端时报 `JWT_SECRET` 错误
```
Could not resolve placeholder 'JWT_SECRET' in value "${JWT_SECRET}"
```
**解决方法：** 确保在启动命令中设置了环境变量：
```bash
JWT_SECRET=SmartInvestSecretKey2024ForJWTTokenSigning mvn spring-boot:run -pl app
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
3. 如果需要重置，可以删除数据库并重新启动：
   ```bash
   docker compose down -v   # -v 会删除所有数据卷
   docker compose up -d postgres
   # 重新启动后端，Flyway 会从头执行所有迁移
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
# 8080 端口（后端）
kill $(lsof -ti :8080)

# 5173 端口（前端）
kill $(lsof -ti :5173)

# 5432 端口（数据库）
docker compose stop postgres
```

---

## 八、快速启动完整命令汇总

复制以下命令，按顺序执行即可完成全部搭建：

```bash
# 1. 启动数据库
cd /path/to/smart-invest
docker compose up -d postgres

# 2. 等待 5 秒
sleep 5

# 3. 构建后端（首次需要）
cd backend
mvn install -DskipTests

# 4. 启动后端
SPRING_PROFILES_ACTIVE=local JWT_SECRET=SmartInvestSecretKey2024ForJWTTokenSigning mvn spring-boot:run -pl app &
BACKEND_PID=$!

# 5. 等待后端启动（约 30 秒）
sleep 30

# 6. 启动前端（新终端窗口）
cd frontend && npm install && npm run dev

# 7. 访问 http://localhost:5173
# 登录账号：demo@smartinvest.com / Demo1234!

# —— 停止服务 ——
# 后端：kill $BACKEND_PID
# 前端：lsof -ti:5173 | xargs kill
# 数据库：docker compose down
```

---

## 九、项目结构速览

```
smart-invest/
├── backend/                  # Spring Boot 后端（多模块 Maven 项目）
│   ├── app/                 # 主应用模块
│   │   └── src/main/resources/
│   │       ├── application-local.yml   # 本地配置
│   │       └── db/migration/           # Flyway 迁移文件（V1~V17）
│   ├── module-user/         # 用户认证模块
│   ├── module-fund/         # 基金数据模块
│   ├── module-order/        # 订单模块
│   ├── module-portfolio/    # 持仓模块
│   ├── module-plan/         # 投资计划模块
│   ├── module-scheduler/    # 定时任务模块
│   └── module-notification/ # 通知模块
├── frontend/                # React 前端
│   └── src/
│       ├── pages/           # 页面组件
│       ├── components/     # 公共组件
│       ├── api/             # API 客户端
│       └── types/           # TypeScript 类型定义
├── docs/                    # 文档目录
│   └── local_development_environment_setup-zh.md  # 本文档
├── scripts/                 # 实用脚本
└── docker-compose.yml       # Docker 数据库配置
```
