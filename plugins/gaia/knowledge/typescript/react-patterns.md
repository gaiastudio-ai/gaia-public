---
name: React Component Patterns
stack: typescript
version: "1.0"
focus: [react]
---

# React Component Patterns

## Principle

Build UIs with functional components and hooks. Use `useState` for local state, `useEffect` for side effects with proper dependency arrays, `useCallback`/`useMemo` for referential stability and expensive computations, and Context for dependency injection of shared services. Compose complex components from simple, focused building blocks.

## Rationale

React's rendering model re-creates component output on every state change. Understanding when React re-renders and how to prevent unnecessary work is crucial for performance. Hooks provide a composable primitive that replaces class lifecycle methods with a more declarative API. Custom hooks extract and share stateful logic without render props or HOCs. Context avoids prop drilling but should not replace purpose-built state management for frequently changing data.

## Pattern Examples

### Pattern 1: Custom Hook for Data Fetching

```typescript
interface UseQueryResult<T> {
  data: T | undefined;
  error: Error | null;
  isLoading: boolean;
  refetch: () => void;
}

function useQuery<T>(url: string): UseQueryResult<T> {
  const [data, setData] = useState<T>();
  const [error, setError] = useState<Error | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const fetchData = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const json = await response.json();
      setData(json);
    } catch (err) {
      setError(err instanceof Error ? err : new Error(String(err)));
    } finally {
      setIsLoading(false);
    }
  }, [url]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  return { data, error, isLoading, refetch: fetchData };
}

// Usage
function UserList() {
  const { data: users, isLoading, error } = useQuery<User[]>('/api/users');
  if (isLoading) return <Spinner />;
  if (error) return <ErrorMessage error={error} />;
  return <ul>{users?.map(u => <UserCard key={u.id} user={u} />)}</ul>;
}
```

### Pattern 2: Compound Components with Context

```typescript
interface TabsContextValue {
  activeTab: string;
  setActiveTab: (id: string) => void;
}

const TabsContext = createContext<TabsContextValue | null>(null);

function useTabs(): TabsContextValue {
  const context = useContext(TabsContext);
  if (!context) throw new Error('useTabs must be used within <Tabs>');
  return context;
}

function Tabs({ defaultTab, children }: { defaultTab: string; children: ReactNode }) {
  const [activeTab, setActiveTab] = useState(defaultTab);
  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      <div role="tablist">{children}</div>
    </TabsContext.Provider>
  );
}

function TabTrigger({ id, children }: { id: string; children: ReactNode }) {
  const { activeTab, setActiveTab } = useTabs();
  return (
    <button
      role="tab"
      aria-selected={activeTab === id}
      onClick={() => setActiveTab(id)}
    >
      {children}
    </button>
  );
}

function TabContent({ id, children }: { id: string; children: ReactNode }) {
  const { activeTab } = useTabs();
  if (activeTab !== id) return null;
  return <div role="tabpanel">{children}</div>;
}

// Usage
// <Tabs defaultTab="profile">
//   <TabTrigger id="profile">Profile</TabTrigger>
//   <TabTrigger id="settings">Settings</TabTrigger>
//   <TabContent id="profile"><ProfileForm /></TabContent>
//   <TabContent id="settings"><SettingsForm /></TabContent>
// </Tabs>
```

### Pattern 3: Performance with useMemo and useCallback

```typescript
interface DataTableProps {
  rows: DataRow[];
  filter: string;
  onRowClick: (row: DataRow) => void;
}

function DataTable({ rows, filter, onRowClick }: DataTableProps) {
  // Expensive filtering — memoize so it only recomputes when inputs change
  const filteredRows = useMemo(
    () => rows.filter(r => r.name.toLowerCase().includes(filter.toLowerCase())),
    [rows, filter]
  );

  // Stable callback reference for child components
  const handleRowClick = useCallback(
    (row: DataRow) => { onRowClick(row); },
    [onRowClick]
  );

  return (
    <table>
      <tbody>
        {filteredRows.map(row => (
          <MemoizedRow key={row.id} row={row} onClick={handleRowClick} />
        ))}
      </tbody>
    </table>
  );
}

const MemoizedRow = memo(function Row({
  row, onClick,
}: { row: DataRow; onClick: (row: DataRow) => void }) {
  return (
    <tr onClick={() => onClick(row)}>
      <td>{row.name}</td>
      <td>{row.value}</td>
    </tr>
  );
});
```

## Anti-Patterns

- **useEffect as onChange handler**: Using `useEffect` to respond to state changes that should be handled in the event handler itself.
- **Missing dependency array**: Omitting the dependency array in `useEffect` causes it to run on every render.
- **Context for high-frequency updates**: Putting rapidly changing state (mouse position, animations) in Context re-renders all consumers.
- **Premature memoization**: Wrapping everything in `useMemo`/`useCallback` adds complexity. Only memoize when profiling shows a bottleneck.

## Integration Points

- **Next.js**: React components are used in both server and client contexts; see `nextjs-patterns.md`.
- **Express**: React apps consume Express APIs; see `express-patterns.md` for API design.
- **TypeScript**: Strict typing enhances React component props; see `ts-conventions.md`.
- **Testing**: Use React Testing Library for component tests; test custom hooks with `renderHook`.
