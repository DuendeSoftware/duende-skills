Define a single policy that adds **both** requirements — the client scope and the user role — and apply it to `DELETE /products/{id}`. Multiple requirements within one policy are combined with **AND** logic, so both must be satisfied for the request to be authorized.

```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("catalog.delete", policy =>
    {
        // Client permission: the access token must carry the write scope
        policy.RequireClaim("scope", "catalog.write");
        // User permission: the acting user must be an admin
        policy.RequireRole("admin");
    });
});
```

Apply it to the endpoint:

```csharp
app.MapDelete("/products/{id}", (int id) => Results.NoContent())
    .RequireAuthorization("catalog.delete");
```

(Both `app.UseAuthentication()` and `app.UseAuthorization()` must be in the pipeline, in that order.)

### Why check *both*

Scopes and roles answer two different questions, and each guards against a different failure mode:

- **Scope = client permission.** An OAuth scope like `catalog.write` describes what the **calling application** is authorized to do with the API. It is granted to the client (and consented to), independent of who the end user is.
- **Role/claim = user permission.** `admin` describes what the **end user** is allowed to do.

If you check only the **role**, a user who is an admin could perform a destructive delete through a client application that was never trusted with write access — for example a read-only mobile app or a third-party integration that should only have `catalog.read`. The client's limited scope should constrain even a privileged user.

If you check only the **scope**, then *any* user calling through a write-capable client could delete products, even non-admins — the client's broad permission would leak to every user of that client.

Requiring both means the delete only succeeds when a **trusted client** (has `catalog.write`) is acting on behalf of a **privileged user** (is `admin`). This is the principle of least privilege applied across both the client and user dimensions of an OAuth-protected API: the effective permission is the *intersection* of what the client may do and what the user may do.

> If your IdentityServer emits scopes as a single space-delimited string, `RequireClaim("scope", "catalog.write")` won't match a substring — in that case use a custom scope requirement/handler that splits on spaces, combined in the same policy with the role check.
