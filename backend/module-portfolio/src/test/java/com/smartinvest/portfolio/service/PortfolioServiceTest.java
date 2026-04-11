package com.smartinvest.portfolio.service;

import com.smartinvest.fund.domain.FundNavHistory;
import com.smartinvest.fund.repository.FundNavHistoryRepository;
import com.smartinvest.portfolio.domain.Holding;
import com.smartinvest.portfolio.dto.HoldingResponse;
import com.smartinvest.portfolio.repository.HoldingRepository;
import com.smartinvest.fund.repository.FundRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PortfolioServiceTest {

    @Mock HoldingRepository holdingRepository;
    @Mock FundNavHistoryRepository fundNavHistoryRepository;
    @Mock FundRepository fundRepository;
    @InjectMocks PortfolioService portfolioService;

    @Test
    void getHoldingsWithMarketValue_computesMarketValueFromNav() {
        UUID userId = UUID.randomUUID();
        UUID fundId = UUID.randomUUID();

        Holding holding = new Holding();
        holding.setId(UUID.randomUUID());
        holding.setUserId(userId);
        holding.setFundId(fundId);
        holding.setTotalUnits(new BigDecimal("100.000000"));
        holding.setTotalInvested(new BigDecimal("950.00"));

        FundNavHistory nav = new FundNavHistory();
        nav.setFundId(fundId);
        nav.setNav(new BigDecimal("10.5000"));
        nav.setNavDate(LocalDate.now());

        when(holdingRepository.findByUserId(userId)).thenReturn(List.of(holding));
        when(fundNavHistoryRepository.findTopByFundIdOrderByNavDateDesc(fundId))
            .thenReturn(Optional.of(nav));

        List<HoldingResponse> result = portfolioService.getHoldingsWithMarketValue(userId);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).marketValue()).isEqualByComparingTo("1050.00");
    }

    @Test
    void getHoldingsWithMarketValue_fallsBackToTotalInvestedWhenNoNav() {
        UUID userId = UUID.randomUUID();
        UUID fundId = UUID.randomUUID();

        Holding holding = new Holding();
        holding.setId(UUID.randomUUID());
        holding.setUserId(userId);
        holding.setFundId(fundId);
        holding.setTotalUnits(new BigDecimal("100.000000"));
        holding.setTotalInvested(new BigDecimal("950.00"));

        when(holdingRepository.findByUserId(userId)).thenReturn(List.of(holding));
        when(fundNavHistoryRepository.findTopByFundIdOrderByNavDateDesc(fundId))
            .thenReturn(Optional.empty());

        List<HoldingResponse> result = portfolioService.getHoldingsWithMarketValue(userId);

        assertThat(result.get(0).marketValue()).isEqualByComparingTo("950.00");
    }

    @Test
    void getTotalMarketValue_sumsAllHoldingMarketValues() {
        UUID userId = UUID.randomUUID();
        UUID fundId1 = UUID.randomUUID();
        UUID fundId2 = UUID.randomUUID();

        Holding h1 = new Holding();
        h1.setId(UUID.randomUUID());
        h1.setUserId(userId);
        h1.setFundId(fundId1);
        h1.setTotalUnits(new BigDecimal("100.000000"));
        h1.setTotalInvested(new BigDecimal("1000.00"));

        Holding h2 = new Holding();
        h2.setId(UUID.randomUUID());
        h2.setUserId(userId);
        h2.setFundId(fundId2);
        h2.setTotalUnits(new BigDecimal("50.000000"));
        h2.setTotalInvested(new BigDecimal("500.00"));

        FundNavHistory nav1 = new FundNavHistory();
        nav1.setNav(new BigDecimal("10.0000"));

        FundNavHistory nav2 = new FundNavHistory();
        nav2.setNav(new BigDecimal("20.0000"));

        when(holdingRepository.findByUserId(userId)).thenReturn(List.of(h1, h2));
        when(fundNavHistoryRepository.findTopByFundIdOrderByNavDateDesc(fundId1))
            .thenReturn(Optional.of(nav1));
        when(fundNavHistoryRepository.findTopByFundIdOrderByNavDateDesc(fundId2))
            .thenReturn(Optional.of(nav2));

        BigDecimal total = portfolioService.getTotalMarketValue(userId);

        // h1: 100 × 10 = 1000, h2: 50 × 20 = 1000, total = 2000
        assertThat(total).isEqualByComparingTo("2000.00");
    }

    @Test
    void getTotalMarketValue_returnsZeroWhenNoHoldings() {
        UUID userId = UUID.randomUUID();
        when(holdingRepository.findByUserId(userId)).thenReturn(List.of());

        BigDecimal total = portfolioService.getTotalMarketValue(userId);

        assertThat(total).isEqualByComparingTo(BigDecimal.ZERO);
    }
}
