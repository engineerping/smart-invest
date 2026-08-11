package com.smartinvest.plan.controller;

import com.smartinvest.plan.domain.InvestmentPlan;
import com.smartinvest.plan.dto.CreatePlanRequest;
import com.smartinvest.plan.service.InvestmentPlanService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/plans")
@RequiredArgsConstructor
public class InvestmentPlanController {
    private final InvestmentPlanService planService;

    @PostMapping
    public ResponseEntity<InvestmentPlan> createPlan(
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody CreatePlanRequest req) {
        UUID userId = UUID.fromString(principal.getUsername());
        InvestmentPlan plan = planService.createPlan(userId, req);
        return ResponseEntity.status(HttpStatus.CREATED).body(plan);
    }

    @GetMapping
    public ResponseEntity<List<InvestmentPlan>> listPlans(@AuthenticationPrincipal UserDetails principal) {
        UUID userId = UUID.fromString(principal.getUsername());
        return ResponseEntity.ok(planService.getActivePlans(userId));
    }

    @GetMapping("/{id}")
    public ResponseEntity<InvestmentPlan> getPlan(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(principal.getUsername());
        return ResponseEntity.ok(planService.getPlan(id, userId));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> terminatePlan(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable UUID id) {
        UUID userId = UUID.fromString(principal.getUsername());
        planService.terminatePlan(id, userId);
        return ResponseEntity.noContent().build();
    }
}
