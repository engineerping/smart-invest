package com.smartinvest.portfolio.service;

import com.smartinvest.fund.repository.FundRepository;
import com.smartinvest.order.dto.PlaceOrderRequest;
import com.smartinvest.order.service.OrderService;
import com.smartinvest.plan.dto.CreatePlanRequest;
import com.smartinvest.plan.service.InvestmentPlanService;
import com.smartinvest.portfolio.domain.UserPortfolio;
import com.smartinvest.portfolio.domain.UserPortfolioAllocation;
import com.smartinvest.portfolio.dto.*;
import com.smartinvest.portfolio.repository.UserPortfolioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PortfolioService {

    private final UserPortfolioRepository portfolioRepository;
    private final FundRepository fundRepository;
    private final OrderService orderService;
    private final InvestmentPlanService planService;

    /**
     * 创建自建组合模板（不立即投资，只保存配置）。
     * 校验：所有基金存在、allocation_pct 合计等于 100。
     */
    @Transactional
    public UserPortfolioResponse createPortfolio(UUID userId, CreatePortfolioRequest req) {
        BigDecimal totalPct = req.allocations().stream()
            .map(FundAllocationItem::allocationPct)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        if (totalPct.compareTo(new BigDecimal("100.00")) != 0) {
            throw new IllegalArgumentException(
                "Allocation percentages must sum to 100, got: " + totalPct);
        }

        UserPortfolio portfolio = new UserPortfolio();
        portfolio.setUserId(userId);
        portfolio.setName(req.name());

        for (FundAllocationItem item : req.allocations()) {
            fundRepository.findById(item.fundId())
                .orElseThrow(() -> new NoSuchElementException("Fund not found: " + item.fundId()));

            UserPortfolioAllocation alloc = new UserPortfolioAllocation();
            alloc.setPortfolio(portfolio);
            alloc.setFundId(item.fundId());
            alloc.setAllocationPct(item.allocationPct());
            portfolio.getAllocations().add(alloc);
        }

        return toResponse(portfolioRepository.save(portfolio));
    }

    public List<UserPortfolioResponse> getPortfolios(UUID userId) {
        return portfolioRepository.findByUserIdAndStatus(userId, "ACTIVE")
            .stream().map(this::toResponse).toList();
    }

    public UserPortfolioResponse getPortfolio(UUID portfolioId, UUID userId) {
        return toResponse(loadOwned(portfolioId, userId));
    }

    @Transactional
    public void deletePortfolio(UUID portfolioId, UUID userId) {
        UserPortfolio portfolio = loadOwned(portfolioId, userId);
        portfolio.setStatus("DELETED");
        portfolioRepository.save(portfolio);
    }

    /**
     * 从自建组合投资：按各基金配置比例拆分总金额，创建各自的订单（ONE_TIME）或定投计划（MONTHLY）。
     * 最后一只基金用余额兜底，避免因舍入导致合计不等于 totalAmount。
     */
    @Transactional
    public List<?> invest(UUID portfolioId, UUID userId, InvestFromPortfolioRequest req) {
        UserPortfolio portfolio = loadOwned(portfolioId, userId);
        List<UserPortfolioAllocation> allocations = portfolio.getAllocations();

        boolean isMonthly = "MONTHLY".equalsIgnoreCase(req.investmentType());

        // 计算每只基金的分配金额
        BigDecimal allocated = BigDecimal.ZERO;
        BigDecimal[] amounts = new BigDecimal[allocations.size()];
        for (int i = 0; i < allocations.size() - 1; i++) {
            BigDecimal pct = allocations.get(i).getAllocationPct()
                .divide(new BigDecimal("100"), 10, RoundingMode.HALF_UP);
            amounts[i] = req.totalAmount().multiply(pct).setScale(2, RoundingMode.HALF_UP);
            allocated = allocated.add(amounts[i]);
        }
        // 最后一只基金用余额，消除舍入误差
        amounts[allocations.size() - 1] = req.totalAmount().subtract(allocated);

        if (isMonthly) {
            return allocations.stream().map(alloc -> {
                int idx = allocations.indexOf(alloc);
                CreatePlanRequest planReq = new CreatePlanRequest(
                    alloc.getFundId(),
                    amounts[idx],
                    req.startDate(),
                    req.investmentAccount(),
                    req.settlementAccount(),
                    portfolioId
                );
                return planService.createPlan(userId, planReq);
            }).toList();
        } else {
            return allocations.stream().map(alloc -> {
                int idx = allocations.indexOf(alloc);
                PlaceOrderRequest orderReq = new PlaceOrderRequest(
                    alloc.getFundId(),
                    "ONE_TIME",
                    amounts[idx],
                    req.startDate(),
                    req.investmentAccount(),
                    req.settlementAccount(),
                    portfolioId
                );
                return orderService.placeOrder(userId, orderReq);
            }).toList();
        }
    }

    private UserPortfolio loadOwned(UUID portfolioId, UUID userId) {
        UserPortfolio portfolio = portfolioRepository.findById(portfolioId)
            .orElseThrow(() -> new NoSuchElementException("Portfolio not found: " + portfolioId));
        if (!portfolio.getUserId().equals(userId)) {
            throw new SecurityException("Access denied");
        }
        if ("DELETED".equals(portfolio.getStatus())) {
            throw new NoSuchElementException("Portfolio not found: " + portfolioId);
        }
        return portfolio;
    }

    private UserPortfolioResponse toResponse(UserPortfolio p) {
        List<UserPortfolioResponse.AllocationDetail> details = p.getAllocations().stream()
            .map(a -> {
                String name = fundRepository.findById(a.getFundId())
                    .map(f -> f.getName()).orElse(null);
                String code = fundRepository.findById(a.getFundId())
                    .map(f -> f.getCode()).orElse(null);
                return new UserPortfolioResponse.AllocationDetail(
                    a.getFundId(), name, code, a.getAllocationPct());
            }).toList();
        return new UserPortfolioResponse(p.getId(), p.getName(), p.getStatus(), details, p.getCreatedAt());
    }
}
