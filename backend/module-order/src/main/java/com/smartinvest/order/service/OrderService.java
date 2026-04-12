package com.smartinvest.order.service;

import com.smartinvest.order.domain.Order;
import com.smartinvest.order.dto.PlaceOrderRequest;
import com.smartinvest.order.dto.OrderResponse;
import com.smartinvest.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;

import java.util.*;

@Service @RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final OrderReferenceGenerator referenceGenerator;
    private final SettlementDateCalculator settlementDateCalculator;
    private final OrderSettlementExecutor settlementExecutor;

    public Order placeOrder(UUID userId, PlaceOrderRequest req) {
        Order order = new Order();
        order.setUserId(userId);
        order.setFundId(req.fundId());
        order.setOrderType(req.orderType());
        order.setInvestmentType("BUY");
        order.setAmount(req.amount());
        order.setInvestmentAccount(req.investmentAccount());
        order.setSettlementAccount(req.settlementAccount());
        order.setReferenceNumber(referenceGenerator.generate(req.orderType()));
        order.setSettlementDate(settlementDateCalculator.calculate(order.getOrderDate(), 2));
        Order saved = orderRepository.save(order);
        // [DEMO] 下单后立即结算，让 My Holdings 页面的 Total Market Value 实时反映持仓变化。
        // 生产环境应移除此调用，改由定时任务在 settlement_date 到期后统一结算 Start。
        settlementExecutor.settle(saved);
        // 生产环境应移除此调用，改由定时任务在 settlement_date 到期后统一结算 End。

        return saved;
    }

    public Page<OrderResponse> getOrders(UUID userId, int page, int size) {
        return orderRepository.findByUserIdOrderByOrderDateDesc(userId, PageRequest.of(page, size))
            .map(this::toResponse);
    }

    public void cancelOrder(UUID orderId, UUID userId) {
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new NoSuchElementException("Order not found: " + orderId));
        if (!order.getUserId().equals(userId)) {
            throw new SecurityException("Access denied");
        }
        if (!"PENDING".equals(order.getStatus())) {
            throw new IllegalStateException("Only PENDING orders can be cancelled");
        }
        order.setStatus("CANCELLED");
        orderRepository.save(order);
    }

    private OrderResponse toResponse(Order order) {
        return new OrderResponse(
            order.getId(), order.getReferenceNumber(), order.getFundId(),
            order.getOrderType(), order.getInvestmentType(), order.getAmount(),
            order.getStatus(), order.getOrderDate(), order.getSettlementDate(),
            order.getCreatedAt()
        );
    }
}