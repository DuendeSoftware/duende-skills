Put both requirements in a single policy. When a policy contains multiple requirements, ASP.NET Core requires all of them (AND logic), so combining `RequireClaim("scope", "catalog.write")` and `RequireRole("admin")` means a request must satisfy both.

```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("DeleteProducts", policy =>
    {
        policy.RequireClaim("scope", "catalog.write");
        policy.RequireRole("admin");
    });
});
```

Apply it to the DELETE endpoint:

```csharp
app.MapDelete("/products/{id}", (int id) => Results.NoContent())
    .RequireAuthorization("DeleteProducts");
```

### Why check both

These two checks protect against different things:

- A **scope** (`catalog.write`) is a permission granted to the **client application** through OAuth. It says the calling app is allowed to make write calls to this API.
- A **role** (`admin`) is a permission that belongs to the **user**. It says this particular person is allowed to perform admin-level actions.

If you only checked the role, an admin user could delete data even from an application that was never supposed to have write access. If you only checked the scope, then any user of a write-capable client could delete, including non-admins. Requiring both ensures the delete happens only when a trusted client is acting on behalf of an authorized user — the action is allowed only where the client's permissions and the user's permissions overlap.
