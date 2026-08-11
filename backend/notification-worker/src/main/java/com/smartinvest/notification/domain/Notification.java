package com.smartinvest.notification.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UuidGenerator;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 通知实体 —— 对应 V21 迁移创建的 notifications 表
 */
@Entity
@Table(name = "notifications")
@Getter @Setter @NoArgsConstructor
public class Notification {
    @Id @UuidGenerator UUID id;
    @Column(name = "user_id", nullable = false) UUID userId;
    @Column(nullable = false) String type;       // ORDER_COMPLETED 等
    @Column(nullable = false) String title;
    @Column(columnDefinition = "TEXT") String body;
    @Column(name = "reference_number") String referenceNumber;
    @Column(nullable = false) String status = "UNREAD";  // UNREAD | READ
    @Column(name = "created_at") OffsetDateTime createdAt = OffsetDateTime.now();
}
