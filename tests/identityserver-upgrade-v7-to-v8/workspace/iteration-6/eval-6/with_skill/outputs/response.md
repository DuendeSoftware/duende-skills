# `IEnumerable<T>` → `IReadOnlyCollection<T>` in `IResourceStore`

In v8, **nine interfaces** changed `IEnumerable<T>` return types to `IReadOnlyCollection<T>`, and **all async methods get a `CancellationToken ct` as the last parameter**. Do both at once in your `IResourceStore`:

```csharp
// ❌ v7
public Task<IEnumerable<ApiScope>> FindApiScopesByNameAsync(IEnumerable<string> scopeNames)

// ✅ v8
public async Task<IReadOnlyCollection<ApiScope>> FindApiScopesByNameAsync(
    IEnumerable<string> scopeNames, CancellationToken ct)
{
    return await _db.ApiScopes
        .Where(s => scopeNames.Contains(s.Name))
        .ToListAsync(ct);   // List<T> implements IReadOnlyCollection<T>
}
```
Apply the same pattern to:
```csharp
Task<IReadOnlyCollection<IdentityResource>> FindIdentityResourcesByScopeNameAsync(IEnumerable<string> scopeNames, CancellationToken ct);
Task<IReadOnlyCollection<ApiResource>> FindApiResourcesByScopeNameAsync(IEnumerable<string> scopeNames, CancellationToken ct);
Task<IReadOnlyCollection<ApiResource>> FindApiResourcesByNameAsync(IEnumerable<string> apiResourceNames, CancellationToken ct);
```
Make sure `GetAllResourcesAsync` also takes `CancellationToken`.

## Tips
- Materialize with `ToListAsync(ct)`/`ToArray()`. Don't return a deferred `IEnumerable`.
- Propagate `ct` to EF calls instead of using `CancellationToken.None`.
- v8 also uses nullable reference types, so check nullable warnings after the build.
- Remember `net10.0` and the 8.x packages.
