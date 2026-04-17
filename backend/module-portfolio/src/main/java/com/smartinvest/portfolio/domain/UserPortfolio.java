package com.smartinvest.portfolio.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "user_portfolios")
@Getter @Setter @NoArgsConstructor
public class UserPortfolio {

    @Id @UuidGenerator
    UUID id;

    @Column(name = "user_id", nullable = false)
    UUID userId;

    @Column(nullable = false)
    String name;

    @Column(nullable = false)
    String status = "ACTIVE";  // ACTIVE | DELETED

    @Column(name = "created_at")
    OffsetDateTime createdAt = OffsetDateTime.now();

    @OneToMany(mappedBy = "portfolio", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    List<UserPortfolioAllocation> allocations = new ArrayList<>();
}
