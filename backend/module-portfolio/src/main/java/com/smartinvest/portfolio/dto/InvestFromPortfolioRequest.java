package com.smartinvest.portfolio.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;

public record InvestFromPortfolioRequest(
    /** ONE_TIME 或 MONTHLY */
    @NotBlank String investmentType,
    @NotNull @DecimalMin("500.00") BigDecimal totalAmount,
    LocalDate startDate,
    String investmentAccount,
    String settlementAccount
) {}
