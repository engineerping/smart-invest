package com.smartinvest.portfolio.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record HoldingResponse(
    UUID id,
    UUID fundId,
    String fundName,
    String fundCode,
    BigDecimal totalUnits,
    BigDecimal totalInvested,
    BigDecimal marketValue
) {}
