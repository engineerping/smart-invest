package com.smartinvest.order.service;

import com.smartinvest.common.event.OrderEvent;
import com.smartinvest.common.event.RabbitMQConfig;
import com.smartinvest.order.client.FundServiceClient;
import com.smartinvest.order.domain.Order;
import com.smartinvest.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;

/**
 * 订单结算执行器
 * =============================================================================
 * 结算单笔订单，并把"订单已成交"这个事实通过 RabbitMQ 广播出去。
 *
 * 原来：结算时直接修改持仓表（模块化单体里 fund/holding 在同一个 jar）。
 * 现在：order-service 和 fund-service 已拆分，持仓表归 fund-service 管，
 *       所以这里改为【发消息】，由 fund-service 的监听器负责更新持仓。
 *       —— 这就是从"同步耦合"到"事件驱动解耦"的关键改造点。
 * =============================================================================
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OrderSettlementExecutor {

    private final OrderRepository orderRepository;
    private final FundServiceClient fundServiceClient;
    private final RabbitTemplate rabbitTemplate;

    @Transactional
    public void settle(Order order) {
        // 从 fund-service 拿最新净值作为成交净值（服务间同步 REST 调用）
        BigDecimal nav = fundServiceClient.getLatestNav(order.getFundId());
        if (nav == null) {
            throw new IllegalStateException("No NAV available for fund " + order.getFundId());
        }

        // 成交份数 = 投资金额 ÷ 净值，保留 6 位小数
        BigDecimal executedUnits = order.getAmount().divide(nav, 6, RoundingMode.HALF_UP);

        // 更新订单状态为 COMPLETED
        order.setExecutedUnits(executedUnits);
        order.setNavAtOrder(nav);
        order.setStatus("COMPLETED");
        order.setCompletedAt(OffsetDateTime.now());
        orderRepository.save(order);

        // 发布订单事件到 RabbitMQ（两个队列都会收到：settlement 更新持仓、notification 写通知）
        OrderEvent event = OrderEvent.settled(
                order.getId(), order.getReferenceNumber(), order.getUserId(),
                order.getFundId(), order.getAmount(), executedUnits, nav);
        rabbitTemplate.convertAndSend(RabbitMQConfig.EXCHANGE,
                RabbitMQConfig.SETTLEMENT_ROUTING_KEY, event);
        rabbitTemplate.convertAndSend(RabbitMQConfig.EXCHANGE,
                RabbitMQConfig.NOTIFICATION_ROUTING_KEY, event);
        log.info("Order {} settled: units={}, nav={}, events published",
                order.getReferenceNumber(), executedUnits, nav);
    }
}
