# Smart Invest K3S 多微服务实施计划

> 日期：2026-08-03
> 执行方式：inline execution（用户已睡觉授权自主决策）
> 服务拆分映射见下，命名规范全局统一

## 全局约束
- 服务名/K8S：`user-service` `fund-service` `order-service` `notification-worker` `api-gateway` `frontend`
- 容器端口：gateway 8080 / user 8081 / fund 8082 / order 8083 / notification 8084 / frontend 80
- 包名统一 `com.smartinvest`，Docker Hub 账号 `gongchengship`
- Java 21 + Spring Boot 3.3.2，共享 PostgreSQL `smartinvest`，RabbitMQ 进 K3S
- 命名空间 `smart-invest`，数据库迁移只由 user-service 的 Flyway 执行（V1–V20 + V21 notifications）
- 服务间 JWT 无状态认证：sub=userId，各服务用 common 的 JwtFilter 校验

## 服务边界与跨服务接口契约

| 服务 | 模块来源 | 表 | 新增/改造点 |
|---|---|---|---|
| common | 抽自 module-user.security | — | JwtTokenProvider/JwtFilter(principal=userId)、GlobalExceptionHandler、BaseConfig |
| user-service | module-user | users, risk_assessments | AuthService 签 sub=userId；RiskService/UserService 用 userId |
| fund-service | fund+holding+plan+portfolio | funds*, holdings, portfolios, plans | `GET /internal/funds/{id}/latest-nav`；`@RabbitListener(order.settlement)` 更新持仓 |
| order-service | order+scheduler | orders | 下单 REST 调 latest-nav 存快照；`POST /internal/orders`；发 MQ `order.completed`；结算用快照 |
| notification-worker | notification 改造 | notifications(V21) | `@RabbitListener(order.notification)` 写表；`GET /api/notifications` |
| api-gateway | 新建 | — | Spring Cloud Gateway 路由 + CORS，透传 JWT |
| frontend | 现有 React | — | client.ts 默认同源 `''`，加 Dockerfile(nginx) |

## 接口契约（服务间）
- `GET http://fund-service:8082/internal/funds/{id}/latest-nav` → `{nav: BigDecimal}`
- `POST http://order-service:8083/internal/orders` → body: PlaceOrderRequest，返回 OrderResponse
- MQ `smart-invest.exchange`(direct)，routing key：`order.settlement`→queue `order.settlement`（fund 消费）、`order.notification`→queue `order.notification`（worker 消费）；消息体：`{orderId,referenceNumber,userId,fundId,amount,executedUnits,navAtOrder,status}`
- JWT claims：sub=userId；各服务 principal=userId 字符串

## 任务清单
1. **Task A 后端重构**：建 common + 4 服务 + gateway，迁移代码，每个独立可启动
2. **Task B 本地验证**：docker compose 起 postgres+rabbitmq，跑通 注册→登录→基金→下单→通知
3. **Task C 镜像**：6 个 Dockerfile，本地构建，推 Docker Hub
4. **Task D Helm+Kustomize**：6 chart + umbrella + overlays
5. **Task E Terraform-k3s 学习版**
6. **Task F 监控+CI/CD+scripts**：prometheus/grafana、GitHub Actions、部署脚本
7. **Task G 部署到 K3S**：服务器恢复可达后执行，验证全流程

## 验收标准
- `mvn -pl user-service,fund-service,order-service,notification-worker,api-gateway package` 全部 BUILD SUCCESS
- 本地 docker compose 全流程 API 闭环通过（含 MQ 通知）
- 6 镜像推送到 Docker Hub 可被 K3S 拉取
- `helm install smart-invest ./umbrella` 后全部 pod Running
- 通过 Traefik Ingress 访问前端 + API 正常
