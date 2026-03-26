# Combining Scope and Role Requirements for DELETE Endpoint

You can create a policy that requires both a specific scope and a role. Here's how:

```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("catalog.delete", policy =>
    {
        policy.RequireClaim("scope", "catalog.write");
        policy.RequireRole("admin");
    });
});
```

Apply it to the DELETE endpoint:

```csharp
app.MapDelete("/products/{id}", (int id) => Results.NoContent())
    .RequireAuthorization("catalog.delete");
```

## Why Both?

Checking both the scope and the role is important because they represent different things:

- **Scopes** come from the OAuth token and represent what the application (client) is allowed to do. They are granted during the authorization flow.
- **Roles** represent the user's permissions. Even if the client has a broad scope, the user might not have the right role.

By combining both, you ensure that the client application has permission to perform write operations AND the specific user has the admin role. This prevents scenarios where a client with write scope could be used by non-admin users to delete products.
