package com.smartinvest.fund.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity @Table(name = "fund_top_holdings")
@Getter @Setter @NoArgsConstructor
public class FundTopHolding {
    @Id @UuidGenerator UUID id;
    @Column(name = "fund_id", nullable = false) UUID fundId;
    @Column(name = "holding_name") String holdingName;
    BigDecimal weight;
    @Column(name = "as_of_date") LocalDate asOfDate;
    short sequence;
}