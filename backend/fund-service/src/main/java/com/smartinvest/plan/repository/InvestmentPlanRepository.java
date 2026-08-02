package com.smartinvest.plan.repository;

import com.smartinvest.plan.domain.InvestmentPlan;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.*;

public interface InvestmentPlanRepository extends JpaRepository<InvestmentPlan, UUID> {
    List<InvestmentPlan> findByUserIdAndStatus(UUID userId, String status);
    List<InvestmentPlan> findByNextContributionDateAndStatus(LocalDate date, String status);
}
