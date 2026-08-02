package com.smartinvest.user.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity @Table(name = "users")
@Getter @Setter @NoArgsConstructor
public class User {
    @Id @UuidGenerator UUID id;
    @Column(unique = true, nullable = false) String email;
    @Column(nullable = false) String password;
    @Column(name = "full_name", nullable = false) String fullName;
    @Column(name = "risk_level") Short riskLevel;
    @Column(nullable = false) String status = "ACTIVE";
    @Column(name = "created_at") OffsetDateTime createdAt = OffsetDateTime.now();
    @Column(name = "updated_at") OffsetDateTime updatedAt = OffsetDateTime.now();

    @PreUpdate void onUpdate() { updatedAt = OffsetDateTime.now(); }
}