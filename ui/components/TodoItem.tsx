"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Checkbox } from "@/components/ui/checkbox";
import { Card, CardContent } from "@/components/ui/card";
import { useUpdateTodo, useDeleteTodo } from "@/hooks/useTodos";
import { Todo } from "@/lib/api";
import { Trash2, Edit2, Check, X } from "lucide-react";

interface TodoItemProps {
  todo: Todo;
}

export default function TodoItem({ todo }: TodoItemProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState(todo.title);
  const [editDescription, setEditDescription] = useState(
    todo.description || ""
  );

  const updateTodo = useUpdateTodo();
  const deleteTodo = useDeleteTodo();

  const handleToggleComplete = async () => {
    try {
      await updateTodo.mutateAsync({
        id: todo.id,
        todo: {
          title: todo.title,
          description: todo.description,
          completed: !todo.completed,
        },
      });
    } catch (error) {
      console.error("Failed to update todo:", error);
    }
  };

  const handleSaveEdit = async () => {
    if (!editTitle.trim()) return;

    try {
      await updateTodo.mutateAsync({
        id: todo.id,
        todo: {
          title: editTitle.trim(),
          description: editDescription.trim() || undefined,
          completed: todo.completed,
        },
      });
      setIsEditing(false);
    } catch (error) {
      console.error("Failed to update todo:", error);
    }
  };

  const handleCancelEdit = () => {
    setEditTitle(todo.title);
    setEditDescription(todo.description || "");
    setIsEditing(false);
  };

  const handleDelete = async () => {
    if (confirm("Are you sure you want to delete this todo?")) {
      try {
        await deleteTodo.mutateAsync(todo.id);
      } catch (error) {
        console.error("Failed to delete todo:", error);
      }
    }
  };

  return (
    <div
      className={`bg-gray-50 rounded-xl p-4 border-2 border-transparent hover:border-gray-200 transition-all ${
        todo.completed ? "opacity-60" : ""
      }`}
    >
      <div className="flex items-start gap-4">
        <Checkbox
          checked={todo.completed}
          onCheckedChange={handleToggleComplete}
          disabled={updateTodo.isPending}
          className="mt-1 scale-125"
        />

        <div className="flex-1 min-w-0">
          {isEditing ? (
            <div className="space-y-3">
              <Input
                value={editTitle}
                onChange={(e) => setEditTitle(e.target.value)}
                placeholder="Task title..."
                className="border-2 border-gray-200 focus:border-blue-500 rounded-lg"
              />
              <Input
                value={editDescription}
                onChange={(e) => setEditDescription(e.target.value)}
                placeholder="Description (optional)..."
                className="border-2 border-gray-200 focus:border-blue-500 rounded-lg"
              />
              <div className="flex gap-2">
                <Button
                  size="sm"
                  onClick={handleSaveEdit}
                  disabled={!editTitle.trim() || updateTodo.isPending}
                  className="bg-green-600 hover:bg-green-700 rounded-lg"
                >
                  <Check className="h-4 w-4" />
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={handleCancelEdit}
                  className="rounded-lg"
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
            </div>
          ) : (
            <div>
              <h3
                className={`font-medium text-lg ${
                  todo.completed
                    ? "line-through text-gray-500"
                    : "text-gray-800"
                }`}
              >
                {todo.title}
              </h3>
              {todo.description && (
                <p
                  className={`text-gray-600 mt-1 ${
                    todo.completed ? "line-through" : ""
                  }`}
                >
                  {todo.description}
                </p>
              )}
              <p className="text-xs text-gray-400 mt-3">
                Created {new Date(todo.createdAt).toLocaleDateString()}
              </p>
            </div>
          )}
        </div>

        {!isEditing && (
          <div className="flex gap-1">
            <Button
              size="sm"
              variant="ghost"
              onClick={() => setIsEditing(true)}
              className="text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded-lg"
            >
              <Edit2 className="h-4 w-4" />
            </Button>
            <Button
              size="sm"
              variant="ghost"
              onClick={handleDelete}
              disabled={deleteTodo.isPending}
              className="text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-lg"
            >
              <Trash2 className="h-4 w-4" />
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}
