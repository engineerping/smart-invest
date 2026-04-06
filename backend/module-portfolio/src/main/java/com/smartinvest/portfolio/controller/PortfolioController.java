package com.smartinvest.portfolio.controller;

import com.smartinvest.portfolio.domain.Holding;
import com.smartinvest.portfolio.service.PortfolioService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/portfolio")
@RequiredArgsConstructor
public class PortfolioController {
    private final PortfolioService portfolioService;

    @GetMapping("/me/holdings")
    public ResponseEntity<List<Holding>> holdings(@AuthenticationPrincipal UserDetails principal) {
        return ResponseEntity.ok(portfolioService.getHoldings(UUID.fromString(principal.getUsername())));
    }
}
