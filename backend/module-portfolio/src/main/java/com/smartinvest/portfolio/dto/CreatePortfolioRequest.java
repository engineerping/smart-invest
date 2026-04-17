package com.smartinvest.portfolio.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.util.List;

public record CreatePortfolioRequest(
    @NotBlank String name,
    @NotNull @Size(min = 2, message = "Portfolio must contain at least 2 funds") @Valid
    List<FundAllocationItem> allocations
) {}
