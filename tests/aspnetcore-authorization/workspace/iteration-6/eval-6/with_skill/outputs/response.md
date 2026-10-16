## Single combined policy

All requirements in one policy are ANDed, so one policy can hold both checks:

```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("catalog-delete", policy =>
    {
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "catalog.write"); // Client permission
        policy.RequireRole("admin");                   // User permission
    });
});

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapDelete("/products/{id}", (int id) => Results.NoContent())
   .RequireAuthorization("catalog-delete");
```

(An inline version works too: `.RequireAuthorization(p => p.RequireClaim("scope", "catalog.write").RequireRole("admin"))`, but a named policy is centralized and reusable.)

## Why check both?

Scope ≠ permission.

- **Scope (`catalog.write`) is what the client application is allowed to do.** It's granted by the authorization server to the client. A privileged user working through a restricted client (for example a read-only reporting app) must still be limited by that client's scopes.
- **Role (`admin`) is what the user is allowed to do.** A client may request broad scopes, but that doesn't mean the signed-in user has the right to delete.

If you check only the role, a client without the write scope could still pass. If you check only the scope, any user of a write-capable client could delete. Requiring both enforces least privilege on both sides.

If your scopes arrive as a single space-delimited string (`EmitScopesAsSpaceDelimitedStringInJwt = true`), replace `RequireClaim` with a custom `ScopeRequirement`/`ScopeHandler`, added to the same policy through `policy.Requirements.Add(...)`.
