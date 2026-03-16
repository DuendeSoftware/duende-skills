# Fixing the IdentityServer Middleware Pipeline

Your current middleware order has some issues. Let me walk through them:

## Issue 1: UseRouting Should Come First

In ASP.NET Core, `UseRouting()` should generally come before authentication and authorization middleware. Your current order places `UseIdentityServer()` before `UseRouting()`, which means IdentityServer endpoints won't be matched correctly.

## Issue 2: Middleware Ordering

The standard ASP.NET Core middleware pipeline should follow this pattern:

```csharp
var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();
```

## Correct Pipeline

The general rule for ASP.NET Core middleware is:
1. `UseRouting()` - sets up endpoint routing
2. `UseAuthentication()` - authenticates the user
3. `UseIdentityServer()` - IdentityServer endpoints
4. `UseAuthorization()` - authorizes the user

Make sure routing comes first so that endpoint metadata is available for subsequent middleware.
