"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useTodos } from "@/hooks/useTodos";
import TodoItem from "./TodoItem";

export default function TodoList() {
  const [filter, setFilter] = useState<"all" | "active" | "completed">("all");

  const {
    data: todos,
    isLoading,
    error,
  } = useTodos(filter === "all" ? undefined : filter === "completed");

  if (isLoading) {
    return (
      <div>
        <h2 className="text-2xl font-semibold text-gray-800 mb-6">
          Your Tasks
        </h2>
        <div className="text-center py-8 text-gray-500">Loading tasks...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div>
        <h2 className="text-2xl font-semibold text-gray-800 mb-6">
          Your Tasks
        </h2>
        <div className="text-center py-8 text-red-500">
          Failed to load tasks. Please try again.
        </div>
      </div>
    );
  }

  const filteredTodos =
    todos?.filter((todo) => {
      if (filter === "active") return !todo.completed;
      if (filter === "completed") return todo.completed;
      return true;
    }) || [];

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-2xl font-semibold text-gray-800">Your Tasks</h2>
        <div className="text-sm text-gray-500">{todos?.length || 0} total</div>
      </div>

      <div className="flex gap-2 mb-6">
        <Button
          size="sm"
          variant={filter === "all" ? "default" : "outline"}
          onClick={() => setFilter("all")}
          className="rounded-full"
        >
          All ({todos?.length || 0})
        </Button>
        <Button
          size="sm"
          variant={filter === "active" ? "default" : "outline"}
          onClick={() => setFilter("active")}
          className="rounded-full"
        >
          Active ({todos?.filter((t) => !t.completed).length || 0})
        </Button>
        <Button
          size="sm"
          variant={filter === "completed" ? "default" : "outline"}
          onClick={() => setFilter("completed")}
          className="rounded-full"
        >
          Done ({todos?.filter((t) => t.completed).length || 0})
        </Button>
      </div>

      {filteredTodos.length === 0 ? (
        <div className="text-center text-gray-500 py-12">
          {filter === "all"
            ? "No tasks yet. Add your first task above!"
            : filter === "active"
            ? "No active tasks. Great job!"
            : "No completed tasks yet."}
        </div>
      ) : (
        <div className="space-y-3">
          {filteredTodos.map((todo) => (
            <TodoItem key={todo.id} todo={todo} />
          ))}
        </div>
      )}
    </div>
  );
}
