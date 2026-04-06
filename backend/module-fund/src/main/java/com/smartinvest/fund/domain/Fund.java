package com.smartinvest.fund.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;
import java.math.BigDecimal;
import java.time.*;
import java.util.UUID;

@Entity @Table(name = "funds")
@Getter @Setter @NoArgsConstructor
public class Fund {
    @Id @UuidGenerator UUID id;
    String code;
    @Column(name = "isin_class") String isinClass;
    String name;
    @Column(name = "fund_type") String fundType;
    @Column(name = "risk_level") short riskLevel;
    String currency;
    @Column(name = "current_nav") BigDecimal currentNav;
    @Column(name = "nav_date") LocalDate navDate;
    @Column(name = "annual_mgmt_fee") BigDecimal annualMgmtFee;
    @Column(name = "min_investment") BigDecimal minInvestment;
    @Column(name = "benchmark_index") String benchmarkIndex;
    @Column(name = "market_focus") String marketFocus;
    @Column(columnDefinition = "TEXT") String description;
    @Column(name = "is_active") boolean isActive = true;
    @Column(name = "created_at") OffsetDateTime createdAt = OffsetDateTime.now();
}