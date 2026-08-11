package com.smartinvest.user.repository;

import com.smartinvest.user.domain.RiskAssessment;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface RiskAssessmentRepository extends JpaRepository<RiskAssessment, UUID> {
    Optional<RiskAssessment> findTopByUserIdOrderByAssessedAtDesc(UUID userId);
}