package com.budgetly.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableAsync
public class BudgetlyApplication {
    public static void main(String[] args) {
        SpringApplication.run(BudgetlyApplication.class, args);
    }
}
