package com.smartinvest.portfolio.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity @Table(name = "holdings")
@Getter @Setter @NoArgsConstructor
public class Holding {
    @Id @UuidGenerator UUID id;
    @Column(name = "user_id", nullable = false) UUID userId;
    @Column(name = "fund_id", nullable = false) UUID fundId;
    @Column(name = "total_units") BigDecimal totalUnits = BigDecimal.ZERO;
    @Column(name = "avg_cost_nav") BigDecimal avgCostNav;
    @Column(name = "total_invested") BigDecimal totalInvested = BigDecimal.ZERO;
    @Column(name = "updated_at") OffsetDateTime updatedAt = OffsetDateTime.now();
}
