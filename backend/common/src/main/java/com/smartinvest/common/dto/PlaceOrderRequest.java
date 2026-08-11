package com.smartinvest.common.dto;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * 下单请求 DTO —— 放在 common 共享库
 * =============================================================================
 * 为什么放这：fund-service 的 PortfolioService 需要构造这个请求，
 * 通过 REST 调用 order-service 下单。两个服务都要认识这个类型，
 * 所以放进 common，避免重复定义。
 * =============================================================================
 */
public record PlaceOrderRequest(
    @NotNull UUID fundId,
    @NotBlank String orderType,
    @NotNull @DecimalMin("100.00") BigDecimal amount,
    LocalDate startDate,
    String investmentAccount,
    String settlementAccount,
    UUID portfolioId   // nullable：从自建组合下单时传入，用于分组
) {}
