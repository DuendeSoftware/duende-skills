Define the `admin` policy once in `AddAuthorization`, then apply it to a `MapGroup`. This follows the policy-over-role-strings approach, so no `[Authorize(Roles = ...)]` is scattered around.

```csharp
builder.Services.AddAuthorization(options =>
{
    // Centrally defined policy
    options.AddPolicy("admin", policy =>
        policy.RequireAuthenticatedUser()
              .RequireRole("admin"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Group-level authorization: every endpoint in the group requires the policy
var adminGroup = app.MapGroup("/admin")
    .RequireAuthorization("admin");

adminGroup.MapGet("/users", () => Results.Ok(new[] { "alice", "bob" }));
adminGroup.MapPost("/users", (object user) => Results.Created("/admin/users/3", user));
```

The resulting routes are still `GET /admin/users` and `POST /admin/users`. The old `app.MapGet("/admin/users", ...)` and `app.MapPost("/admin/users", ...)` registrations should be removed, along with the "no authorization configured yet" comment.

Notes:
- Any endpoint added to `adminGroup` later automatically inherits the policy, so it fails closed.
- `RequireRole("admin")` depends on the token's role claim being mapped as the role claim type. If your IdP uses another claim name, set `TokenValidationParameters.RoleClaimType` in `AddJwtBearer`.
- For an API protected by IdentityServer, you may also add a scope requirement to the same policy, since scope says what the client may do and the role says what the user may do.
- `UseAuthorization()` is required.
