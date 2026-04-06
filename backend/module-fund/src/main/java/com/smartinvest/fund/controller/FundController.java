package com.smartinvest.fund.controller;

import com.smartinvest.fund.domain.*;
import com.smartinvest.fund.service.FundService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/funds")
@RequiredArgsConstructor
public class FundController {
    private final FundService fundService;

    @GetMapping
    public ResponseEntity<List<Fund>> listFunds(
            @RequestParam(required = false) String type,
            @RequestParam(required = false) Short riskLevel) {
        return ResponseEntity.ok(fundService.getAllFunds(type, riskLevel));
    }

    @GetMapping("/multi-asset")
    public ResponseEntity<List<Fund>> multiAsset() {
        return ResponseEntity.ok(fundService.getMultiAssetFunds());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Fund> getFund(@PathVariable UUID id) {
        return ResponseEntity.ok(fundService.getFundById(id));
    }

    @GetMapping("/{id}/nav-history")
    public ResponseEntity<List<FundNavHistory>> navHistory(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "3M") String period) {
        return ResponseEntity.ok(fundService.getNavHistory(id, period));
    }

    @GetMapping("/{id}/asset-allocation")
    public ResponseEntity<List<FundAssetAllocation>> assetAllocation(@PathVariable UUID id) {
        return ResponseEntity.ok(fundService.getAssetAllocation(id));
    }
}