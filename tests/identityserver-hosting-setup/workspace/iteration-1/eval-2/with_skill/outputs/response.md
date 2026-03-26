# Fixing the IdentityServer Middleware Pipeline

## What's Wrong

Your current pipeline order has multiple problems:

```csharp
// ❌ CURRENT (WRONG)
app.UseIdentityServer();    // 1 — too early, before routing
app.UseRouting();           // 2 — must be before IdentityServer
app.UseAuthentication();    // 3 — redundant
app.UseAuthorization();     // 4 — correct position
```

### Issues:

1. **`UseRouting()` must come before `UseIdentityServer()`** — IdentityServer relies on routing to match its endpoints (discovery, token, authorize, etc.). Without routing first, IdentityServer's endpoints won't be reachable.

2. **`UseAuthentication()` is redundant** — `UseIdentityServer()` already calls `UseAuthentication()` internally. Having both won't cause an error, but it's unnecessary and confusing.

3. **`UseIdentityServer()` is too early** — It should come after routing but before authorization.

## Correct Pipeline Order

```csharp
var app = builder.Build();

app.UseStaticFiles();       // 1 — static files first
app.UseRouting();           // 2 — routing before IdentityServer
app.UseIdentityServer();   // 3 — includes UseAuthentication() internally
app.UseAuthorization();    // 4 — required, must not be omitted
app.MapDefaultControllerRoute();  // 5 — UI framework endpoints
```

### Pipeline Rules

| Order | Middleware | Notes |
|-------|-----------|-------|
| 1 | `UseStaticFiles()` | Before IdentityServer |
| 2 | `UseRouting()` | **Before** IdentityServer |
| 3 | `UseIdentityServer()` | Includes `UseAuthentication()` internally |
| 4 | `UseAuthorization()` | **After** IdentityServer — must not be omitted |
| 5 | `MapDefaultControllerRoute()` | UI framework endpoints |

### Why `UseAuthorization()` Must Not Be Omitted

Even though it might seem optional, `UseAuthorization()` is **required** by the Duende UI template. The login, logout, consent, and error pages use authorization attributes, and omitting this middleware will cause authorization failures in those UI pages.

### Why `UseAuthentication()` Is Redundant

`UseIdentityServer()` internally calls `UseAuthentication()` as part of its middleware setup. Adding a separate `UseAuthentication()` call is unnecessary. While it won't break anything, it should be removed to avoid confusion.
