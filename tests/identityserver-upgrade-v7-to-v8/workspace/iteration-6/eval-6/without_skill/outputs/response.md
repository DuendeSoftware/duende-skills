# `IEnumerable<T>` vs `IReadOnlyCollection<T>` in `IResourceStore`

In v8 some store methods appear to return `IReadOnlyCollection<T>` instead of `IEnumerable<T>`. This gives callers a known `Count` and signals that results are materialized. Your implementation must match the new return types exactly.

Typical fix:

```csharp
// v7
public Task<IEnumerable<ApiScope>> FindApiScopesByNameAsync(IEnumerable<string> scopeNames) { ... }

// v8
public async Task<IReadOnlyCollection<ApiScope>> FindApiScopesByNameAsync(IEnumerable<string> scopeNames)
{
    return await _db.ApiScopes
        .Where(s => scopeNames.Contains(s.Name))
        .ToListAsync();   // List<T> implements IReadOnlyCollection<T>
}
```
Do the same for `FindIdentityResourcesByScopeNameAsync`, `FindApiResourcesByScopeNameAsync`, `FindApiResourcesByNameAsync` and any other `IResourceStore` members the compiler flags. Always materialize with `.ToList()`/`.ToArray()` and don't return a deferred query. `Resources GetAllResourcesAsync()` is likely unchanged. Also check that any wrapper or decorator stores use the same types.

Rely on the compiler errors for the definitive list, since I can't confirm every signature.
