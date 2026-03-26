# Getting an Audience Claim Without Full API Resources

The simplest way to get an `aud` (audience) claim when you only have a single API is to enable `EmitStaticAudienceClaim`:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Emit a static audience claim: {issuer}/resources
    options.EmitStaticAudienceClaim = true;

    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryApiScopes(new ApiScope[]
    {
        new ApiScope("api1", "My API")
    });
```

## What EmitStaticAudienceClaim Does

When set to `true`, every access token will include an `aud` claim with the value `{issuer}/resources`. For example, if your IdentityServer issuer is `https://identity.example.com`, the token will contain:

```json
{
  "iss": "https://identity.example.com",
  "aud": "https://identity.example.com/resources",
  "scope": "api1"
}
```

Your API validates this audience:

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "https://identity.example.com/resources";
    });
```

## Alternative: Minimal ApiResource

If you want a more targeted audience claim, define a minimal `ApiResource`:

```csharp
.AddInMemoryApiScopes(new[] { new ApiScope("api1", "My API") })
.AddInMemoryApiResources(new[]
{
    new ApiResource("my-api")
    {
        Scopes = { "api1" }
    }
})
```

This produces `"aud": "my-api"` instead of the static `{issuer}/resources`. This is better if you plan to add more APIs later, as each can have its own audience.

## When to Use Which

| Approach | Audience Value | Best For |
|----------|---------------|----------|
| `EmitStaticAudienceClaim = true` | `{issuer}/resources` | Single API, simplest setup |
| `ApiResource` | Custom per-API name | Multiple APIs or planned growth |
