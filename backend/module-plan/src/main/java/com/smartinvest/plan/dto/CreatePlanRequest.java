package com.smartinvest.plan.dto;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record CreatePlanRequest(
    @NotNull UUID fundId,
    @NotNull @DecimalMin("100.00") BigDecimal monthlyAmount,
    LocalDate startDate,
    String investmentAccount,
    String settlementAccount
) {}
