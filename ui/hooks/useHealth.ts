import { useQuery } from "@tanstack/react-query";
import axios from "axios";

interface HealthResponse {
  status: string;
  components?: {
    [key: string]: {
      status: string;
      details?: any;
    };
  };
}

const healthApi = axios.create({
  baseURL: "http://34.237.223.247:8080", // Direct actuator endpoint without /api prefix
  timeout: 5000,
});

export const useHealth = () => {
  return useQuery<HealthResponse>({
    queryKey: ["health"],
    queryFn: async () => {
      try {
        const response = await healthApi.get("/actuator/health");
        return response.data;
      } catch (error) {
        // If CORS error or network error, try to infer health from API availability
        if (
          axios.isAxiosError(error) &&
          (error.code === "ERR_NETWORK" || error.message.includes("CORS"))
        ) {
          // Try a simple API call to check if backend is responsive
          try {
            await axios.get("http://34.237.223.247:8080/api/todos", {
              timeout: 3000,
            });
            return { status: "UP" }; // Backend is responsive via API
          } catch {
            throw error; // Backend is truly down
          }
        }
        throw error;
      }
    },
    refetchInterval: 30000, // Refetch every 30 seconds
    retry: 2,
    retryDelay: 1000,
  });
};
