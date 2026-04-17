package com.smartinvest.holding.controller;

import com.smartinvest.holding.dto.HoldingResponse;
import com.smartinvest.holding.service.HoldingService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/holdings")
@RequiredArgsConstructor
public class HoldingController {

    private final HoldingService holdingService;

    @GetMapping("/me")
    public List<HoldingResponse> myHoldings(@AuthenticationPrincipal UserDetails user) {
        return holdingService.getHoldingsWithMarketValue(UUID.fromString(user.getUsername()));
    }

    @GetMapping("/me/summary")
    public Map<String, BigDecimal> mySummary(@AuthenticationPrincipal UserDetails user) {
        BigDecimal total = holdingService.getTotalMarketValue(UUID.fromString(user.getUsername()));
        return Map.of("totalMarketValue", total);
    }
}
