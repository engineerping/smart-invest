# 开发阶段推荐 `mvn spring-boot:run` 而非 `java -jar`

**开发阶段推荐 `mvn spring-boot:run -pl <service>` 的原因：**

| | `mvn spring-boot:run -pl <service>` | `java -jar` |
|--|---|---|
| **构建** | 自动编译该服务及其依赖（6 个模块按依赖顺序） | 需要先手动 `mvn package` 生成 fat JAR |
| **代码修改** | 自动重新编译（配合 devtools 热重载） | 改代码后需重新 `package` 再 `java -jar` |
| **调试** | 直接源码运行，堆栈信息清晰 | 打包后运行，调试不便 |
| **依赖管理** | Maven 自动处理模块间依赖 | 需确保 JAR 已正确打包 |

**总结：**

- **开发用 `mvn spring-boot:run -pl <service>`**：改代码后自动重编译，一行命令搞定（如 `-pl api-gateway`、`-pl user-service`）
- **生产用 Docker 镜像 + K3S/Helm 部署**：在 x86_64 构建机上打 `gongchengship/smart-invest-<service>:1.0.0` 镜像，导入 K3S 后由 Helm 部署（见 `infrastructure/deployment-guide.md`）

`java -jar` 在开发阶段的问题是每次改代码都要手动重新打包，很繁琐。
