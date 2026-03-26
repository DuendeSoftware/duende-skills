# Configuring Reference Token Introspection

To validate reference tokens (opaque strings), your API needs to call IdentityServer's introspection endpoint. Here's how to set it up.

## Step 1: Install the Introspection Package

```bash
dotnet add package Duende.AspNetCore.Authentication.OAuth2Introspection
```

Or the combined validation package:

```bash
dotnet add package Duende.IdentityServer.AccessTokenValidation
```

## Step 2: Configure OAuth2 Introspection

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("token")
    .AddOAuth2Introspection("token", options =>
    {
        options.Authority = "https://auth.mycompany.com";
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
```

## How It Works

When a request arrives with a Bearer token, the introspection handler sends the token to IdentityServer's `/connect/introspect` endpoint. The API authenticates to the introspection endpoint using `ClientId` and `ClientSecret`.

## Critical: ApiResource Must Have ApiSecrets

For introspection to work, the `ApiResource` in IdentityServer must have `ApiSecrets` configured:

```csharp
// IdentityServer configuration
var apiResource = new ApiResource("invoicing")
{
    ApiSecrets = { new Secret("invoicing_secret".Sha256()) },
    Scopes = { "invoicing.read", "invoicing.write" }
};
```

Without `ApiSecrets` on the `ApiResource`, the introspection endpoint will return a 401 Unauthorized response, and your API will reject all tokens.
