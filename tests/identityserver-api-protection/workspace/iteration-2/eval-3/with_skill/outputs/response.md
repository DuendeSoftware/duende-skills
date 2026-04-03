# Handling Both JWT and Reference Tokens in a Single API

When some clients receive JWTs and others receive reference tokens, you need both authentication handlers with a selector that routes tokens to the correct handler.

## 1. Install the Duende JWT Bearer Package

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

This package provides the `ForwardReferenceToken` selector that inspects the token format: if it contains a dot (`.`) it's treated as a JWT; if not, it's forwarded to the introspection handler.

## 2. Configure Both Handlers

```csharp
// Program.cs
using Duende.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";

        // Validate at+jwt type to prevent JWT confusion attacks
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];

        // Forward reference tokens (no dots) to the introspection handler
        options.ForwardDefaultSelector =
            Selector.ForwardReferenceToken("introspection");
    })
    .AddOAuth2Introspection("introspection", options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "api1";
        options.ClientSecret = "api1_secret";
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

## How ForwardReferenceToken Works

The `Selector.ForwardReferenceToken("introspection")` method creates a selector function that:

- **Token contains a dot (`.`)** → treated as a JWT (header.payload.signature), validated by `AddJwtBearer`
- **Token has no dot** → treated as a reference token (opaque string), forwarded to the `AddOAuth2Introspection` handler named `"introspection"`

The scheme name `"introspection"` passed to `ForwardReferenceToken` must exactly match the scheme name used in `AddOAuth2Introspection`.
