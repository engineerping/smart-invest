package com.smartinvest.user.controller;

import com.smartinvest.user.service.RiskService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/risk")
@RequiredArgsConstructor
public class RiskController {
    private final RiskService riskService;

    @GetMapping("/questionnaire")
    public ResponseEntity<Map<String, Object>> getQuestionnaire() {
        return ResponseEntity.ok(riskService.getQuestionnaire());
    }

    @PostMapping("/submit")
    public ResponseEntity<Map<String, Object>> submit(
            @AuthenticationPrincipal UserDetails principal,
            @RequestBody Map<String, String> answers) {
        return ResponseEntity.ok(riskService.submitRiskAssessment(principal.getUsername(), answers));
    }
}