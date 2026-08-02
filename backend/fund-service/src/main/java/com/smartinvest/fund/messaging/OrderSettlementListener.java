package com.smartinvest.fund.messaging;

import com.smartinvest.common.event.OrderEvent;
import com.smartinvest.common.event.RabbitMQConfig;
import com.smartinvest.holding.service.HoldingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

/**
 * 订单结算事件监听器 —— fund-service
 * =============================================================================
 * 监听 RabbitMQ 的 order.settlement 队列。
 * 当 order-service 下单并结算成功后，会发布 OrderEvent 到这里，
 * 本监听器调用 HoldingService 累加用户持仓（份数、金额、平均成本）。
 *
 * 这就是"事件驱动解耦"的体现：
 *   order-service 只负责"算清成交"，不关心谁更新持仓；
 *   fund-service 只负责"更新持仓"，不关心订单是怎么结算的。
 *   两个服务通过消息队列协作，任何一方宕机都不影响另一方主流程
 *   （消息会滞留在队列里，等服务恢复后继续消费）。
 * =============================================================================
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class OrderSettlementListener {

    private final HoldingService holdingService;

    @RabbitListener(queues = RabbitMQConfig.SETTLEMENT_QUEUE)
    public void onOrderSettled(OrderEvent event) {
        log.info("Settlement event received: order={} fund={} units={}",
                event.referenceNumber(), event.fundId(), event.executedUnits());
        // 累加持仓：把成交份数和金额并到用户持仓上
        holdingService.applySettlement(event.userId(), event.fundId(),
                event.executedUnits(), event.amount());
    }
}
