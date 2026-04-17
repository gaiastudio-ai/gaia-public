# Gin & Fiber Web Framework Patterns

<!-- SECTION: gin -->
## Gin Patterns

- Router groups for versioned APIs: `v1 := r.Group("/api/v1")`
- Middleware: `r.Use(middleware)` — logging, auth, CORS, recovery
- Context: `c.JSON()`, `c.ShouldBindJSON()`, `c.Param()`, `c.Query()`
- Validation with binding tags: `binding:"required,min=1"`
- Error handling: custom error response struct with status codes
- Graceful shutdown with `signal.Notify` + `server.Shutdown`

<!-- SECTION: fiber -->
## Fiber Patterns

- Express-inspired API: `app.Get("/path", handler)`
- Middleware: `app.Use(middleware)` — similar to Express
- Context: `c.JSON()`, `c.BodyParser()`, `c.Params()`, `c.Query()`
- High performance via fasthttp (not net/http)
- Prefork for multi-core utilization

<!-- SECTION: grpc -->
## gRPC Patterns

- Protocol Buffers for service definition (`.proto` files)
- `protoc` compiler generates Go code
- Unary, server-streaming, client-streaming, bidirectional
- Interceptors for middleware (logging, auth, tracing)
- Health checks: `grpc_health_v1`
- Reflection for debugging: `reflection.Register(server)`

<!-- SECTION: database -->
## Database Patterns

- `database/sql` for raw SQL with connection pooling
- GORM for ORM: models with struct tags, migrations, associations
- sqlx for enhanced `database/sql` with named params and struct scanning
- Connection pool: `SetMaxOpenConns`, `SetMaxIdleConns`, `SetConnMaxLifetime`
- Transactions: `tx, err := db.Begin()` / `tx.Commit()` / `tx.Rollback()`
- Migrations: golang-migrate or GORM AutoMigrate
