# Securing the `/connect/dcr` endpoint with JWT bearer + scope check

To restrict who can register clients, protect the DCR endpoint with JWT bearer authentication and an authorization policy that checks for a specific scope, then require that policy on the mapped endpoint.

## 1. Add JWT bearer authentication

```csharp
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        // Point at the token issuer (your IdentityServer)
        options.Authority = "https://identity.example.com";
        options.Audience  = "IdentityServer.Configuration";
    });
```

Using a named scheme (`"dcr"`) keeps this separate from any other authentication you may already have.

## 2. Add an authorization policy requiring the scope

Scopes typically arrive in the `scope` claim. Require an authenticated user plus the expected scope:

```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("DcrPolicy", policy =>
    {
        policy.AddAuthenticationSchemes("dcr");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});
```

If your tokens pack multiple scopes into a single space-delimited `scope` string, a `RequireAssertion` check can be more robust:

```csharp
policy.RequireAssertion(ctx =>
    ctx.User.FindFirst("scope")?.Value
        .Split(' ')
        .Contains("IdentityServer.Configuration") == true);
```

## 3. Apply the policy to the endpoint

```csharp
var app = builder.Build();

app.UseRouting();
app.UseIdentityServer();
app.UseAuthentication();
app.UseAuthorization();

app.MapRazorPages();

app.MapDynamicClientRegistration()
    .RequireAuthorization("DcrPolicy");

app.Run();
```

## Result

- Requests without a valid bearer token get a `401 Unauthorized`.
- Requests with a valid token but missing the `IdentityServer.Configuration` scope get a `403 Forbidden`.
- Only correctly scoped callers reach the registration logic.

Make sure `UseAuthentication()` and `UseAuthorization()` are in the pipeline before the endpoint is mapped, and never expose `MapDynamicClientRegistration()` without the `RequireAuthorization` call.
