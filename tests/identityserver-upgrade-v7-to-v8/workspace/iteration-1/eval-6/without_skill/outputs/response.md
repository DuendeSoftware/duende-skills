# Fixing IEnumerable<T> vs IReadOnlyCollection<T> Build Errors

If IdentityServer v8 changed interface return types from `IEnumerable<T>` to `IReadOnlyCollection<T>`, here's how to fix the compilation errors:

## The Fix

Change your method return types to match the new interface and ensure your return values implement `IReadOnlyCollection<T>`:

```csharp
// ❌ Before
public async Task<IEnumerable<ApiScope>> FindApiScopesByNameAsync(IEnumerable<string> scopeNames)
{
    return await _db.ApiScopes
        .Where(s => scopeNames.Contains(s.Name))
        .ToListAsync();
}

// ✅ After
public async Task<IReadOnlyCollection<ApiScope>> FindApiScopesByNameAsync(IEnumerable<string> scopeNames)
{
    return await _db.ApiScopes
        .Where(s => scopeNames.Contains(s.Name))
        .ToListAsync();
}
```

Since `List<T>` implements `IReadOnlyCollection<T>`, if you're already using `.ToListAsync()` or `.ToList()`, you just need to update the return type declaration. If you're using deferred LINQ (e.g., returning a `.Where()` without materializing), you'll need to add `.ToList()` or `.ToArray()`:

```csharp
// If using deferred execution, materialize:
return scopeNames.Select(s => MapToScope(s)).ToList();
// or
return results.ToArray();
```

## Affected Methods

Check all your store implementations — this likely affects multiple methods across `IResourceStore` and potentially other store interfaces. Update each return type from `IEnumerable<T>` to `IReadOnlyCollection<T>`.
