import TodoForm from "@/components/TodoForm";
import TodoList from "@/components/TodoList";

export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 py-12">
      <div className="max-w-2xl mx-auto px-4">
        <header className="text-center mb-12">
          <h1 className="text-6xl font-bold text-gray-900 mb-4 tracking-tight">
            Your Todo List
          </h1>
          <p className="text-xl text-gray-600 font-medium">
            Stay organized and get things done
          </p>
        </header>

        <div className="space-y-8">
          <div className="bg-white rounded-2xl shadow-xl p-8">
            <TodoForm />
          </div>

          <div className="bg-white rounded-2xl shadow-xl p-8">
            <TodoList />
          </div>
        </div>
      </div>
    </div>
  );
}
