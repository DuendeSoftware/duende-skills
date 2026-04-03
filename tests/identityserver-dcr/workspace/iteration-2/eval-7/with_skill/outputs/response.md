Here's how to set up DCR in a separate application from your main IdentityServer at `https://identity.example.com`.

### Separate DCR Host — Program.cs

```csharp
// Program.cs — Separate DCR Host (NOT an IdentityServer instance)

var builder = WebApplication.CreateBuilder(args);

// Register DCR services pointing to the main IdentityServer
builder.Services.AddIdentityServerConfiguration(options =>
{
    options.IdentityServerBaseUrl = "https://identity.example.com";
});

// Configure Entity Framework store for persisting DCR clients
// This MUST use the same database that IdentityServer reads from
builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();

// JWT bearer authentication pointing to the main IdentityServer
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "IdentityServer.Configuration";
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

// Authorization policy for the DCR endpoint
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("dcr", policy =>
    {
        policy.AddAuthenticationSchemes("dcr");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Map the DCR endpoint with authorization
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.Run();
```

### Key points

1. **`AddIdentityServerConfiguration` with `IdentityServerBaseUrl`** — This tells the DCR host where the main IdentityServer lives at `https://identity.example.com`. The DCR host does NOT call `AddIdentityServer()` because it's not an IdentityServer instance.

2. **JWT bearer authentication** — The `Authority` is set to the main IdentityServer URL. The DCR host validates tokens issued by the main IdentityServer.

3. **`MapDynamicClientRegistration().RequireAuthorization("dcr")`** — Maps the DCR endpoint and secures it with the authorization policy.

4. **`IClientConfigurationStore` must be backed by the same database** — The separate DCR host writes clients to a database, and IdentityServer must read from the same database. Without this, IdentityServer won't know about dynamically registered clients.

5. **No `AddIdentityServer()` call** — This application does NOT run IdentityServer. It only hosts the DCR endpoint. Adding `AddIdentityServer()` would create a second IdentityServer instance, which is not the intent.
