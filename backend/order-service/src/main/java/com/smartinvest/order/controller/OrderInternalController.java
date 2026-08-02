package com.smartinvest.order.controller;

import com.smartinvest.common.dto.PlaceOrderRequest;
import com.smartinvest.order.domain.Order;
import com.smartinvest.order.dto.OrderResponse;
import com.smartinvest.order.service.OrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * 内部接口 —— 供 fund-service 同步调用
 * =============================================================================
 * fund-service 的"从组合投资"功能，需要给用户真实创建订单。
 * 这里用 X-User-Id 请求头传递当前用户（内部调用不做 JWT 校验，
 * 因为 K8S 集群内网络相对可信；生产环境应用 mTLS / 服务网格加固）。
 * =============================================================================
 */
@RestController
@RequestMapping("/internal/orders")
@RequiredArgsConstructor
public class OrderInternalController {

    private final OrderService orderService;

    @PostMapping
    public ResponseEntity<OrderResponse> placeOrder(
            @RequestHeader("X-User-Id") UUID userId,
            @Valid @RequestBody PlaceOrderRequest req) {
        Order order = orderService.placeOrder(userId, req);
        return ResponseEntity.status(HttpStatus.CREATED).body(toResponse(order));
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
