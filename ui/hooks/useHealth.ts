import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";

interface HealthData {
  status: string;
  timestamp: string;
  application: string;
  version: string;
  database: {
    status: string;
    type: string;
    todoCount: number;
    error?: string;
  };
  system: {
    totalMemory: number;
    freeMemory: number;
    maxMemory: number;
    availableProcessors: number;
  };
  services: {
    [key: string]: string;
  };
}

interface HealthResponse {
  message: string;
  data: HealthData;
  timestamp: string;
  statusCode: number;
}

export const useHealth = () => {
  return useQuery<HealthData>({
    queryKey: ["health"],
    queryFn: async () => {
      try {
        const response = await api.get<HealthResponse>("/health");
        return response.data.data;
      } catch (error) {
        // If the custom health endpoint fails, try to infer health from API availability
        try {
          await api.get("/todos");
          return { 
            status: "UP",
            timestamp: new Date().toISOString(),
            application: "Todo Application",
            version: "1.0.0",
            database: { status: "UNKNOWN", type: "MongoDB", todoCount: 0 },
            system: { totalMemory: 0, freeMemory: 0, maxMemory: 0, availableProcessors: 0 },
            services: { todoService: "UP" }
          };
        } catch {
          throw error; // Backend is truly down
        }
      }
    },
    refetchInterval: 30000, // Refetch every 30 seconds
    retry: 2,
    retryDelay: 1000,
  });
};
