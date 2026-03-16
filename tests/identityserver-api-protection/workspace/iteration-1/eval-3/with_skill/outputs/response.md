# Handling Both JWT and Reference Tokens in a Single API

To support both JWT access tokens and reference tokens in a single API, use `ForwardReferenceToken` from the `Duende.AspNetCore.Authentication.JwtBearer` package. This routes tokens to the correct handler based on whether they contain a dot (JWTs have dots, reference tokens don't).

## Step 1: Add NuGet Packages

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
dotnet add package Duende.AspNetCore.Authentication.OAuth2Introspection
```

## Step 2: Configure Both Handlers

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
        
        // Critical: Validate the at+jwt type header to prevent JWT confusion attacks
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

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## How ForwardReferenceToken Works

`Selector.ForwardReferenceToken("introspection")` creates a `ForwardDefaultSelector` that inspects the incoming Bearer token:

- **Contains a dot (`.`)** — Treated as a JWT (`header.payload.signature`), validated by the `AddJwtBearer` handler
- **No dot** — Treated as a reference token (opaque string), forwarded to the `AddOAuth2Introspection` handler named `"introspection"`

The scheme name passed to `ForwardReferenceToken()` must exactly match the scheme name used in `AddOAuth2Introspection()`. In this case, both use `"introspection"`.

## IdentityServer-Side Configuration

On the IdentityServer side, ensure the `ApiResource` has secrets for introspection:

```csharp
var apiResource = new ApiResource("api1")
{
    ApiSecrets = { new Secret("api1_secret".Sha256()) },
    Scopes = { "api1.read", "api1.write" }
};
```
