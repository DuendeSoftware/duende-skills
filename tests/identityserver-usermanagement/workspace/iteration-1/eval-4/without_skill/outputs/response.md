# Migrating Users from ASP.NET Identity

If you're moving away from ASP.NET Identity to a new user management system, you'll need to export and import users carefully to preserve access.

## General Approach

1. **Export users from the existing database** — query the `AspNetUsers`, `AspNetRoles`, `AspNetUserRoles`, and `AspNetUserClaims` tables.

2. **Preserve password hashes** — ASP.NET Identity uses PBKDF2 (v2 or v3 format). If your new system supports the same hashing format, users won't need to reset passwords.

3. **Write a migration script**:

```csharp
// Pseudocode for migration
var existingUsers = await oldDbContext.Users.ToListAsync();

foreach (var user in existingUsers)
{
    var newUser = new NewUserModel
    {
        Email = user.Email,
        PasswordHash = user.PasswordHash, // Preserve hash
        EmailConfirmed = user.EmailConfirmed
    };
    
    await newUserStore.CreateAsync(newUser);
}
```

4. **Handle roles and claims** — migrate `AspNetUserRoles` and `AspNetUserClaims` to your new system's equivalent.

## Considerations

- Test the migration with a subset of users first.
- Run the migration in a maintenance window or make it idempotent so it can be re-run.
- Verify that password validation works with the preserved hashes.
- Plan for users who may need to re-verify their email or set up new 2FA.

## After Migration

- Decommission the old ASP.NET Identity tables once you've verified all users are migrated.
- Consider offering users a "set up new authentication" flow for modern methods like passkeys.
