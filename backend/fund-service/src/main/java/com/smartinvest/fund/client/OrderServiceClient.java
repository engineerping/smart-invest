package com.smartinvest.fund.client;

import com.smartinvest.common.dto.PlaceOrderRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.UUID;

/**
 * order-service 的 REST 客户端 —— 服务间同步调用
 * =============================================================================
 * fund-service 的"从组合投资"功能需要真正创建订单，
 * 但订单逻辑在 order-service（独立部署）。
 * 因此这里用 RestTemplate 发起 HTTP 调用，走 K8S 服务发现：
 *   order-service 的 K8S Service 名就是 order-service，
 *   集群内 URL：http://order-service:8083
 * 当前用户 ID 通过 X-User-Id 请求头传给内部接口。
 * =============================================================================
 */
@Component
public class OrderServiceClient {

    private final RestTemplate restTemplate;
    private final String orderServiceUrl;

    public OrderServiceClient(RestTemplate restTemplate,
                              @Value("${services.order-service-url:http://localhost:8083}") String orderServiceUrl) {
        this.restTemplate = restTemplate;
        this.orderServiceUrl = orderServiceUrl;
    }

    /** 调用 order-service 内部接口下单，返回订单 JSON */
    public Map<String, Object> placeOrder(UUID userId, PlaceOrderRequest req) {
        String url = orderServiceUrl + "/internal/orders";
        HttpHeaders headers = new HttpHeaders();
        headers.set("X-User-Id", userId.toString());
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<PlaceOrderRequest> entity = new HttpEntity<>(req, headers);
        ResponseEntity<Map> resp = restTemplate.exchange(url, HttpMethod.POST, entity, Map.class);
        return resp.getBody();
    }
}
