package com.smartinvest.notification;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class EmailNotificationService {

    @Value("${aws.ses.sender-email:noreply@smartinvest.example.com}")
    private String senderEmail;

    /**
     * Send order confirmation email via Amazon SES.
     * In local dev, emails are logged instead of sent.
     */
    public void sendOrderConfirmation(String toEmail, String referenceNumber, String fundName) {
        log.info("DEV] Sending order confirmation email");
        log.info("  From: {}", senderEmail);
        log.info("  To: {}", toEmail);
        log.info("  Subject: Smart Invest — Order Confirmed");
        log.info("  Body: Your order {} for {} has been received.", referenceNumber, fundName);
        // In production with real SES credentials:
        // sesClient.sendEmail(SendEmailRequest.builder()...);
    }
}
