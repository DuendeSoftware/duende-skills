```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdminOnly", policy =>
        policy.RequireAuthenticatedUser().RequireRole("admin"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

var admin = app.MapGroup("/admin/users")
    .RequireAuthorization("AdminOnly");

admin.MapGet("/", () => Results.Ok(new[] { "alice", "bob" }));
admin.MapPost("/", (object user) => Results.Created("/admin/users/3", user));
```

The rest of the file stays the same.

- The policy is defined once in `AddAuthorization`. The group applies it to every endpoint inside it.
- `RequireRole("admin")` checks the role claim, using `ClaimsIdentity.RoleClaimType`. With JwtBearer the default role claim type is `role` after the token handler's mapping. If your IdP uses a different claim name, set `options.TokenValidationParameters.RoleClaimType = "role"` (or the right name).
- `UseAuthorization()` is required for enforcement.
