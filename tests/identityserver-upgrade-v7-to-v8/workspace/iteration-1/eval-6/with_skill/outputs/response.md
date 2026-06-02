# Fixing IEnumerable<T> → IReadOnlyCollection<T> in Custom IResourceStore

In IdentityServer v8, nine interfaces changed their return types from `IEnumerable<T>` to `IReadOnlyCollection<T>`. You also need to add `CancellationToken` parameters.

## Fix

```csharp
// ❌ Before (v7)
public class CustomResourceStore : IResourceStore
{
    public async Task<IEnumerable<ApiScope>> FindApiScopesByNameAsync(IEnumerable<string> scopeNames)
    {
        return await _db.ApiScopes
            .Where(s => scopeNames.Contains(s.Name))
            .ToListAsync();
    }

    public async Task<IEnumerable<ApiResource>> FindApiResourcesByScopeNameAsync(IEnumerable<string> scopeNames)
    {
        return await _db.ApiResources
            .Where(r => r.Scopes.Any(s => scopeNames.Contains(s)))
            .ToListAsync();
    }

    public async Task<IEnumerable<IdentityResource>> FindIdentityResourcesByScopeNameAsync(IEnumerable<string> scopeNames)
    {
        return await _db.IdentityResources
            .Where(r => scopeNames.Contains(r.Name))
            .ToListAsync();
    }
}

// ✅ After (v8) — IReadOnlyCollection<T> + CancellationToken
public class CustomResourceStore : IResourceStore
{
    public async Task<IReadOnlyCollection<ApiScope>> FindApiScopesByNameAsync(
        IEnumerable<string> scopeNames, CancellationToken ct)
    {
        return await _db.ApiScopes
            .Where(s => scopeNames.Contains(s.Name))
            .ToListAsync(ct);
    }

    public async Task<IReadOnlyCollection<ApiResource>> FindApiResourcesByScopeNameAsync(
        IEnumerable<string> scopeNames, CancellationToken ct)
    {
        return await _db.ApiResources
            .Where(r => r.Scopes.Any(s => scopeNames.Contains(s)))
            .ToListAsync(ct);
    }

    public async Task<IReadOnlyCollection<IdentityResource>> FindIdentityResourcesByScopeNameAsync(
        IEnumerable<string> scopeNames, CancellationToken ct)
    {
        return await _db.IdentityResources
            .Where(r => scopeNames.Contains(r.Name))
            .ToListAsync(ct);
    }
}
```

## Key Points

1. **Change return types** from `IEnumerable<T>` to `IReadOnlyCollection<T>`
2. **Use `.ToList()` or `.ToArray()`** on LINQ results — both implement `IReadOnlyCollection<T>`
3. **Add `CancellationToken ct`** as the last parameter on all methods
4. This applies to multiple interfaces: `IResourceStore`, `IClientStore`, `IPersistedGrantStore`, `IDeviceFlowStore`, and others

Since `List<T>` and `T[]` both implement `IReadOnlyCollection<T>`, if you're already calling `.ToListAsync()`, your code just needs the return type and parameter signature updates.
