package com.smartinvest;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class SmartInvestApplication {
    public static void main(String[] args) {
        SpringApplication.run(SmartInvestApplication.class, args);
    }
}
