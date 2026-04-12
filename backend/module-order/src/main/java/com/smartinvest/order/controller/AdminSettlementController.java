package com.smartinvest.order.controller;

import com.smartinvest.order.service.OrderSettlementService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Map;

// TODO: restrict to ADMIN role once role-based auth is added to the JWT/user model
@RestController
@RequestMapping("/api/admin/settlement")
@RequiredArgsConstructor
public class AdminSettlementController {

    private final OrderSettlementService settlementService;

    @PostMapping("/run")
    public ResponseEntity<Map<String, Object>> runSettlement(
            @RequestParam(required = false) String asOf) {
        LocalDate date = asOf != null ? LocalDate.parse(asOf) : LocalDate.now();
        int settled = settlementService.settleDueOrders(date);
        return ResponseEntity.ok(Map.of("settledCount", settled, "asOf", date.toString()));
    }
}
