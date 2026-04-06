package com.smartinvest.order.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record OrderResponse(
    UUID id,
    String referenceNumber,
    UUID fundId,
    String orderType,
    String investmentType,
    BigDecimal amount,
    String status,
    LocalDate orderDate,
    LocalDate settlementDate,
    java.time.OffsetDateTime createdAt
) {}