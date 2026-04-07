package com.smartinvest.portfolio.controller;

import com.smartinvest.portfolio.dto.HoldingResponse;
import com.smartinvest.portfolio.service.PortfolioService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.*;

@RestController
@RequestMapping("/api/portfolio")
@RequiredArgsConstructor
public class PortfolioController {
    private final PortfolioService portfolioService;

    @GetMapping("/me/holdings")
    public ResponseEntity<List<HoldingResponse>> holdings(@AuthenticationPrincipal UserDetails principal) {
        return ResponseEntity.ok(portfolioService.getHoldingsWithMarketValue(UUID.fromString(principal.getUsername())));
    }

    @GetMapping("/me/summary")
    public ResponseEntity<Map<String, BigDecimal>> summary(@AuthenticationPrincipal UserDetails principal) {
        BigDecimal total = portfolioService.getTotalMarketValue(UUID.fromString(principal.getUsername()));
        return ResponseEntity.ok(Map.of("totalMarketValue", total));
    }
}
