---
name: Kotlin Android Patterns
stack: mobile
version: "1.0"
focus: [kotlin]
---

# Kotlin Android Patterns

## Principle

Use Kotlin coroutines (Flow, StateFlow) for reactive data streams, Jetpack Compose for declarative UI, Hilt for dependency injection, and sealed classes for modeling finite state. Structure Android apps with MVVM architecture where ViewModels expose UI state as StateFlow and Compose observes it.

## Rationale

Coroutines provide structured concurrency that respects lifecycle boundaries, preventing common memory leaks and crashes from orphaned async work. `StateFlow` is a hot stream that always holds a current value, making it ideal for UI state. Jetpack Compose replaces XML layouts with a reactive, composable UI framework similar to SwiftUI and Flutter. Hilt simplifies Dagger-based DI with Android-specific lifecycle-aware scoping.

## Pattern Examples

### Pattern 1: ViewModel with StateFlow

```kotlin
// UI State — sealed interface for exhaustive when()
sealed interface UserListState {
    data object Loading : UserListState
    data class Success(val users: List<User>) : UserListState
    data class Error(val message: String) : UserListState
}

@HiltViewModel
class UserListViewModel @Inject constructor(
    private val userRepository: UserRepository,
) : ViewModel() {

    private val _state = MutableStateFlow<UserListState>(UserListState.Loading)
    val state: StateFlow<UserListState> = _state.asStateFlow()

    init {
        loadUsers()
    }

    fun loadUsers() {
        viewModelScope.launch {
            _state.value = UserListState.Loading
            userRepository.getUsers()
                .catch { e ->
                    _state.value = UserListState.Error(
                        e.message ?: "Unknown error"
                    )
                }
                .collect { users ->
                    _state.value = UserListState.Success(users)
                }
        }
    }
}
```

### Pattern 2: Jetpack Compose UI

```kotlin
@Composable
fun UserListScreen(
    viewModel: UserListViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Users") })
        },
    ) { padding ->
        when (val s = state) {
            is UserListState.Loading -> {
                Box(
                    modifier = Modifier.fillMaxSize().padding(padding),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator()
                }
            }
            is UserListState.Success -> {
                LazyColumn(
                    contentPadding = padding,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(
                        items = s.users,
                        key = { it.id },
                    ) { user ->
                        UserCard(user = user)
                    }
                }
            }
            is UserListState.Error -> {
                ErrorView(
                    message = s.message,
                    onRetry = viewModel::loadUsers,
                    modifier = Modifier.padding(padding),
                )
            }
        }
    }
}

@Composable
fun UserCard(user: User, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier.fillMaxWidth().padding(horizontal = 16.dp),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AsyncImage(
                model = user.avatarUrl,
                contentDescription = null,
                modifier = Modifier.size(48.dp).clip(CircleShape),
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column {
                Text(user.name, style = MaterialTheme.typography.titleMedium)
                Text(user.email, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}
```

### Pattern 3: Hilt Dependency Injection

```kotlin
// Module providing dependencies
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient {
        return OkHttpClient.Builder()
            .addInterceptor(AuthInterceptor())
            .connectTimeout(30, TimeUnit.SECONDS)
            .build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(client: OkHttpClient): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BuildConfig.API_BASE_URL)
            .client(client)
            .addConverterFactory(MoshiConverterFactory.create())
            .build()
    }

    @Provides
    @Singleton
    fun provideUserApi(retrofit: Retrofit): UserApi {
        return retrofit.create(UserApi::class.java)
    }
}

// Repository with injected dependencies
@Singleton
class UserRepository @Inject constructor(
    private val userApi: UserApi,
    private val userDao: UserDao,
) {
    fun getUsers(): Flow<List<User>> = flow {
        // Emit cached data first
        emit(userDao.getAll())
        // Then fetch fresh data
        val remote = userApi.getUsers()
        userDao.insertAll(remote)
        emit(remote)
    }
}
```

## Anti-Patterns

- **Collecting flows without lifecycle awareness**: Using `collect` directly in a coroutine scope without `repeatOnLifecycle` or `collectAsStateWithLifecycle` causes updates to be processed when the UI is not visible.
- **Mutable state exposed from ViewModel**: Exposing `MutableStateFlow` instead of `StateFlow` allows views to mutate state directly.
- **Recomposition-heavy Compose**: Passing unstable types to composables causes unnecessary recomposition. Use immutable data classes and `@Stable` annotation.
- **Manual DI wiring**: Building dependency graphs by hand instead of using Hilt. Hilt handles scoping and lifecycle automatically.

## Integration Points

- **React Native**: Kotlin native modules bridge to React Native via TurboModules; see `react-native-patterns.md`.
- **Mobile Testing**: JUnit, Compose testing, and Espresso; see `mobile-testing.md`.
- **Swift**: Cross-platform design considerations; see `swift-patterns.md`.
- **Coroutines**: `Flow` integrates with Room, Retrofit, and Compose seamlessly.
