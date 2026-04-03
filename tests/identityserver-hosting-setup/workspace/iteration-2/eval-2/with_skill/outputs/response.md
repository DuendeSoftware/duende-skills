# Fix IdentityServer Middleware Pipeline

## Current (Wrong) Order
```
UseIdentityServer -> UseRouting -> UseAuthentication -> UseAuthorization
```

## Problems

1. **`UseRouting()` must come before `UseIdentityServer()`**. IdentityServer depends on routing to match its endpoints. Without routing first, IdentityServer cannot process requests correctly.

2. **`UseAuthentication()` is redundant**. `UseIdentityServer()` already calls `UseAuthentication()` internally. Having both is unnecessary (not harmful, but redundant).

3. **`UseAuthorization()` must not be omitted** — it is required by the Duende UI template for authorization checks on UI pages.

## Correct Order

```csharp
app.UseStaticFiles();       // 1. Static files first
app.UseRouting();            // 2. Routing before IdentityServer
app.UseIdentityServer();     // 3. IdentityServer (includes UseAuthentication internally)
app.UseAuthorization();      // 4. Authorization after IdentityServer — must not be omitted
```

Remove `UseAuthentication()` since `UseIdentityServer()` includes it. The correct pipeline is:
- `UseStaticFiles` → `UseRouting` → `UseIdentityServer` → `UseAuthorization`
