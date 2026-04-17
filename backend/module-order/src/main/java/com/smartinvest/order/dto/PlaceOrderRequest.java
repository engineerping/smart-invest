package com.smartinvest.order.dto;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record PlaceOrderRequest(
    @NotNull UUID fundId,
    @NotBlank String orderType,
    @NotNull @DecimalMin("100.00") BigDecimal amount,
    LocalDate startDate,
    String investmentAccount,
    String settlementAccount,
    UUID portfolioId   // nullable：从自建组合下单时传入，用于分组
) {}