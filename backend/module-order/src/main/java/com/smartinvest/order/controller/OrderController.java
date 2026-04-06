package com.smartinvest.order.controller;

import com.smartinvest.order.domain.Order;
import com.smartinvest.order.dto.PlaceOrderRequest;
import com.smartinvest.order.dto.OrderResponse;
import com.smartinvest.order.service.OrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    @PostMapping
    public ResponseEntity<OrderResponse> placeOrder(
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody PlaceOrderRequest req) {
        UUID userId = UUID.fromString(principal.getUsername());
        Order order = orderService.placeOrder(userId, req);
        return ResponseEntity.status(HttpStatus.CREATED).body(toResponse(order));
    }

    @GetMapping
    public ResponseEntity<Page<OrderResponse>> listOrders(
            @AuthenticationPrincipal UserDetails principal,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        UUID userId = UUID.fromString(principal.getUsername());
        return ResponseEntity.ok(orderService.getOrders(userId, page, size));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> cancelOrder(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(principal.getUsername());
        orderService.cancelOrder(id, userId);
        return ResponseEntity.noContent().build();
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