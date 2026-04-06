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
        return orderRepository.save(order);
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