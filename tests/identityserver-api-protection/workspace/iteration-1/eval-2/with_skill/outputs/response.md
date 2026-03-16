# Configuring Reference Token Introspection

Reference tokens are opaque strings that require validation via the OAuth 2.0 introspection endpoint. Here's how to configure your API.

## Step 1: Add the NuGet Package

You can use either the standalone introspection package or the combined access token validation package:

```bash
dotnet add package Duende.AspNetCore.Authentication.OAuth2Introspection
```

Or:

```bash
dotnet add package Duende.IdentityServer.AccessTokenValidation
```

## Step 2: Configure Introspection

Update your `Program.cs`:

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// Add OAuth2 introspection for reference token validation
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

app.MapPost("/data", (DataModel model) => Results.Created($"/data/{model.Id}", model))
    .RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## Important: ApiResource Configuration in IdentityServer

The `ClientId` and `ClientSecret` above correspond to the `ApiResource` name and secret in IdentityServer. **The ApiResource must have `ApiSecrets` configured for introspection to work.** Without it, introspection requests will fail with a 401.

```csharp
// IdentityServer configuration
var apiResource = new ApiResource("invoicing")
{
    // ❌ WRONG: No secret — introspection will fail
    // Scopes = { "invoicing.read" }

    // ✅ CORRECT: ApiSecrets required for introspection
    ApiSecrets = { new Secret("invoicing_secret".Sha256()) },
    Scopes = { "invoicing.read", "invoicing.write" }
};
```

## How It Works

When a client presents a reference token to your API:

1. The introspection handler sends the opaque token to `https://auth.mycompany.com/connect/introspect`
2. It authenticates using the `ClientId` and `ClientSecret` (the API resource credentials)
3. IdentityServer looks up the token in its operational store and returns the token claims if active
4. The handler populates the `ClaimsPrincipal` with the returned claims

Unlike JWT validation, introspection requires a network call to IdentityServer for every request, but reference tokens can be revoked immediately.
