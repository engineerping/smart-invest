package com.smartinvest.user.service;

import com.smartinvest.user.domain.RiskAssessment;
import com.smartinvest.user.repository.RiskAssessmentRepository;
import com.smartinvest.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.*;

@Service @RequiredArgsConstructor
public class RiskService {
    private final RiskAssessmentRepository riskAssessmentRepository;
    private final UserRepository userRepository;

    /** Convert total score (0–30) to risk level (1–5). */
    public int scoreToLevel(int totalScore) {
        if (totalScore <= 9)  return 1;   // Conservative
        if (totalScore <= 15) return 2;   // Moderate
        if (totalScore <= 20) return 3;   // Balanced
        if (totalScore <= 25) return 4;   // Adventurous
        return 5;                           // Speculative
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> getQuestionnaire() {
        return Map.of("questions", List.of(
            Map.of("id", 1, "text", "What is your primary investment goal?",
                "options", List.of(
                    Map.of("id", "A", "text", "Preserve capital", "score", 1),
                    Map.of("id", "B", "text", "Generate steady income", "score", 2),
                    Map.of("id", "C", "text", "Balanced growth and income", "score", 3),
                    Map.of("id", "D", "text", "Long-term growth", "score", 4),
                    Map.of("id", "E", "text", "Maximum growth / speculative", "score", 5))),
            Map.of("id", 2, "text", "How long is your investment horizon?",
                "options", List.of(
                    Map.of("id", "A", "text", "Less than 1 year", "score", 1),
                    Map.of("id", "B", "text", "1–3 years", "score", 2),
                    Map.of("id", "C", "text", "3–5 years", "score", 3),
                    Map.of("id", "D", "text", "5–10 years", "score", 4),
                    Map.of("id", "E", "text", "More than 10 years", "score", 5))),
            Map.of("id", 3, "text", "How would you react to a 20% portfolio decline?",
                "options", List.of(
                    Map.of("id", "A", "text", "Sell immediately", "score", 1),
                    Map.of("id", "B", "text", "Sell some and wait", "score", 2),
                    Map.of("id", "C", "text", "Hold and wait", "score", 3),
                    Map.of("id", "D", "text", "Buy a little more", "score", 4),
                    Map.of("id", "E", "text", "Buy significantly more", "score", 5))),
            Map.of("id", 4, "text", "What percentage of your savings is this investment?",
                "options", List.of(
                    Map.of("id", "A", "text", "More than 75%", "score", 1),
                    Map.of("id", "B", "text", "50–75%", "score", 2),
                    Map.of("id", "C", "text", "25–50%", "score", 3),
                    Map.of("id", "D", "text", "10–25%", "score", 4),
                    Map.of("id", "E", "text", "Less than 10%", "score", 5))),
            Map.of("id", 5, "text", "What is your investment experience?",
                "options", List.of(
                    Map.of("id", "A", "text", "None", "score", 1),
                    Map.of("id", "B", "text", "Limited (savings/deposits)", "score", 2),
                    Map.of("id", "C", "text", "Moderate (bonds/funds)", "score", 3),
                    Map.of("id", "D", "text", "Good (equities)", "score", 4),
                    Map.of("id", "E", "text", "Extensive (derivatives/margin)", "score", 5))),
            Map.of("id", 6, "text", "What is your annual income?",
                "options", List.of(
                    Map.of("id", "A", "text", "Below HKD 150,000", "score", 1),
                    Map.of("id", "B", "text", "HKD 150,000–300,000", "score", 2),
                    Map.of("id", "C", "text", "HKD 300,000–600,000", "score", 3),
                    Map.of("id", "D", "text", "HKD 600,000–1,200,000", "score", 4),
                    Map.of("id", "E", "text", "Above HKD 1,200,000", "score", 5)))));
    }

    public Map<String, Object> submitRiskAssessment(String email, Map<String, String> answers) {
        int totalScore = answers.values().stream()
            .mapToInt(v -> Integer.parseInt(v))
            .sum();
        int riskLevel = scoreToLevel(totalScore);

        // Update user's risk level
        userRepository.findByEmail(email).ifPresent(user -> {
            user.setRiskLevel((short) riskLevel);
            userRepository.save(user);
        });

        return Map.of("totalScore", totalScore, "riskLevel", riskLevel);
    }
}