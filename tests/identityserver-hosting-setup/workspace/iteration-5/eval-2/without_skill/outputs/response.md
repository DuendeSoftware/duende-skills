# Fixing the Middleware Pipeline Order

Your current order is:

```csharp
app.UseIdentityServer();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
```

## What's wrong

**`UseRouting()` is in the wrong place.** In ASP.NET Core the middleware pipeline runs top to bottom, and routing needs to be established before authentication/authorization and before IdentityServer's endpoints are matched. Having `UseIdentityServer()` before `UseRouting()` is incorrect — routing must come first.

Also worth noting: `UseIdentityServer()` internally wires up the authentication middleware, so an explicit `UseAuthentication()` call right after it is generally redundant. It won't break anything, but you can remove it.

## Correct order

```csharp
app.UseRouting();
app.UseAuthentication();   // optional — UseIdentityServer already sets this up
app.UseIdentityServer();
app.UseAuthorization();

app.MapControllers();
```

A clean, minimal version:

```csharp
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
```

The key rule is: **`UseRouting()` → `UseIdentityServer()` → `UseAuthorization()`**. Routing first so endpoints resolve, then IdentityServer, then authorization.
