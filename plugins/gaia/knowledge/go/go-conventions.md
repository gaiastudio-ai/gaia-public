# Go Conventions & Project Structure

<!-- SECTION: project-layout -->
## Project Layout

```
project/
├── cmd/           # Entry points (main packages)
│   └── server/
│       └── main.go
├── internal/      # Private packages (not importable externally)
│   ├── handler/   # HTTP/gRPC handlers
│   ├── service/   # Business logic
│   ├── repository/# Data access
│   └── model/     # Domain models
├── pkg/           # Public reusable packages
├── api/           # API definitions (proto, OpenAPI)
├── config/        # Configuration
├── migrations/    # Database migrations
├── go.mod
├── go.sum
└── Makefile
```

<!-- SECTION: naming -->
## Naming Conventions

- Packages: short, lowercase, single word (`http`, `user`, `auth`)
- Exported: `PascalCase` — visible outside package
- Unexported: `camelCase` — private to package
- Interfaces: `-er` suffix for single-method (`Reader`, `Writer`, `Stringer`)
- Getters: no `Get` prefix — `user.Name()` not `user.GetName()`
- Acronyms: all caps (`HTTPHandler`, `URLParser`, `ID`)
- Test files: `xxx_test.go` alongside source

<!-- SECTION: code-style -->
## Code Style

- `gofmt` / `goimports` — non-negotiable formatting
- `golangci-lint` for comprehensive linting
- Short variable names in small scopes: `i`, `r`, `w`, `ctx`
- Descriptive names for exported APIs
- Group imports: stdlib, blank line, third-party, blank line, internal
- No unused imports or variables (compiler enforced)

<!-- SECTION: patterns -->
## Common Patterns

- Functional options: `func WithTimeout(d time.Duration) Option`
- Constructor: `func NewService(opts ...Option) *Service`
- Repository pattern: interface for data access, struct implements
- Middleware chain: compose handlers via wrapping
- Config from environment: `os.Getenv` or `viper` for complex config
- Graceful shutdown: `signal.NotifyContext` + `errgroup`
