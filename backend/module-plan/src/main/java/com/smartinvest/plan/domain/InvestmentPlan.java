package com.smartinvest.plan.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;
import java.math.BigDecimal;
import java.time.*;
import java.util.UUID;

@Entity @Table(name = "investment_plans")
@Getter @Setter @NoArgsConstructor
public class InvestmentPlan {
    @Id @UuidGenerator UUID id;
    @Column(name = "reference_number", unique = true, nullable = false) String referenceNumber;
    @Column(name = "user_id", nullable = false) UUID userId;
    @Column(name = "fund_id", nullable = false) UUID fundId;
    @Transient String fundName;
    @Column(name = "monthly_amount", nullable = false) BigDecimal monthlyAmount;
    @Column(name = "next_contribution_date", nullable = false) LocalDate nextContributionDate;
    @Column(name = "investment_account") String investmentAccount;
    @Column(name = "settlement_account") String settlementAccount;
    String status = "ACTIVE";   // ACTIVE | TERMINATED
    @Column(name = "completed_orders") int completedOrders = 0;
    @Column(name = "total_invested") BigDecimal totalInvested = BigDecimal.ZERO;
    @Column(name = "plan_creation_date") LocalDate planCreationDate = LocalDate.now();
    @Column(name = "terminated_at") OffsetDateTime terminatedAt;
}
