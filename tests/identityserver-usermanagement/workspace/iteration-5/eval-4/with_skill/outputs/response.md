# Migrating Existing Users from ASP.NET Identity to Duende User Management

You can import your existing ASP.NET Identity users into Duende User Management **without forcing anyone to reset their password**. Duende User Management ships a built-in migration that reads your existing ASP.NET Identity database and imports users, roles, and claims — **preserving the existing password hashes** so users keep logging in with their current credentials.

## Configuration

Add the migration inside the `AddUserManagement()` options lambda, pointing it at your **existing** ASP.NET Identity database connection string:

```csharp
using Duende.UserManagement;

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddUserManagement(options =>
    {
        // New User Management store (destination)
        options.AddPostgreSqlStore(
            builder.Configuration.GetConnectionString("UserManagement"));

        // Import from the existing ASP.NET Identity database (source)
        options.AddAspNetIdentityMigration(migration =>
        {
            migration.ConnectionString =
                builder.Configuration.GetConnectionString("LegacyAspNetIdentity");
        });
    });
```

## What Gets Imported

- **Users** — accounts and their profile data
- **Roles** — role assignments
- **Claims** — user claims stored in the Identity tables
- **Password hashes** — imported **as-is**

## Why Users Don't Lose Access

Because the **password hashes are preserved** during import, an imported user can log in immediately with the **same password they already use** — there's no forced reset and no "losing access." The hashes are carried over verbatim into the new store and validated on sign-in.

## The Migration Is Idempotent

- The migration **runs once** and imports users that aren't already present.
- **Subsequent runs skip users that have already been imported**, so it's safe to leave the migration configured across deployments or to re-run it — it won't duplicate accounts or clobber existing ones.

## After Migration

Once users are imported, they can start **enrolling in passwordless authentication methods** — email/SMS OTP, TOTP authenticator apps, and passkeys (WebAuthn/FIDO2) — while still being able to fall back to their migrated password. This lets you move users off passwords gradually rather than all at once.

## Recommended Rollout

1. Stand up the new User Management store and configure `AddAspNetIdentityMigration` against a copy/read of the legacy DB.
2. Run the app so the migration imports existing users (idempotent — safe to repeat).
3. Verify a few accounts can log in with existing passwords.
4. Encourage users to enroll a passwordless method (OTP/TOTP/passkey).
5. Once adoption is high, optionally disable password sign-in.
