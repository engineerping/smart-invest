package com.smartinvest.order.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

/** order-service 配置 —— RestTemplate Bean，用于服务间调用 */
@Configuration
public class OrderClientConfig {

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
