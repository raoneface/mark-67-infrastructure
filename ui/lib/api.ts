import axios from "axios";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080/api";

export const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
});

export interface ApiResponse<T> {
  message?: string;
  error?: string;
  data?: T;
  timestamp?: string;
  statusCode?: number;
}

export interface Todo {
  id: string;
  title: string;
  description?: string;
  completed: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface TodoRequest {
  title: string;
  description?: string;
  completed?: boolean;
}

export interface HealthData {
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

export const todoApi = {
  getAllTodos: () => api.get<ApiResponse<Todo[]>>("/todos"),
  getTodosByStatus: (completed: boolean) =>
    api.get<ApiResponse<Todo[]>>(`/todos?completed=${completed}`),
  getTodoById: (id: string) => api.get<ApiResponse<Todo>>(`/todos/${id}`),
  createTodo: (todo: TodoRequest) =>
    api.post<ApiResponse<Todo>>("/todos", todo),
  updateTodo: (id: string, todo: TodoRequest) =>
    api.put<ApiResponse<Todo>>(`/todos/${id}`, todo),
  deleteTodo: (id: string) => api.delete<ApiResponse<void>>(`/todos/${id}`),
};

export const healthApi = {
  getHealth: () => api.get<ApiResponse<HealthData>>("/health"),
};
