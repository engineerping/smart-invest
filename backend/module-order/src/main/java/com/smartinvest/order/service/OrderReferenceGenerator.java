package com.smartinvest.order.service;

import org.springframework.stereotype.Component;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.ThreadLocalRandom;

@Component
public class OrderReferenceGenerator {

    public String generate(String orderType) {
        if ("ONE_TIME".equals(orderType)) {
            return "P-" + String.format("%06d",
                ThreadLocalRandom.current().nextInt(100_000, 999_999));
        }
        // MONTHLY_PLAN: YYYYMMDDHHmmss + 3-digit suffix = 17 chars
        return LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"))
            + String.format("%03d", ThreadLocalRandom.current().nextInt(0, 999));
    }
}