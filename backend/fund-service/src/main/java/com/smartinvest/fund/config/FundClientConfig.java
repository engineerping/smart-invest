package com.smartinvest.fund.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

/**
 * fund-service 配置 —— RestTemplate Bean
 * 用于服务间同步调用（调用 order-service）。
 */
@Configuration
public class FundClientConfig {

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
