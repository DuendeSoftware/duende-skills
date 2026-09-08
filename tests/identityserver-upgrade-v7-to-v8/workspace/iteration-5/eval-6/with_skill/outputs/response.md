# Fixing `IEnumerable<T>` → `IReadOnlyCollection<T>` in `IResourceStore`

In v8, nine store/service interfaces changed their async return types from `IEnumerable<T>` to **`IReadOnlyCollection<T>`**, and the same methods also gained a `CancellationToken`. `IResourceStore` is one of them, which is why your implementation no longer matches the interface. Fix it by changing the return types and materializing your LINQ results.

## What changed

```csharp
// ❌ Before (v7)
public Task<IEnumerable<ApiScope>> FindApiScopesByNameAsync(IEnumerable<string> scopeNames)

// ✅ After (v8)
public Task<IReadOnlyCollection<ApiScope>> FindApiScopesByNameAsync(
    IEnumerable<string> scopeNames, CancellationToken ct)
```

## How to fix your implementation

For each affected method: update the return type to `IReadOnlyCollection<T>`, add `CancellationToken ct` as the last parameter, and call `.ToList()` (or `.ToArray()`) on your query so a lazy `IEnumerable` becomes a concrete collection that satisfies `IReadOnlyCollection<T>`.

```csharp
public class CustomResourceStore : IResourceStore
{
    private readonly AppDbContext _db;
    public CustomResourceStore(AppDbContext db) => _db = db;

    public async Task<IReadOnlyCollection<ApiScope>> FindApiScopesByNameAsync(
        IEnumerable<string> scopeNames, CancellationToken ct)
    {
        // materialize the query — IReadOnlyCollection needs a concrete collection
        return await _db.ApiScopes
            .Where(s => scopeNames.Contains(s.Name))
            .ToListAsync(ct);
    }

    public async Task<IReadOnlyCollection<ApiResource>> FindApiResourcesByNameAsync(
        IEnumerable<string> names, CancellationToken ct)
    {
        return await _db.ApiResources
            .Where(r => names.Contains(r.Name))
            .ToListAsync(ct);
    }

    // ...apply the same pattern to the remaining IResourceStore methods...
}
```

Where you have in-memory LINQ rather than EF, just append `.ToList()` / `.ToArray()`:

```csharp
return resources.Where(r => r.Enabled).ToList();
```

## Key points

- **Return `IReadOnlyCollection<T>`** instead of `IEnumerable<T>` on the affected methods.
- **Materialize** results with `.ToList()` / `.ToArray()` (or EF's `.ToListAsync(ct)`) — a deferred `IEnumerable` won't satisfy the new signature.
- **Add `CancellationToken ct`** to each method's parameter list and propagate it into the query.
- **This isn't limited to `IResourceStore`.** The same `IEnumerable<T>` → `IReadOnlyCollection<T>` change hit multiple interfaces in v8 (nine in total), so check your other custom stores/services and apply the identical fix.
