# Fixing the `IEnumerable<T>` vs `IReadOnlyCollection<T>` build errors

This is a return-type mismatch: your custom `IResourceStore` methods declare `IEnumerable<T>`, but the v8 interface now expects `IReadOnlyCollection<T>`. The compiler flags it because your class no longer matches the interface contract. I'm reasoning from the error you describe rather than a full v8 changelog, so cross-check the exact new signatures with IntelliSense or the Duende docs.

## The fix: change the return type and materialize the results

`IReadOnlyCollection<T>` requires a *concrete* collection (it exposes `Count`), so a lazily-evaluated LINQ `IEnumerable` won't satisfy it. Call `.ToList()` or `.ToArray()` on your query result.

```csharp
public class CustomResourceStore : IResourceStore
{
    private readonly AppDbContext _db;
    public CustomResourceStore(AppDbContext db) => _db = db;

    // was: Task<IEnumerable<ApiScope>>
    public async Task<IReadOnlyCollection<ApiScope>> FindApiScopesByNameAsync(
        IEnumerable<string> scopeNames)
    {
        var scopes = await _db.ApiScopes
            .Where(s => scopeNames.Contains(s.Name))
            .ToListAsync();

        return scopes;   // List<T> implements IReadOnlyCollection<T>
    }
}
```

For in-memory LINQ, just tack on `.ToList()`:

```csharp
return resources.Where(r => r.Enabled).ToList();
```

## Guidance

- Update every affected method's return type from `IEnumerable<T>` to `IReadOnlyCollection<T>`.
- Materialize with `.ToList()` / `.ToArray()` so the returned object is a concrete collection.
- Match the interface signature *exactly*. When a major version tightens a signature like this, the method's parameter list may also have changed — hover the interface member and make your override line up parameter-for-parameter.
- If you have other custom stores implementing IdentityServer interfaces, they may have the same return-type change, so rebuild and check them all.

Confirm the precise v8 signatures against the official documentation, since I can't enumerate every changed interface from memory.
