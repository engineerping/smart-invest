package com.smartinvest.order.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;
import java.math.BigDecimal;
import java.time.*;
import java.util.UUID;

@Entity @Table(name = "orders")
@Getter @Setter @NoArgsConstructor
public class Order {
    @Id @UuidGenerator UUID id;
    @Column(name = "reference_number", unique = true, nullable = false) String referenceNumber;
    @Column(name = "user_id", nullable = false) UUID userId;
    @Column(name = "fund_id", nullable = false) UUID fundId;
    @Column(name = "order_type", nullable = false) String orderType;      // ONE_TIME | MONTHLY_PLAN
    @Column(name = "investment_type", nullable = false) String investmentType; // BUY
    BigDecimal amount;
    @Column(name = "nav_at_order") BigDecimal navAtOrder;
    @Column(name = "executed_units") BigDecimal executedUnits;
    @Column(name = "investment_account") String investmentAccount;
    @Column(name = "settlement_account") String settlementAccount;
    String status = "PENDING";   // PENDING | PROCESSING | COMPLETED | CANCELLED | FAILED
    @Column(name = "order_date") LocalDate orderDate = LocalDate.now();
    @Column(name = "settlement_date") LocalDate settlementDate;
    @Column(name = "plan_id") UUID planId;
    @Column(name = "created_at") OffsetDateTime createdAt = OffsetDateTime.now();
    @Column(name = "completed_at") OffsetDateTime completedAt;
}