# Migrating from ASP.NET Identity to Duende User Management

Duende User Management provides a built-in migration path from ASP.NET Identity that preserves existing user access.

## Configuration

Add the migration inside your `AddUserManagement()` options lambda:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddUserManagement(options =>
    {
        options.AddPostgreSqlStore(connectionString);

        // Migrate existing ASP.NET Identity users
        options.AddAspNetIdentityMigration(migrationOptions =>
        {
            migrationOptions.ConnectionString = "Server=...;Database=ExistingIdentityDb;...";
        });

        options.UseSmtpOtpDispatcher(smtp =>
            builder.Configuration.GetSection("Smtp").Bind(smtp));
    });
```

## How It Works

1. **Password hashes are preserved** — users can continue to log in with their existing passwords immediately after migration. No password reset is required.

2. **Migration is idempotent** — subsequent runs skip users that have already been imported. You can safely restart the application without duplicating users.

3. **Imports users, roles, and claims** — the migration reads from the existing ASP.NET Identity tables (AspNetUsers, AspNetRoles, AspNetUserClaims, etc.) and creates corresponding records in the User Management store.

4. **After migration, users can enroll in passwordless methods** — once migrated, users can set up OTP, TOTP, or passkeys alongside (or instead of) their existing password.

## Recommended Migration Strategy

1. Deploy with `AddAspNetIdentityMigration()` configured — existing users are imported on first startup.
2. Keep the old ASP.NET Identity database read-only as a backup.
3. Encourage users to enroll in passwordless authentication (passkeys or TOTP).
4. Eventually remove the migration configuration once all users have been imported.
