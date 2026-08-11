package com.smartinvest.notification.service;

import com.smartinvest.notification.domain.Notification;
import com.smartinvest.notification.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

/** 通知查询服务 */
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository repository;

    public List<Notification> getMyNotifications(UUID userId) {
        return repository.findByUserIdOrderByCreatedAtDesc(userId);
    }
}
