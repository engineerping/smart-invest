package com.smartinvest.plan.service;

import com.smartinvest.plan.domain.InvestmentPlan;
import com.smartinvest.plan.dto.CreatePlanRequest;
import com.smartinvest.plan.repository.InvestmentPlanRepository;
import com.smartinvest.fund.repository.FundRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.time.*;
import java.util.*;

@Service @RequiredArgsConstructor
public class InvestmentPlanService {
    private final InvestmentPlanRepository planRepository;
    private final FundRepository fundRepository;

    private String generateRef() {
        return "PLAN-" + System.currentTimeMillis();
    }

    public InvestmentPlan createPlan(UUID userId, CreatePlanRequest req) {
        InvestmentPlan plan = new InvestmentPlan();
        plan.setUserId(userId);
        plan.setFundId(req.fundId());
        plan.setMonthlyAmount(req.monthlyAmount());
        plan.setNextContributionDate(req.startDate() != null ? req.startDate() : LocalDate.now().plusMonths(1));
        plan.setInvestmentAccount(req.investmentAccount());
        plan.setSettlementAccount(req.settlementAccount());
        plan.setPortfolioId(req.portfolioId());
        plan.setReferenceNumber(generateRef());
        return planRepository.save(plan);
    }

    public List<InvestmentPlan> getActivePlans(UUID userId) {
        List<InvestmentPlan> plans = planRepository.findByUserIdAndStatus(userId, "ACTIVE");
        for (InvestmentPlan plan : plans) {
            fundRepository.findById(plan.getFundId())
                .ifPresent(f -> plan.setFundName(f.getName()));
        }
        return plans;
    }

    public InvestmentPlan getPlan(UUID planId, UUID userId) {
        InvestmentPlan plan = planRepository.findById(planId)
            .filter(p -> p.getUserId().equals(userId))
            .orElseThrow(() -> new NoSuchElementException("Plan not found"));
        fundRepository.findById(plan.getFundId())
            .ifPresent(f -> plan.setFundName(f.getName()));
        return plan;
    }

    public void terminatePlan(UUID planId, UUID userId) {
        InvestmentPlan plan = getPlan(planId, userId);
        plan.setStatus("TERMINATED");
        plan.setTerminatedAt(OffsetDateTime.now());
        planRepository.save(plan);
    }

    public List<InvestmentPlan> findPlansDueOn(LocalDate date) {
        return planRepository.findByNextContributionDateAndStatus(date, "ACTIVE");
    }
}
