# Protecting APIs Co-hosted with IdentityServer

If your API runs in the same process as IdentityServer, you can validate tokens locally without making network calls.

## Approach

You could configure JWT bearer authentication pointing to localhost, but there's a simpler approach. IdentityServer provides a built-in mechanism for this.

```csharp
// In IdentityServer host
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes);

// Add JWT bearer pointing to self
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://localhost:5001"; // self
        options.Audience = "api1";
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/api/data", () => "Protected")
    .RequireAuthorization();

app.Run();
```

This works but still does a network call to the discovery endpoint on startup. For truly local validation, look into IdentityServer's built-in local API support if available.
