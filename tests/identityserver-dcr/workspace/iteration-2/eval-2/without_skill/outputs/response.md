To secure the DCR endpoint with JWT bearer authentication and scope-based authorization, you'll need to configure authentication and authorization in your ASP.NET Core pipeline.

### Program.cs changes

```csharp
// Add JWT bearer authentication
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
    });

// Add authorization with a policy for DCR
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("DcrPolicy", policy =>
    {
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "dcr:manage");
    });
});
```

### Applying the policy

If you have a custom DCR endpoint, apply the policy:

```csharp
app.MapPost("/connect/register", async (HttpContext context) =>
{
    // DCR logic here
})
.RequireAuthorization("DcrPolicy");
```

Or if IdentityServer has built-in DCR support, you would need to check their documentation for how to apply authorization policies to it. Generally, you'd configure the endpoint to require authorization during setup.

### Key considerations

- Make sure the `Authority` points to your IdentityServer instance
- The `Audience` should match what your token endpoint issues
- The scope claim `dcr:manage` should be configured as an API scope in IdentityServer
- Always validate that the endpoint is not accessible without proper authentication
