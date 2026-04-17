# Go Standard Library Patterns

<!-- SECTION: http-server -->
## HTTP Server Patterns

- Use `http.ServeMux` for simple routing, Gin/Fiber for complex APIs
- `http.Handler` interface: implement `ServeHTTP(w http.ResponseWriter, r *http.Request)`
- Middleware pattern: `func(next http.Handler) http.Handler`
- Context propagation: always pass `context.Context` through request chain
- Graceful shutdown: `server.Shutdown(ctx)` with signal handling

<!-- SECTION: concurrency -->
## Concurrency Patterns

- Goroutines for concurrent work, channels for communication
- `sync.WaitGroup` for waiting on multiple goroutines
- `sync.Mutex` / `sync.RWMutex` for shared state protection
- `context.Context` for cancellation and timeouts
- Worker pool pattern: buffered channel + N goroutines
- Fan-out/fan-in for parallel processing pipelines
- Never start a goroutine without knowing how it will stop

<!-- SECTION: error-handling -->
## Error Handling

- Errors are values — wrap with `fmt.Errorf("context: %w", err)`
- Custom error types implement `error` interface
- Use `errors.Is()` and `errors.As()` for error inspection
- Sentinel errors for expected conditions: `var ErrNotFound = errors.New("not found")`
- Never ignore errors — handle or propagate explicitly

<!-- SECTION: io -->
## I/O Patterns

- `io.Reader` / `io.Writer` interfaces for streaming
- `bufio` for buffered I/O
- `os.OpenFile` with explicit permissions
- `defer file.Close()` immediately after open
- `encoding/json` for JSON marshal/unmarshal with struct tags
