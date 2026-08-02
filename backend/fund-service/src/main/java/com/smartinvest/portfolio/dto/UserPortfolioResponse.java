package com.smartinvest.portfolio.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public record UserPortfolioResponse(
    UUID id,
    String name,
    String status,
    List<AllocationDetail> allocations,
    OffsetDateTime createdAt
) {
    public record AllocationDetail(
        UUID fundId,
        String fundName,
        String fundCode,
        BigDecimal allocationPct
    ) {}
}
