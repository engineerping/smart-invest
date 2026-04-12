package com.smartinvest.order.service;

import com.smartinvest.fund.repository.FundNavHistoryRepository;
import com.smartinvest.order.domain.Order;
import com.smartinvest.order.repository.OrderRepository;
import com.smartinvest.portfolio.service.PortfolioService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;

@Service
@RequiredArgsConstructor
public class OrderSettlementExecutor {

    private final OrderRepository orderRepository;
    private final FundNavHistoryRepository fundNavHistoryRepository;
    private final PortfolioService portfolioService;

    /**
     * 结算单笔订单：计算成交份数，将订单标记为 COMPLETED，并更新用户持仓。
     * 使用 @Transactional 保证订单更新和持仓更新原子性——任何一步失败都会整体回滚。
     */
    @Transactional
    public void settle(Order order) {
        // 取 settlement date 当天或之前最近的 NAV 作为成交净值
        BigDecimal nav = fundNavHistoryRepository
            .findTopByFundIdAndNavDateLessThanEqualOrderByNavDateDesc(order.getFundId(), order.getSettlementDate())
            .orElseThrow(() -> new IllegalStateException("No NAV available for fund " + order.getFundId()))
            .getNav();

        // 成交份数 = 投资金额 ÷ 净值，保留 6 位小数
        BigDecimal executedUnits = order.getAmount().divide(nav, 6, RoundingMode.HALF_UP);

        // 更新订单状态
        order.setExecutedUnits(executedUnits);
        order.setNavAtOrder(nav);
        order.setStatus("COMPLETED");
        order.setCompletedAt(OffsetDateTime.now());
        orderRepository.save(order);

        // 将成交份数和金额累加到用户持仓
        portfolioService.applySettlement(order.getUserId(), order.getFundId(), executedUnits, order.getAmount());
    }
}
