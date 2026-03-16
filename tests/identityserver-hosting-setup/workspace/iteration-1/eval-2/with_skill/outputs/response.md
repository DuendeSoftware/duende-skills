# Fixing the IdentityServer Middleware Pipeline

Your current pipeline has two issues:

## Problem 1: `UseRouting()` Must Come Before `UseIdentityServer()`

Your current order has `UseIdentityServer()` before `UseRouting()`. This is incorrect. `UseRouting()` must come first because IdentityServer needs the routing system to be initialized to match its endpoints.

## Problem 2: `UseAuthentication()` Is Redundant

`UseIdentityServer()` already calls `UseAuthentication()` internally. Having both is unnecessary (though not harmful). You should remove the explicit `UseAuthentication()` call.

## Problem 3: Don't Omit `UseAuthorization()`

`UseAuthorization()` must not be omitted as it is required by the Duende UI template for authorization on login, consent, and other UI pages.

## Correct Pipeline Order

```csharp
var app = builder.Build();

app.UseStaticFiles();       // 1. Static files first
app.UseRouting();           // 2. Routing before IdentityServer
app.UseIdentityServer();    // 3. IdentityServer (includes UseAuthentication internally)
app.UseAuthorization();     // 4. Authorization after IdentityServer - must not be omitted

app.MapDefaultControllerRoute();
```

### Why This Order Matters

| Order | Middleware | Notes |
|-------|-----------|-------|
| 1 | `UseStaticFiles()` | Before IdentityServer |
| 2 | `UseRouting()` | Before IdentityServer |
| 3 | `UseIdentityServer()` | Includes `UseAuthentication()` internally |
| 4 | `UseAuthorization()` | Required after IdentityServer, must not be omitted |
| 5 | `MapDefaultControllerRoute()` | UI framework endpoints |

### What You Had vs. What's Correct

```csharp
// ❌ Your current (wrong) order:
app.UseIdentityServer();    // Too early - routing not set up yet
app.UseRouting();           // Should be before IdentityServer
app.UseAuthentication();    // Redundant - UseIdentityServer includes this
app.UseAuthorization();

// ✅ Correct order:
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();    // Already calls UseAuthentication()
app.UseAuthorization();     // Required for Duende UI template
```
