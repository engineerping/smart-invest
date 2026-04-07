package com.smartinvest.portfolio.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record HoldingResponse(
    UUID id,
    UUID fundId,
    BigDecimal totalUnits,
    BigDecimal totalInvested,
    BigDecimal marketValue
) {}
