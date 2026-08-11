package com.smartinvest.gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * api-gateway 启动类
 * =============================================================================
 * 统一入口：前端只访问网关，网关按路径把请求路由到各微服务。
 * 对应架构图里的 Kong Gateway / NLB。
 * 路由规则在 application.yml 里配置（Spring Cloud Gateway 声明式路由）。
 * =============================================================================
 */
@SpringBootApplication
public class ApiGatewayApplication {
    public static void main(String[] args) {
        SpringApplication.run(ApiGatewayApplication.class, args);
    }
}
