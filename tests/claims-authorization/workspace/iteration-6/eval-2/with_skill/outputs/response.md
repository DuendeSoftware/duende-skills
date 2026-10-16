# `User.FindFirst("sub")` is null

The claim is in the token, but the JWT bearer handler **renames inbound claims** by default. `sub` becomes `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`, `name` and `role` are remapped too, so `FindFirst("sub")` finds nothing.

## Fix: `MapInboundClaims = false`
```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "my_api";
        options.MapInboundClaims = false;   // keep "sub", not the long URI
        options.TokenValidationParameters.NameClaimType = JwtClaimTypes.Name;
        options.TokenValidationParameters.RoleClaimType = JwtClaimTypes.Role;
    });
```
Now `User.FindFirst(JwtClaimTypes.Subject)` works. Setting `NameClaimType`/`RoleClaimType` keeps `User.Identity.Name` and `[Authorize(Roles = ...)]` working, since the defaults point at the long Microsoft types.

Same for a web app OIDC handler: `options.MapInboundClaims = false;`.

## Quick check
```csharp
foreach (var c in User.Claims) logger.LogInformation("{Type} = {Value}", c.Type, c.Value);
```
Before the fix you'll see the long URIs.

## Alternative (not recommended)
Look up `ClaimTypes.NameIdentifier`, but that couples code to Microsoft names; use short `JwtClaimTypes` constants (`sub`, `name`, `email`, `role`) consistently instead.
