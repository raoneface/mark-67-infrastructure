package com.project.demo.service;

import com.project.demo.repository.TodoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.actuator.health.Health;
import org.springframework.boot.actuator.health.HealthIndicator;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class HealthService {

    private final TodoRepository todoRepository;
    private final MongoTemplate mongoTemplate;

    public Map<String, Object> getHealthStatus() {
        Map<String, Object> healthData = new HashMap<>();
        
        // Application status
        healthData.put("status", "UP");
        healthData.put("timestamp", LocalDateTime.now());
        healthData.put("application", "Todo Application");
        healthData.put("version", "1.0.0");
        
        // Database connectivity check
        Map<String, Object> database = new HashMap<>();
        try {
            // Test MongoDB connection
            mongoTemplate.getDb().runCommand(new org.bson.Document("ping", 1));
            database.put("status", "UP");
            database.put("type", "MongoDB");
            
            // Get database stats
            long todoCount = todoRepository.count();
            database.put("todoCount", todoCount);
            
        } catch (Exception e) {
            database.put("status", "DOWN");
            database.put("error", e.getMessage());
        }
        healthData.put("database", database);
        
        // System information
        Map<String, Object> system = new HashMap<>();
        Runtime runtime = Runtime.getRuntime();
        system.put("totalMemory", runtime.totalMemory());
        system.put("freeMemory", runtime.freeMemory());
        system.put("maxMemory", runtime.maxMemory());
        system.put("availableProcessors", runtime.availableProcessors());
        healthData.put("system", system);
        
        // Service status
        Map<String, Object> services = new HashMap<>();
        services.put("todoService", "UP");
        services.put("healthService", "UP");
        healthData.put("services", services);
        
        return healthData;
    }
}