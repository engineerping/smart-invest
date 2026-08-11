package com.smartinvest.holding.service;

import com.smartinvest.fund.repository.FundNavHistoryRepository;
import com.smartinvest.fund.repository.FundRepository;
import com.smartinvest.holding.domain.Holding;
import com.smartinvest.holding.dto.HoldingResponse;
import com.smartinvest.holding.repository.HoldingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service @RequiredArgsConstructor
public class HoldingService {

    private final HoldingRepository holdingRepository;
    private final FundNavHistoryRepository fundNavHistoryRepository;
    private final FundRepository fundRepository;

    public List<HoldingResponse> getHoldingsWithMarketValue(UUID userId) {
        return holdingRepository.findByUserId(userId).stream()
            .map(this::toResponse)
            .toList();
    }

    public BigDecimal getTotalMarketValue(UUID userId) {
        return getHoldingsWithMarketValue(userId).stream()
            .map(HoldingResponse::marketValue)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /**
     * 将一笔订单的成交结果累加到用户持仓。
     * 若该用户对该基金尚无持仓记录则新建，否则累加份数和金额，并重新计算平均成本净值。
     */
    @Transactional
    public void applySettlement(UUID userId, UUID fundId, BigDecimal executedUnits, BigDecimal amount) {
        Holding h = holdingRepository.findByUserIdAndFundId(userId, fundId)
            .orElseGet(() -> {
                Holding n = new Holding();
                n.setUserId(userId);
                n.setFundId(fundId);
                return n;
            });
        BigDecimal newTotalUnits    = h.getTotalUnits().add(executedUnits);
        BigDecimal newTotalInvested = h.getTotalInvested().add(amount);
        h.setTotalUnits(newTotalUnits);
        h.setTotalInvested(newTotalInvested);
        h.setAvgCostNav(newTotalInvested.divide(newTotalUnits, 4, RoundingMode.HALF_UP));
        h.setUpdatedAt(OffsetDateTime.now());
        holdingRepository.save(h);
    }

    private HoldingResponse toResponse(Holding h) {
        BigDecimal marketValue = fundNavHistoryRepository
            .findTopByFundIdOrderByNavDateDesc(h.getFundId())
            .map(nav -> h.getTotalUnits().multiply(nav.getNav()).setScale(2, RoundingMode.HALF_UP))
            .orElse(h.getTotalInvested());
        return fundRepository.findById(h.getFundId())
            .map(f -> new HoldingResponse(h.getId(), h.getFundId(), f.getName(), f.getCode(),
                    h.getTotalUnits(), h.getTotalInvested(), marketValue))
            .orElse(new HoldingResponse(h.getId(), h.getFundId(), null, null,
                    h.getTotalUnits(), h.getTotalInvested(), marketValue));
    }
}
