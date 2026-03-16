# Validating Reference Tokens with Introspection

Reference tokens (opaque tokens) need to be validated by calling back to the authorization server's introspection endpoint. Here's how to set that up.

## Step 1: Add a Token Introspection Package

You'll need a package that supports OAuth 2.0 token introspection. For IdentityServer-based setups, you can use:

```bash
dotnet add package IdentityModel.AspNetCore.OAuth2Introspection
```

## Step 2: Configure the API

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("Bearer")
    .AddOAuth2Introspection("Bearer", options =>
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

public record DataModel(int Id, string Name, string Description);
```

## How Introspection Works

When a request comes in with an opaque bearer token, the middleware sends the token to the authorization server's introspection endpoint (`/connect/introspect`). The server checks if the token is still valid and returns the associated claims.

This approach allows for immediate token revocation since the authorization server checks the token's status on every API call. The trade-off is that every API request requires a network call to the authorization server.
