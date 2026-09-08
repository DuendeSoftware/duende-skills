# Validating reference (opaque) tokens with introspection

Reference tokens are opaque identifiers, not JWTs, so the API cannot verify them by signature. Instead it calls IdentityServer's **introspection endpoint** to ask whether the token is active and what claims it carries. This is what the Duende OAuth2 introspection handler does.

## 1. Add the introspection package

Either the Duende access-token-validation meta-package:

```bash
dotnet add package Duende.IdentityServer.AccessTokenValidation
```

...or the introspection handler directly:

```bash
dotnet add package Duende.AspNetCore.Authentication.OAuth2Introspection
```

## 2. Configure introspection in `Program.cs`

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("introspection")
    .AddOAuth2Introspection("introspection", options =>
    {
        options.Authority = "https://auth.mycompany.com";

        // The API authenticates to the introspection endpoint using the
        // ApiResource name + secret configured in IdentityServer.
        options.ClientId = "invoicing";
        options.ClientSecret = "invoicing_secret";
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

`ClientId`/`ClientSecret` are the credentials the API presents to the introspection endpoint. They map to the **`ApiResource` name and one of its `ApiSecrets`** in IdentityServer.

## 3. IMPORTANT — configure ApiSecrets on the ApiResource

Introspection **only works if the `ApiResource` has an `ApiSecrets` entry** matching the secret above. Without it, the introspection call is unauthenticated and IdentityServer rejects it — you'll get `401`s at the API with no obvious cause.

```csharp
// IdentityServer configuration
var invoicing = new ApiResource("invoicing")
{
    ApiSecrets = { new Secret("invoicing_secret".Sha256()) },
    Scopes = { "invoicing.read", "invoicing.write" }
};
```

## Trade-offs to keep in mind

- Introspection makes a network call to IdentityServer on (cache-miss) validation, so IdentityServer must be reachable and the added latency is real. The handler caches results, but caching means revocation isn't perfectly instantaneous unless you tune it.
- Reference tokens **can be revoked immediately** at IdentityServer — that's their main advantage over JWTs.
