# Validating reference tokens via OAuth 2.0 token introspection

Because reference tokens are opaque strings (RFC 7662), the API can't validate them locally. It must call the authorization server's **introspection endpoint** to check whether the token is active and retrieve its claims.

## 1. Add an introspection handler package

The Duende/IdentityModel introspection handler is the common choice:

```bash
dotnet add package Duende.AspNetCore.Authentication.OAuth2Introspection
```

(The older equivalent is `IdentityModel.AspNetCore.OAuth2Introspection`.)

## 2. Configure it in `Program.cs`

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("Bearer")
    .AddOAuth2Introspection("Bearer", options =>
    {
        options.Authority = "https://auth.mycompany.com";

        // Credentials the API uses to call the introspection endpoint
        options.ClientId = "invoicing";
        options.ClientSecret = "invoicing_secret";

        // Optional: cache introspection results to avoid a round-trip per request
        options.EnableCaching = true;
        options.CacheDuration = TimeSpan.FromMinutes(5);
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

> If you enable caching you also need to register a cache, e.g. `builder.Services.AddDistributedMemoryCache();`.

## How it maps to IdentityServer

- `Authority` points at your IdentityServer so the handler can discover the introspection endpoint.
- `ClientId` / `ClientSecret` are the API resource's credentials. IdentityServer authenticates the introspection request with these, so the corresponding API resource must have a matching secret configured on its side. Make sure the secret you configure here matches what's registered for the `invoicing` resource in IdentityServer, otherwise introspection calls will be rejected.

Once configured, the handler transparently introspects each incoming reference token and populates the `ClaimsPrincipal` from the response.
