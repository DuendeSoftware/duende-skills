# Securing `/connect/dcr` with JWT Bearer + a scope check

The DCR endpoint should never be exposed unauthenticated. The pattern is:

1. Register a JWT bearer scheme dedicated to DCR (with an `Authority` and `Audience`).
2. Define an authorization policy that requires an authenticated user and the required scope claim.
3. Apply that policy to the mapped endpoint with `RequireAuthorization`.

## Service configuration

```csharp
// A dedicated JWT bearer scheme for the DCR endpoint
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience  = "IdentityServer.Configuration";

        // DCR access tokens are at+jwt
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
    });

// Policy: must be authenticated AND carry the required scope
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("dcr", policy =>
    {
        policy.AddAuthenticationSchemes("dcr");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});
```

## Apply the policy to the endpoint

```csharp
var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthentication();
app.UseAuthorization();

app.MapRazorPages();

// Only callers holding a valid token with the required scope can register clients
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.Run();
```

## How it fits together

- **`AddJwtBearer("dcr", ...)`** — validates incoming access tokens. `Authority` points at your IdentityServer so keys are fetched from its discovery document; `Audience` (`IdentityServer.Configuration`) ensures the token was issued for this API.
- **`AddAuthorization` policy `"dcr"`** — `RequireAuthenticatedUser()` guarantees a valid principal, and `RequireClaim("scope", "IdentityServer.Configuration")` enforces the scope so only tokens issued for DCR management are accepted.
- **`RequireAuthorization("dcr")`** — attaches the policy to the DCR endpoint. Without this, `MapDynamicClientRegistration()` would be open to anonymous callers.

## Getting a token to call the endpoint

A management client uses the client-credentials flow to request the `IdentityServer.Configuration` scope, then presents the resulting access token:

```http
POST /connect/dcr
Authorization: Bearer <access_token>
Content-Type: application/json

{ "client_name": "My App", "redirect_uris": ["https://app.example.com/callback"], "grant_types": ["authorization_code"] }
```

Your `dcr.manager` client (client-credentials, allowed scope `IdentityServer.Configuration`) is already set up for exactly this — request that scope and use the token as the bearer credential.

**Never** map `MapDynamicClientRegistration()` without `RequireAuthorization(...)`.
