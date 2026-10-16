I'm not certain what import tooling Duende User Management provides, so verify with the docs. General strategy:

1. **Map the schema:** ASP.NET Identity's `AspNetUsers` (Id, UserName, Email, EmailConfirmed, PasswordHash, PhoneNumber, SecurityStamp), plus `AspNetUserClaims`, `AspNetUserLogins`, `AspNetUserRoles` map to User Management profile attributes/credentials.
2. **Preserve subject IDs:** keep the same `sub` (the existing user Id) so existing grants, refresh tokens and downstream API data keep matching.
3. **Passwords:** you can't decrypt hashes. Either (a) lazy migration – on login, validate against the legacy Identity hasher (PBKDF2 `PasswordHasher<TUser>`), then re-save the password in the new system; or (b) if User Management is passwordless, send users through email OTP/passkey enrollment verifying their confirmed email.
4. **External logins:** migrate `AspNetUserLogins` provider/key pairs.
5. **Run in parallel:** do a batch import script (read old DB, create users via the User Management API), keep the old store as fallback during cutover, then decommission.
6. Test with a sample of users, and communicate any required re-enrollment (e.g. MFA, passkeys).
