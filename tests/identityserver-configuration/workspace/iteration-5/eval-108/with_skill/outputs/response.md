# Getting an `aud` Claim for a Single API

Since you only have one API and don't want to model full API Resources, the simplest option is to enable `EmitStaticAudienceClaim`. This makes IdentityServer add a fixed audience claim to every access token.

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Emit a static "aud" claim on all access tokens
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);
```

With this enabled, tokens carry:

```json
{
  "aud": "https://your-identityserver/resources",
  "scope": "your_scope"
}
```

The audience value is `{issuer}/resources` — i.e., your IdentityServer's issuer URL with `/resources` appended. Configure your API's JWT bearer validation to expect that value:

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer(o =>
    {
        o.Authority = "https://your-identityserver";
        o.Audience  = "https://your-identityserver/resources";
    });
```

## Notes

- **`EmitStaticAudienceClaim = true`** is the least-effort way to get an `aud` claim when you have a single API and are using only API Scopes — no API Resource needed.
- The emitted audience is always `{issuer}/resources`, a single static value shared by all tokens.
- **Alternative:** define a minimal `ApiResource` (e.g., `new ApiResource("my-api") { Scopes = { "your_scope" } }`) and register it with `AddInMemoryApiResources`. This gives a more targeted, API-specific `aud` value (`my-api`) and is the better choice if you later add more APIs or need audience isolation.
- Do **not** reach for the implicit grant type or other deprecated patterns to solve this — the audience behavior is purely a token-emission/options concern.
