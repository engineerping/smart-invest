package com.smartinvest.user;

import com.smartinvest.common.security.CommonSecurityConfig;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Import;

/**
 * user-service 启动类
 * =============================================================================
 * 注意 @Import(CommonSecurityConfig.class)：
 *   安全配置（JWT 过滤器、CORS、放行规则）放在 common 共享库里，
 *   这里显式导入，让本服务启用它。这是"共享库被多个独立 Spring Boot 应用复用"的关键。
 * =============================================================================
 */
@SpringBootApplication(scanBasePackages = "com.smartinvest")
@Import(CommonSecurityConfig.class)
public class UserServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(UserServiceApplication.class, args);
    }
}
