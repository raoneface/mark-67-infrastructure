package com.project.demo.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {
        // CORS configuration for API and Actuator endpoints

        @Override
        public void addCorsMappings(CorsRegistry registry) {
                // API endpoints - Allow all origins for production deployment
                registry.addMapping("/api/**")
                                .allowedOriginPatterns("*") // Allow all origins for flexibility
                                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                                .allowedHeaders("*")
                                .allowCredentials(false); // Set to false when using allowedOriginPatterns("*")

                // Actuator endpoints
                registry.addMapping("/actuator/**")
                                .allowedOriginPatterns("*") // Allow all origins for flexibility
                                .allowedMethods("GET", "OPTIONS")
                                .allowedHeaders("*")
                                .allowCredentials(false); // Set to false when using allowedOriginPatterns("*")
        }
}