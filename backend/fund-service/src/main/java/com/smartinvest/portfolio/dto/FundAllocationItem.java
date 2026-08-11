package com.smartinvest.portfolio.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.util.UUID;

public record FundAllocationItem(
    @NotNull UUID fundId,
    @NotNull @DecimalMin("0.01") @DecimalMax("100.00") BigDecimal allocationPct
) {}
