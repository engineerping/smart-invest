package com.smartinvest.notification;

import com.smartinvest.common.security.CommonSecurityConfig;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Import;

/**
 * notification-worker 启动类
 * =============================================================================
 * 这是一个"事件驱动"的微服务：主要工作不是接收 HTTP 请求，
 * 而是监听 RabbitMQ 的 order.notification 队列，消费订单事件写通知。
 * 同时提供 /api/notifications 供前端查询通知列表。
 * =============================================================================
 */
@SpringBootApplication(scanBasePackages = "com.smartinvest")
@Import(CommonSecurityConfig.class)
public class NotificationWorkerApplication {
    public static void main(String[] args) {
        SpringApplication.run(NotificationWorkerApplication.class, args);
    }
}
