package com.smartinvest.config;

import org.springframework.context.annotation.*;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.ses.SesClient;

@Configuration
public class AwsConfig {

    @Bean
    @Profile("!local")
    public SesClient sesClient(@org.springframework.beans.factory.annotation.Value("${aws.region}") String region) {
        return SesClient.builder().region(Region.of(region)).build();
    }

    @Bean
    @Profile("local")
    public SesClient sesClientLocal() {
        // No-op stub for local dev
        return SesClient.builder().region(Region.US_EAST_1).build();
    }
}
