package com.smartinvest.order.scheduler;

import com.smartinvest.order.service.OrderSettlementService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.ZoneId;

/**
 * 定时结算任务 —— order-service
 * =============================================================================
 * 在 demo 里，下单会立即结算（方便面试实时看到持仓变化），
 * 这个定时任务作为兜底：每天收盘后把所有到期未结算的订单统一结算一遍，
 * 展示"定时任务 + 批量处理"的能力。对应架构图里 scheduler 的位置。
 * =============================================================================
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class OrderSettlementScheduler {

    private final OrderSettlementService settlementService;

    /** 工作日 17:30（香港时间）批量结算到期订单 */
    @Scheduled(cron = "0 30 17 * * MON-FRI", zone = "Asia/Hong_Kong")
    public void settleDueOrders() {
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Hong_Kong"));
        int settled = settlementService.settleDueOrders(today);
        log.info("Scheduled settlement run: {} orders settled", settled);
    }
}
