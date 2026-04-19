---
name: Swift and SwiftUI Patterns
stack: mobile
version: "1.0"
focus: [swift]
---

# Swift and SwiftUI Patterns

## Principle

Build iOS interfaces with SwiftUI's declarative syntax, use Combine for reactive data flow, apply protocol-oriented programming for flexible abstractions, and manage memory carefully with ARC (Automatic Reference Counting). Prefer value types (structs, enums) over reference types (classes) unless identity semantics are required.

## Rationale

SwiftUI re-renders views when their state changes, similar to React. Views are lightweight structs, not persistent objects, so the framework creates and discards them freely. Combine provides a native reactive pipeline for transforming and combining async data streams. Protocol-oriented programming (POP) avoids the fragile base class problem of inheritance. ARC requires explicit attention to retain cycles, especially in closures and delegate patterns.

## Pattern Examples

### Pattern 1: SwiftUI Views with State Management

```swift
import SwiftUI

// View Model — ObservableObject publishes changes
@MainActor
class UserListViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: UserRepository

    init(repository: UserRepository = .shared) {
        self.repository = repository
    }

    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        do {
            users = try await repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// SwiftUI View — lightweight struct
struct UserListView: View {
    @StateObject private var viewModel = UserListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Error", systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    List(viewModel.users) { user in
                        NavigationLink(value: user) {
                            UserRow(user: user)
                        }
                    }
                }
            }
            .navigationTitle("Users")
            .task { await viewModel.loadUsers() }
            .refreshable { await viewModel.loadUsers() }
        }
    }
}

// Reusable subview
struct UserRow: View {
    let user: User

    var body: some View {
        HStack {
            AsyncImage(url: user.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(.gray.opacity(0.3))
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(user.name).font(.headline)
                Text(user.email).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
```

### Pattern 2: Combine Pipeline

```swift
import Combine

class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [SearchResult] = []

    private var cancellables = Set<AnyCancellable>()
    private let searchService: SearchService

    init(searchService: SearchService) {
        self.searchService = searchService

        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { $0.count >= 2 }
            .flatMap { [weak self] query -> AnyPublisher<[SearchResult], Never> in
                guard let self else { return Just([]).eraseToAnyPublisher() }
                return self.searchService.search(query: query)
                    .catch { _ in Just([]) }
                    .eraseToAnyPublisher()
            }
            .receive(on: RunLoop.main)
            .assign(to: &$results)
    }
}
```

### Pattern 3: Protocol-Oriented Programming

```swift
// Protocol defines the contract
protocol Repository {
    associatedtype Entity: Identifiable
    func fetchAll() async throws -> [Entity]
    func fetchById(_ id: Entity.ID) async throws -> Entity?
    func save(_ entity: Entity) async throws -> Entity
    func delete(_ id: Entity.ID) async throws
}

// Default implementation via protocol extension
extension Repository {
    func fetchOrThrow(_ id: Entity.ID) async throws -> Entity {
        guard let entity = try await fetchById(id) else {
            throw RepositoryError.notFound(String(describing: id))
        }
        return entity
    }
}

// Concrete implementation
struct UserRepository: Repository {
    typealias Entity = User
    private let apiClient: APIClient

    func fetchAll() async throws -> [User] {
        try await apiClient.get("/users")
    }

    func fetchById(_ id: String) async throws -> User? {
        try? await apiClient.get("/users/\(id)")
    }

    func save(_ entity: User) async throws -> User {
        try await apiClient.post("/users", body: entity)
    }

    func delete(_ id: String) async throws {
        try await apiClient.delete("/users/\(id)")
    }
}
```

## Anti-Patterns

- **Retain cycles in closures**: Capturing `self` strongly in escaping closures causes memory leaks. Use `[weak self]` and guard against nil.
- **Massive view bodies**: SwiftUI views with 100+ lines in `body`. Extract subviews as separate structs.
- **Using `@ObservedObject` for owned objects**: `@ObservedObject` does not own its object; use `@StateObject` for objects created by the view.
- **Forcing class inheritance for abstraction**: Use protocols and protocol extensions instead of base classes.

## Integration Points

- **React Native**: Native modules in Swift bridge to React Native; see `react-native-patterns.md`.
- **Mobile Testing**: XCTest and XCUITest for unit and UI testing; see `mobile-testing.md`.
- **Kotlin**: Cross-platform considerations with Kotlin Multiplatform; see `kotlin-patterns.md`.
- **Combine**: Integrates with SwiftUI's `@Published` and async/await via `values` property.
