package com.smartinvest.order.service;

import com.smartinvest.order.domain.Order;
import com.smartinvest.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderSettlementService {

    private final OrderRepository orderRepository;
    private final OrderSettlementExecutor executor;

    /**
     * 批量结算到期的 PENDING 订单（settlement_date <= asOf）。
     * 每笔订单独立处理，单笔失败不影响其他订单继续结算。
     */
    public int settleDueOrders(LocalDate asOf) {
        List<Order> due = orderRepository.findByStatusAndSettlementDateLessThanEqual("PENDING", asOf);
        log.info("Settlement run for {}: {} orders due", asOf, due.size());
        int settled = 0;
        for (Order order : due) {
            try {
                executor.settle(order);
                settled++;
            } catch (Exception e) {
                log.error("Settlement failed for order {}: {}", order.getId(), e.getMessage());
            }
        }
        log.info("Settlement complete: {}/{} orders settled", settled, due.size());
        return settled;
    }
}
