package com.smartinvest.notification.controller;

import com.smartinvest.notification.domain.Notification;
import com.smartinvest.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * 通知查询接口 —— 前端展示用户的通知列表
 * =============================================================================
 * 前端登录后调用 GET /api/notifications 拿到通知（订单成交提示等）。
 * 通知数据的产生是异步的（来自 RabbitMQ 消费），这里是查询侧。
 * =============================================================================
 */
@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    @GetMapping
    public List<Notification> myNotifications(@AuthenticationPrincipal UserDetails principal) {
        return notificationService.getMyNotifications(UUID.fromString(principal.getUsername()));
    }
}
