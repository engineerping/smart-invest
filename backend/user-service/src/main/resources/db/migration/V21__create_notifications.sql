-- =============================================================================
-- V21: notifications 通知表
-- 由 notification-worker 消费 RabbitMQ 的 order.notification 消息后写入。
-- 归属 user-service 的迁移序列，因为 user-service 是唯一执行 Flyway 的服务。
-- =============================================================================
CREATE TABLE IF NOT EXISTS notifications (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID         NOT NULL REFERENCES users(id),
    type            VARCHAR(30)  NOT NULL,
    title           VARCHAR(255) NOT NULL,
    body            TEXT,
    reference_number VARCHAR(50),
    status          VARCHAR(20)  DEFAULT 'UNREAD',
    created_at      TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_created
    ON notifications (user_id, created_at DESC);
