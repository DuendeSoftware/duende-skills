# Fixing the IdentityServer Middleware Pipeline

Your current order is:

```csharp
app.UseIdentityServer();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
```

There are two problems.

## Problem 1: `UseRouting()` is after `UseIdentityServer()`

Routing must be established **before** IdentityServer runs so that endpoints can be resolved. `UseIdentityServer()` (and the endpoint routing it depends on) needs `UseRouting()` to have already run. Having `UseIdentityServer()` first is incorrect.

## Problem 2: `UseAuthentication()` is redundant

`UseIdentityServer()` **already calls `UseAuthentication()` internally**. Adding a separate `UseAuthentication()` call is unnecessary (it is not harmful, just redundant) and should be removed to avoid confusion.

## Correct order

```csharp
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();   // includes UseAuthentication() internally
app.UseAuthorization();

app.MapDefaultControllerRoute();
```

| Order | Middleware              | Notes                                              |
| ----- | ----------------------- | -------------------------------------------------- |
| 1     | `UseStaticFiles()`      | Before IdentityServer                              |
| 2     | `UseRouting()`          | Before IdentityServer                              |
| 3     | `UseIdentityServer()`   | Includes `UseAuthentication()` internally          |
| 4     | `UseAuthorization()`    | Required after IdentityServer, must not be omitted |

## Important: keep `UseAuthorization()`

Do **not** drop `UseAuthorization()`. It is **required by the Duende UI template** — the login/consent/logout pages rely on authorization middleware, and omitting it causes authorization failures in the UI pages. So the fix is to reorder (routing before IdentityServer) and remove the redundant `UseAuthentication()`, while keeping `UseAuthorization()` in place after `UseIdentityServer()`.
