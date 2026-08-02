package com.smartinvest.fund;

import com.smartinvest.common.security.CommonSecurityConfig;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Import;

/**
 * fund-service 启动类
 * =============================================================================
 * 组件扫描整个 com.smartinvest 包（包括 common 里的配置和 event 监听器）。
 * =============================================================================
 */
@SpringBootApplication(scanBasePackages = "com.smartinvest")
@Import(CommonSecurityConfig.class)
public class FundServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(FundServiceApplication.class, args);
    }
}
