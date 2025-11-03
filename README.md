# Todo Application

A full-stack todo application built with Spring Boot (backend) and Next.js (frontend).

## Features

- ✅ Create, read, update, and delete todos
- ✅ Mark todos as completed/incomplete
- ✅ Filter todos by status (all, active, completed)
- ✅ Real-time updates with React Query
- ✅ Responsive design with Tailwind CSS and shadcn/ui
- ✅ Input validation
- ✅ Generic API response structure
- ✅ Health check endpoint via Spring Actuator
- ✅ CORS configuration for frontend integration

## Tech Stack

### Backend

- **Spring Boot 3.5.7** - Java framework
- **MongoDB** - Database
- **Spring Data MongoDB** - Data access layer
- **Spring Boot Validation** - Input validation
- **Lombok** - Reduce boilerplate code
- **Spring Boot Actuator** - Health monitoring

### Frontend

- **Next.js 16** - React framework
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **shadcn/ui** - UI components
- **React Query (@tanstack/react-query)** - Data fetching and caching
- **Axios** - HTTP client

## Getting Started

### Prerequisites

- Java 21+
- Node.js 18+
- Docker (for MongoDB)

### Backend Setup

1. **Start MongoDB with Docker:**

   ```bash
   cd demo
   docker-compose up -d
   ```

2. **Run the Spring Boot application:**

   ```bash
   cd demo
   ./mvnw spring-boot:run
   ```

   The backend will be available at `http://localhost:8080`

3. **Health Check:**
   Visit `http://localhost:8080/actuator/health` to verify the application is running.

### Frontend Setup

1. **Install dependencies:**

   ```bash
   cd ui
   npm install
   ```

2. **Run the development server:**

   ```bash
   npm run dev
   ```

   The frontend will be available at `http://localhost:3000`

## API Endpoints

### Todos

- `GET /api/todos` - Get all todos
- `GET /api/todos?completed=true` - Get completed todos
- `GET /api/todos?completed=false` - Get active todos
- `GET /api/todos/{id}` - Get todo by ID
- `POST /api/todos` - Create new todo
- `PUT /api/todos/{id}` - Update todo
- `DELETE /api/todos/{id}` - Delete todo

### Health

- `GET /actuator/health` - Application health status

## API Response Format

All API responses follow this generic structure:

```json
{
  "message": "Success message",
  "data": "Response data",
  "timestamp": "2024-01-01T12:00:00",
  "statusCode": 200
}
```

For errors:

```json
{
  "error": "Error message",
  "timestamp": "2024-01-01T12:00:00",
  "statusCode": 400
}
```

## Project Structure

```
├── demo/                          # Spring Boot backend
│   ├── src/main/java/com/project/demo/
│   │   ├── controller/           # REST controllers
│   │   ├── service/             # Business logic
│   │   ├── repository/          # Data access
│   │   ├── entity/              # JPA entities
│   │   ├── dto/                 # Data transfer objects
│   │   ├── config/              # Configuration classes
│   │   └── exception/           # Exception handlers
│   ├── docker-compose.yml       # MongoDB setup
│   └── pom.xml                  # Maven dependencies
└── ui/                          # Next.js frontend
    ├── app/                     # Next.js app directory
    ├── components/              # React components
    ├── hooks/                   # Custom React hooks
    ├── lib/                     # Utility functions
    └── package.json             # npm dependencies
```

## Development

### Backend Development

- The application uses Spring Boot DevTools for hot reloading
- MongoDB data is persisted in Docker volumes
- Validation is handled by Spring Boot Validation
- CORS is configured to allow requests from localhost:3000 and localhost:3001

### Frontend Development

- React Query handles data fetching, caching, and synchronization
- shadcn/ui provides consistent, accessible UI components
- TypeScript ensures type safety across the application
- Tailwind CSS provides utility-first styling

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request
