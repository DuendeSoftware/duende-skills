# Supporting Both JWT and Reference Tokens

To accept both JWT and reference (opaque) tokens, you'll need to configure two authentication schemes. Here's how:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api";
    })
    .AddOAuth2Introspection("introspection", options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "catalog-api";
        options.ClientSecret = "api-secret";
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.Run();
```

## How It Works

- **JWT Bearer** validates self-contained JWT tokens locally using the signing keys from the authority
- **OAuth2 Introspection** validates opaque/reference tokens by sending them to the introspection endpoint

You'll need to determine which handler to use based on the token format. JWT tokens typically start with `eyJ` (base64-encoded JSON header), while reference tokens are opaque strings.

You may need to implement custom logic to route tokens to the appropriate handler, or use a policy scheme to select the right scheme at runtime.
