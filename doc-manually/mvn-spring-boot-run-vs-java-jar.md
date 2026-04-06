# 开发阶段推荐 `mvn spring-boot:run` 而非 `java -jar`

**开发阶段推荐 `mvn spring-boot:run -pl app -am` 的原因：**

| | `mvn spring-boot:run -pl app -am` | `java -jar` |
|--|---|---|
| **构建** | 自动编译所有 8 个模块（按依赖顺序） | 需要先手动 `mvn package` 生成 fat JAR |
| **代码修改** | 自动重新编译（配合 devtools 热重载） | 改代码后需重新 `package` 再 `java -jar` |
| **调试** | 直接源码运行，堆栈信息清晰 | 打包后运行，调试不便 |
| **依赖管理** | Maven 自动处理模块间依赖 | 需确保 JAR 已正确打包 |

**总结：**

- **开发用 `mvn spring-boot:run`**：改代码后自动重编译，一行命令搞定
- **生产用 `java -jar`**：EC2 上部署时用，已提前 `mvn package` 打好 JAR

`java -jar` 在开发阶段的问题是每次改代码都要手动重新打包，很繁琐。
