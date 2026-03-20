package com.budgetly.api.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.mongodb.config.EnableMongoAuditing;

@Configuration
@EnableMongoAuditing
public class MongoConfig {
    // MongoDB is configured via application.yml (spring.data.mongodb.uri)
    // Auditing enabled for @CreatedDate, @LastModifiedDate support if needed
}
