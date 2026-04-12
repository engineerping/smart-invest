package com.smartinvest.scheduler;

import com.smartinvest.order.service.OrderSettlementService;
import com.smartinvest.plan.service.InvestmentPlanService;
import lombok.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.*;

@Component
@Slf4j
@RequiredArgsConstructor
public class MonthlyInvestmentScheduler {

    private final InvestmentPlanService planService;
    private final OrderSettlementService settlementService;

    /** Execute monthly plans — runs daily at 01:00 HKT on weekdays. */
    @Scheduled(cron = "0 0 1 * * *", zone = "Asia/Hong_Kong")
    public void executeMonthlyPlans() {
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Hong_Kong"));
        if (today.getDayOfWeek() == DayOfWeek.SATURDAY ||
            today.getDayOfWeek() == DayOfWeek.SUNDAY) {
            return;
        }
        var duePlans = planService.findPlansDueOn(today);
        log.info("Monthly plan execution: {} plans due on {}", duePlans.size(), today);
        // TODO: Execute each plan by calling OrderService.placeOrder()
    }

    /** Settle due orders — runs weekdays at 17:30 HKT after market close. */
    @Scheduled(cron = "0 30 17 * * MON-FRI", zone = "Asia/Hong_Kong")
    public void settleOrders() {
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Hong_Kong"));
        settlementService.settleDueOrders(today);
    }

    /** Simulate NAV updates — runs weekdays at 15:00 HKT. */
    @Scheduled(cron = "0 0 15 * * MON-FRI", zone = "Asia/Hong_Kong")
    public void simulateNavUpdate() {
        log.info("NAV simulation triggered");
        // TODO: Update fund NAV values with small random deltas
    }
}
