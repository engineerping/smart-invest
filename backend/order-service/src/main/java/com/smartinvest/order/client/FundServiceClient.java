package com.smartinvest.order.client;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

/**
 * fund-service 的 REST 客户端 —— 服务间同步调用
 * =============================================================================
 * order-service 下单后需要知道"成交净值"，而这个数据存在 fund-service。
 * 这里调用 fund-service 的内部接口 GET /internal/funds/{id}/latest-nav 拿最新净值。
 * 走 K8S 服务发现：http://fund-service:8082
 * =============================================================================
 */
@Component
public class FundServiceClient {

    private final RestTemplate restTemplate;
    private final String fundServiceUrl;

    public FundServiceClient(RestTemplate restTemplate,
                             @Value("${services.fund-service-url:http://localhost:8082}") String fundServiceUrl) {
        this.restTemplate = restTemplate;
        this.fundServiceUrl = fundServiceUrl;
    }

    /** 获取基金最新净值 */
    public BigDecimal getLatestNav(UUID fundId) {
        String url = fundServiceUrl + "/internal/funds/" + fundId + "/latest-nav";
        ResponseEntity<Map> resp = restTemplate.getForEntity(url, Map.class);
        Object nav = resp.getBody() != null ? resp.getBody().get("nav") : null;
        return nav != null ? new BigDecimal(nav.toString()) : null;
    }
}
