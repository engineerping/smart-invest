package com.smartinvest.fund;

import com.smartinvest.common.security.CommonSecurityConfig;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

/**
 * fund-service 启动类
 * =============================================================================
 * fund-service 由 fund + holding + plan + portfolio 四个领域合并而来，
 * 包结构跨了多个顶层包（com.smartinvest.fund / .holding / .plan / .portfolio）。
 * Spring Boot 默认从主类所在包（com.smartinvest.fund）往下扫描，
 * 扫不到 com.smartinvest.plan.repository 等。
 * 所以这里用 @EntityScan 和 @EnableJpaRepositories 显式扩大扫描范围到 com.smartinvest。
 * =============================================================================
 */
@SpringBootApplication(scanBasePackages = "com.smartinvest")
@EntityScan("com.smartinvest")
@EnableJpaRepositories(basePackages = "com.smartinvest")
@Import(CommonSecurityConfig.class)
public class FundServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(FundServiceApplication.class, args);
    }
}
