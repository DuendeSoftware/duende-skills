# Handling Both JWT and Reference Tokens in a Single API

Use the `Duende.AspNetCore.Authentication.JwtBearer` package which provides `ForwardReferenceToken` to automatically route tokens to the correct handler.

## Install Package

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

## Configure Both Handlers

```csharp
using Duende.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];

        // Forward reference tokens to the introspection handler
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

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.Run();
```

## How ForwardReferenceToken Works

The `Selector.ForwardReferenceToken("introspection")` selector inspects the incoming Bearer token:

- **Contains a dot (`.`)** — treated as a JWT, validated by the `AddJwtBearer` handler
- **No dot** — treated as a reference token, forwarded to the `AddOAuth2Introspection` handler named `"introspection"`

The scheme name passed to `ForwardReferenceToken()` must exactly match the scheme name used in `AddOAuth2Introspection()` — in this case `"introspection"`.
