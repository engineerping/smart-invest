package com.smartinvest.order;

import com.smartinvest.common.security.CommonSecurityConfig;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Import;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * order-service 启动类
 * @EnableScheduling 启用 @Scheduled 定时任务（结算、NAV 模拟等）。
 */
@SpringBootApplication(scanBasePackages = "com.smartinvest")
@Import(CommonSecurityConfig.class)
@EnableScheduling
public class OrderServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(OrderServiceApplication.class, args);
    }
}
