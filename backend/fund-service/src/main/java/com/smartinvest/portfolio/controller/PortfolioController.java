package com.smartinvest.portfolio.controller;

import com.smartinvest.portfolio.dto.*;
import com.smartinvest.portfolio.service.PortfolioService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/portfolio")
@RequiredArgsConstructor
public class PortfolioController {

    private final PortfolioService service;

    /** 创建自建组合模板 */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserPortfolioResponse create(
            @AuthenticationPrincipal UserDetails user,
            @Valid @RequestBody CreatePortfolioRequest req) {
        return service.createPortfolio(UUID.fromString(user.getUsername()), req);
    }

    /** 查看我的所有自建组合 */
    @GetMapping
    public List<UserPortfolioResponse> list(@AuthenticationPrincipal UserDetails user) {
        return service.getPortfolios(UUID.fromString(user.getUsername()));
    }

    /** 查看单个组合详情 */
    @GetMapping("/{id}")
    public UserPortfolioResponse get(
            @AuthenticationPrincipal UserDetails user,
            @PathVariable UUID id) {
        return service.getPortfolio(id, UUID.fromString(user.getUsername()));
    }

    /** 删除（软删除）组合模板 */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(
            @AuthenticationPrincipal UserDetails user,
            @PathVariable UUID id) {
        service.deletePortfolio(id, UUID.fromString(user.getUsername()));
    }

    /**
     * 从组合投资：按比例拆分金额创建订单（ONE_TIME）或定投计划（MONTHLY）。
     * 返回创建的 Order 列表或 InvestmentPlan 列表。
     */
    @PostMapping("/{id}/invest")
    @ResponseStatus(HttpStatus.CREATED)
    public List<?> invest(
            @AuthenticationPrincipal UserDetails user,
            @PathVariable UUID id,
            @Valid @RequestBody InvestFromPortfolioRequest req) {
        return service.invest(id, UUID.fromString(user.getUsername()), req);
    }
}
