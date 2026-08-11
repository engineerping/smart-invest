package com.smartinvest.common.event;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 订单事件消息 —— 通过 RabbitMQ 在不同服务间传递
 * =============================================================================
 * 下单成功后 order-service 发出这个消息，两个服务消费：
 *   - fund-service（监听 order.settlement）：更新用户持仓（份数、成本）
 *   - notification-worker（监听 order.notification）：写一条通知记录
 *
 * 类比：这是一张"订单已成交"的纸条，塞进 RabbitMQ 的邮筒，
 *       两个邮递员（监听器）各取一份做自己的事。这就是"异步解耦"——
 *       下单服务不关心谁在处理，处理方也不必认识下单服务。
 * =============================================================================
 */
public record OrderEvent(
        UUID orderId,
        String referenceNumber,
        UUID userId,
        UUID fundId,
        BigDecimal amount,
        BigDecimal executedUnits,
        BigDecimal navAtOrder,
        String status,
        OffsetDateTime occurredAt
) {
    public static OrderEvent settled(UUID orderId, String referenceNumber, UUID userId,
                                     UUID fundId, BigDecimal amount, BigDecimal executedUnits,
                                     BigDecimal navAtOrder) {
        return new OrderEvent(orderId, referenceNumber, userId, fundId, amount,
                executedUnits, navAtOrder, "COMPLETED", OffsetDateTime.now());
    }
}
