"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useCreateTodo } from "@/hooks/useTodos";
import { TodoRequest } from "@/lib/api";

export default function TodoForm() {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const createTodo = useCreateTodo();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const todoData: TodoRequest = {
      title: title.trim(),
      description: description.trim() || undefined,
      completed: false,
    };

    try {
      await createTodo.mutateAsync(todoData);
      setTitle("");
      setDescription("");
    } catch (error) {
      console.error("Failed to create todo:", error);
    }
  };

  return (
    <div>
      <h2 className="text-2xl font-semibold text-gray-800 mb-6">
        Add New Task
      </h2>
      <form onSubmit={handleSubmit} className="space-y-4">
        <Input
          placeholder="What needs to be done?"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
          className="text-lg py-3 px-4 border-2 border-gray-200 focus:border-blue-500 rounded-xl"
        />
        <Input
          placeholder="Add a description (optional)..."
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          className="py-3 px-4 border-2 border-gray-200 focus:border-blue-500 rounded-xl"
        />
        <Button
          type="submit"
          disabled={!title.trim() || createTodo.isPending}
          className="w-full py-3 text-lg font-medium bg-blue-600 hover:bg-blue-700 rounded-xl transition-colors"
        >
          {createTodo.isPending ? "Adding..." : "Add Task"}
        </Button>
      </form>
    </div>
  );
}
