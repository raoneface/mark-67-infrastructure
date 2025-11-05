"use client";

import { useHealth } from "@/hooks/useHealth";
import { useState } from "react";

export default function HealthIndicator() {
  const { data: health, isLoading, error } = useHealth();
  const [showDetails, setShowDetails] = useState(false);

  const getStatusInfo = () => {
    if (isLoading) {
      return {
        dot: "bg-gray-400 animate-pulse",
        text: "API Checking...",
      };
    }

    if (error) {
      return {
        dot: "bg-red-500",
        text: "API Disconnected",
      };
    }

    if (health?.status === "UP") {
      const dbStatus = health.database?.status === "UP" ? "✓" : "⚠";
      return {
        dot: "bg-green-500",
        text: `API Connected ${dbStatus}`,
      };
    }

    return {
      dot: "bg-yellow-500",
      text: "API Issues",
    };
  };

  const statusInfo = getStatusInfo();

  return (
    <div className="relative">
      <div 
        className="inline-flex items-center gap-2 px-3 py-1 rounded-full text-sm font-medium text-gray-600 bg-gray-100 cursor-pointer hover:bg-gray-200 transition-colors"
        onClick={() => setShowDetails(!showDetails)}
        title="Click for health details"
      >
        <div className={`w-2 h-2 rounded-full ${statusInfo.dot}`}></div>
        <span>{statusInfo.text}</span>
      </div>

      {showDetails && health && (
        <div className="absolute bottom-full right-0 mb-2 w-80 bg-white border border-gray-200 rounded-lg shadow-lg p-4 text-xs z-50">
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="font-medium">Application:</span>
              <span>{health.application} v{health.version}</span>
            </div>
            <div className="flex justify-between">
              <span className="font-medium">Database:</span>
              <span className={health.database?.status === "UP" ? "text-green-600" : "text-red-600"}>
                {health.database?.type} ({health.database?.status})
              </span>
            </div>
            {health.database?.todoCount !== undefined && (
              <div className="flex justify-between">
                <span className="font-medium">Todo Count:</span>
                <span>{health.database.todoCount}</span>
              </div>
            )}
            <div className="flex justify-between">
              <span className="font-medium">Memory:</span>
              <span>{Math.round((health.system?.freeMemory || 0) / 1024 / 1024)}MB free</span>
            </div>
            <div className="text-gray-500 text-center pt-2 border-t">
              Last updated: {new Date(health.timestamp).toLocaleTimeString()}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
