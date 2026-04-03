# Fix Middleware Pipeline

## Current Order (Wrong)
```
UseIdentityServer -> UseRouting -> UseAuthentication -> UseAuthorization
```

## Issues

The main issue is that `UseRouting()` should come before `UseIdentityServer()`. The routing middleware needs to run first so that endpoints are matched before IdentityServer processes them.

## Correct Order

```csharp
app.UseRouting();
app.UseAuthentication();
app.UseIdentityServer();
app.UseAuthorization();
```

This ensures routing runs first, then authentication, then IdentityServer, then authorization.
