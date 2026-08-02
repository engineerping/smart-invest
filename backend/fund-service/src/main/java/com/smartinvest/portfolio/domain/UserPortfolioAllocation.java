package com.smartinvest.portfolio.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "user_portfolio_allocations")
@Getter @Setter @NoArgsConstructor
public class UserPortfolioAllocation {

    @Id @UuidGenerator
    UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "portfolio_id", nullable = false)
    UserPortfolio portfolio;

    @Column(name = "fund_id", nullable = false)
    UUID fundId;

    @Column(name = "allocation_pct", nullable = false)
    BigDecimal allocationPct;
}
