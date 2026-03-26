# Client Configuration Review

Looking at this configuration, there are a few issues:

## Fix 1: Add .Sha256() to the Secret

```csharp
// Before
ClientSecrets = { new Secret("super-secret-password") }

// After
ClientSecrets = { new Secret("super-secret-password".Sha256()) }
```

Secrets need to be hashed before storage.

## Fix 2: Missing openid Scope

For OIDC to work, you need the `openid` scope:

```csharp
AllowedScopes = { "openid", "profile", "email", "api1" }
```

## Fix 3: Enable Refresh Tokens

Change `AllowOfflineAccess` to `true`:

```csharp
AllowOfflineAccess = true
```

## Fixed Client

```csharp
new Client
{
    ClientId = "my-web-app",
    AllowedGrantTypes = GrantTypes.Code,
    ClientSecrets = { new Secret("super-secret-password".Sha256()) },
    RedirectUris = { "https://app.example.com/signin-oidc/" },
    AllowedScopes = { "openid", "profile", "email", "api1" },
    AllowOfflineAccess = true
}
```
