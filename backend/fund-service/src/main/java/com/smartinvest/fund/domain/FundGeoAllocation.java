package com.smartinvest.fund.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity @Table(name = "fund_geo_allocations")
@Getter @Setter @NoArgsConstructor
public class FundGeoAllocation {
    @Id @UuidGenerator UUID id;
    @Column(name = "fund_id", nullable = false) UUID fundId;
    String region;
    BigDecimal percentage;
    @Column(name = "as_of_date") LocalDate asOfDate;
}
