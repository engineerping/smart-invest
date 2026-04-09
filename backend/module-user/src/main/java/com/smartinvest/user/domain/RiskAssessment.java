package com.smartinvest.user.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity @Table(name = "risk_assessments")
@Getter @Setter @NoArgsConstructor
public class RiskAssessment {
    @Id @UuidGenerator UUID id;
    @Column(name = "user_id", nullable = false) UUID userId;
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb", nullable = false) String answers;
    @Column(name = "total_score", nullable = false) Integer totalScore;
    @Column(name = "risk_level", nullable = false) Short riskLevel;
    @Column(name = "assessed_at") OffsetDateTime assessedAt = OffsetDateTime.now();
}