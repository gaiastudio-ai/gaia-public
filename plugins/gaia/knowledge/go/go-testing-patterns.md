# Go Testing Patterns

<!-- SECTION: unit-tests -->
## Unit Testing

- Test files: `*_test.go` in same package
- Test functions: `func TestXxx(t *testing.T)`
- Table-driven tests: slice of test cases with name, input, expected
- `t.Run(name, func(t *testing.T) { ... })` for subtests
- `t.Parallel()` for concurrent test execution
- `t.Helper()` in helper functions for correct line reporting
- `t.Cleanup(func())` for teardown

<!-- SECTION: mocking -->
## Mocking & Interfaces

- Define interfaces at the consumer, not the provider
- Mock by implementing the interface in test file
- `gomock` / `mockgen` for generated mocks
- `testify/mock` for assertion-style mocking
- Dependency injection via constructor: `func NewService(repo Repository) *Service`

<!-- SECTION: integration -->
## Integration Testing

- Build tags: `//go:build integration` to separate from unit tests
- `testcontainers-go` for database/service containers
- `httptest.NewServer` for HTTP integration tests
- `httptest.NewRecorder` for handler testing without server
- Setup/teardown with `TestMain(m *testing.M)`

<!-- SECTION: benchmarks -->
## Benchmarks & Fuzzing

- Benchmark functions: `func BenchmarkXxx(b *testing.B)` with `b.N` loop
- `b.ReportAllocs()` for allocation tracking
- Fuzz testing: `func FuzzXxx(f *testing.F)` with `f.Add()` seeds
- `go test -bench=. -benchmem` for memory profiling
- `go test -race` for race condition detection
