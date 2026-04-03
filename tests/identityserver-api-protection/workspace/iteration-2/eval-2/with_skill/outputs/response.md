# Configuring Reference Token Introspection

Reference tokens are opaque strings that the API cannot validate locally — it must call the IdentityServer introspection endpoint to verify them.

## 1. Install the Introspection Package

```bash
dotnet add package Duende.AspNetCore.Authentication.OAuth2Introspection
```

Alternatively, you can use the umbrella package:

```bash
dotnet add package Duende.IdentityServer.AccessTokenValidation
```

## 2. Configure Introspection in Program.cs

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("token")
    .AddOAuth2Introspection("token", options =>
    {
        options.Authority = "https://auth.mycompany.com";
        options.ClientId = "invoicing";
        options.ClientSecret = "invoicing_secret";
    });

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.Run();
```

## Important: ApiResource Configuration in IdentityServer

The `ApiResource` on the IdentityServer side **must** have `ApiSecrets` configured for introspection to work. The `ClientId` and `ClientSecret` in the introspection handler correspond to the `ApiResource` name and secret:

```csharp
// On the IdentityServer side
var apiResource = new ApiResource("invoicing")
{
    ApiSecrets = { new Secret("invoicing_secret".Sha256()) },
    Scopes = { "invoicing.read", "invoicing.write" }
};
```

Without `ApiSecrets`, the introspection endpoint will return a 401 Unauthorized and token validation will fail silently.
