```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("ProductDelete", policy =>
        policy.RequireAuthenticatedUser()
              .RequireClaim("scope", "catalog.write")
              .RequireRole("admin"));
});

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapDelete("/products/{id}", (int id) => Results.NoContent())
   .RequireAuthorization("ProductDelete");
```

Every requirement in one policy must be satisfied (AND semantics), so a single policy enforces both checks.

## Why check both?

- **Scope = what the client application is allowed to do.** It is delegated by the user and granted by the authorization server to the client. It limits the token's power, so a compromised or low-privilege app can't use the token for operations it wasn't approved for.
- **Role = what the user is allowed to do.** It reflects who the person is in your system.

Checking only the scope means any user with a write-capable client could delete. Checking only the role means any client app acting for an admin, including one that was never meant to write, could delete. Requiring both enforces least privilege on both the client and the user.

If your IdP sends `scope` as one space-delimited string, use a custom scope handler instead of `RequireClaim`.
