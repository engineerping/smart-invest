package com.smartinvest.portfolio.service;

import com.smartinvest.fund.repository.FundNavHistoryRepository;
import com.smartinvest.portfolio.domain.Holding;
import com.smartinvest.portfolio.dto.HoldingResponse;
import com.smartinvest.portfolio.repository.HoldingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.UUID;

@Service @RequiredArgsConstructor
public class PortfolioService {
    private final HoldingRepository holdingRepository;
    private final FundNavHistoryRepository fundNavHistoryRepository;

    public List<HoldingResponse> getHoldingsWithMarketValue(UUID userId) {
        return holdingRepository.findByUserId(userId).stream()
            .map(h -> toResponse(h))
            .toList();
    }

    public BigDecimal getTotalMarketValue(UUID userId) {
        return getHoldingsWithMarketValue(userId).stream()
            .map(HoldingResponse::marketValue)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private HoldingResponse toResponse(Holding h) {
        BigDecimal marketValue = fundNavHistoryRepository
            .findTopByFundIdOrderByNavDateDesc(h.getFundId())
            .map(nav -> h.getTotalUnits().multiply(nav.getNav()).setScale(2, RoundingMode.HALF_UP))
            .orElse(h.getTotalInvested());
        return new HoldingResponse(h.getId(), h.getFundId(), h.getTotalUnits(), h.getTotalInvested(), marketValue);
    }
}
