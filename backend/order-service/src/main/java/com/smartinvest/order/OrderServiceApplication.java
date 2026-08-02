package com.smartinvest.order;

import com.smartinvest.common.security.CommonSecurityConfig;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * order-service 启动类
 * 显式扩大 JPA 扫描范围到 com.smartinvest（含 common 里的实体/仓库）。
 * @EnableScheduling 启用 @Scheduled 定时任务。
 */
@SpringBootApplication(scanBasePackages = "com.smartinvest")
@EntityScan("com.smartinvest")
@EnableJpaRepositories(basePackages = "com.smartinvest")
@Import(CommonSecurityConfig.class)
@EnableScheduling
public class OrderServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(OrderServiceApplication.class, args);
    }
}
