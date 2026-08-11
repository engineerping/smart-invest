package com.smartinvest.notification;

import com.smartinvest.common.event.RabbitMQConfig;
import com.smartinvest.notification.domain.Notification;
import com.smartinvest.notification.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;

/**
 * 订单事件消费者 —— notification-worker 的核心
 * =============================================================================
 * 监听 order.notification 队列，把"订单已成交"写成一条用户通知。
 *
 * 面试讲点：这就是异步解耦 + 削峰。
 *   - 解耦：order-service 发消息，不关心谁消费；
 *   - 削峰：下单高峰时，消息在队列里排队，worker 慢慢消费，不会压垮数据库。
 *   - 可靠性：RabbitMQ 持久化队列，worker 宕机重启后消息还在（消费确认机制）。
 * =============================================================================
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class OrderNotificationListener {

    private final NotificationRepository notificationRepository;

    @RabbitListener(queues = RabbitMQConfig.NOTIFICATION_QUEUE)
    public void onOrderEvent(com.smartinvest.common.event.OrderEvent event) {
        log.info("Notification event received: order={} fund={} amount={}",
                event.referenceNumber(), event.fundId(), event.amount());

        String title = "订单已成交";
        String body = String.format(
                "您的订单 %s 已按净值 %.4f 成交，金额 %s。",
                event.referenceNumber(),
                event.navAtOrder() != null ? event.navAtOrder() : BigDecimal.ZERO,
                event.amount());

        Notification n = new Notification();
        n.setUserId(event.userId());
        n.setType("ORDER_COMPLETED");
        n.setTitle(title);
        n.setBody(body);
        n.setReferenceNumber(event.referenceNumber());
        notificationRepository.save(n);

        log.info("Notification saved for user {}", event.userId());
    }
}
