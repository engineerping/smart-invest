package com.smartinvest.fund.domain;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity @Table(name = "fund_nav_history")
@Getter @Setter @NoArgsConstructor
public class FundNavHistory {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) Long id;
    @Column(name = "fund_id", nullable = false) UUID fundId;
    @Column(nullable = false) BigDecimal nav;
    @Column(name = "nav_date", nullable = false) LocalDate navDate;
}