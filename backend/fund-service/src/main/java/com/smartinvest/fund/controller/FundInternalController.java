package com.smartinvest.fund.controller;

import com.smartinvest.fund.repository.FundNavHistoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.UUID;

/**
 * 内部接口 —— 供 order-service 同步调用
 * =============================================================================
 * 为什么叫 /internal/？
 *   这是服务之间的调用契约（服务发现 + 同步 REST），不对前端开放。
 *   路径前缀区分"面向外部的 API"和"面向内部服务的 API"，
 *   是微服务架构里的常见约定（也方便安全策略按路径分组放行）。
 *
 * 这个接口暴露基金的"最新净值"，order-service 下单结算时需要它：
 *   成交份数 = 投资金额 ÷ 最新净值
 * =============================================================================
 */
@RestController
@RequestMapping("/internal/funds")
@RequiredArgsConstructor
public class FundInternalController {

    private final FundNavHistoryRepository navHistoryRepository;

    /** 返回某基金最新净值 */
    @GetMapping("/{fundId}/latest-nav")
    public ResponseEntity<Map<String, BigDecimal>> latestNav(@PathVariable UUID fundId) {
        BigDecimal nav = navHistoryRepository.findTopByFundIdOrderByNavDateDesc(fundId)
                .orElseThrow(() -> new NoSuchElementException("No NAV available for fund " + fundId))
                .getNav();
        return ResponseEntity.ok(Map.of("nav", nav));
    }
}
