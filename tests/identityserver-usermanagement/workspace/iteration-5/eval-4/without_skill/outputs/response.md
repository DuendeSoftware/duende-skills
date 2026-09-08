# Migrating Users from ASP.NET Identity Without Locking Them Out

The good news: ASP.NET Core Identity stores passwords as salted hashes using its `IPasswordHasher<TUser>` (PBKDF2 by default, with a version marker on each hash). As long as your new system can validate those same hashes, you can migrate users **without a password reset**. Here's how I'd approach it.

## 1. Understand the Existing Data

The important columns in `AspNetUsers` are:

- `Id`, `UserName`, `NormalizedUserName`, `Email`, `NormalizedEmail`, `EmailConfirmed`
- `PasswordHash` — the hashed password (format is self-describing/versioned)
- `SecurityStamp`, `ConcurrencyStamp`
- Plus `AspNetUserRoles`, `AspNetUserClaims`, `AspNetUserLogins` for roles/claims/external logins

## 2. Preserve the Password Hashes

The key to not locking users out is to **carry the `PasswordHash` value over verbatim**. Because ASP.NET Identity's default hasher understands its own historical hash formats, if your target continues to use a compatible `PasswordHasher`, a user's existing password will validate on first sign-in — no reset required.

If your new store uses a different hashing scheme, the common pattern is **rehash-on-login**: keep the old hash, and the first time a user successfully authenticates, transparently rehash their password into the new format.

## 3. Do the Import

A straightforward, idempotent import loop:

```csharp
foreach (var legacy in legacyUsers)
{
    // Skip if already imported (makes the migration safe to re-run)
    if (await targetStore.ExistsAsync(legacy.Email)) continue;

    var user = new AppUser
    {
        UserName = legacy.UserName,
        Email = legacy.Email,
        EmailConfirmed = legacy.EmailConfirmed,
        PasswordHash = legacy.PasswordHash,   // preserved as-is
        SecurityStamp = legacy.SecurityStamp
    };
    await targetStore.CreateAsync(user);
    // copy roles and claims too
}
```

Guarding with an existence check makes the process **idempotent** — you can run it repeatedly (or in batches during a phased cutover) and it won't create duplicates.

## 4. Migrate Roles and Claims

Copy `AspNetUserRoles` → role assignments and `AspNetUserClaims` → user claims so authorization keeps working after the move.

## 5. Cutover Strategy

- Run the import ahead of time against a snapshot, then a final delta sync at cutover.
- Verify a sample of accounts can log in with their existing passwords.
- Keep the old system read-only as a fallback for a short window.

## Summary

- ASP.NET Identity password hashes are portable — **copy `PasswordHash` verbatim** and users keep their current passwords.
- If schemes differ, use **rehash-on-login**.
- Make the import **idempotent** with an existence check so it can run repeatedly.
- Don't forget roles, claims, and external logins.

If you're moving to a specific Duende user-management product, check whether it provides a built-in ASP.NET Identity import routine — that would save you writing the loop above — but the hash-preservation principle is the same.
