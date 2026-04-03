Looking at this client configuration, I can spot a few issues:

## Issues

### 1. The secret should be hashed
The `Secret` class typically expects the value to be hashed. You should call `.Sha256()` on the secret string:

```csharp
ClientSecrets = { new Secret("super-secret-password".Sha256()) }
```

### 2. Trailing slash on redirect URI
The redirect URI has a trailing slash which might cause issues with exact URL matching:

```csharp
// Fix: remove trailing slash
RedirectUris = { "https://app.example.com/signin-oidc" }
```

### 3. Missing openid scope
For OpenID Connect to work properly, you need the `openid` scope:

```csharp
AllowedScopes = { "openid", "profile", "email", "api1" }
```

### 4. AllowOfflineAccess should be true
To get refresh tokens, you need to enable offline access:

```csharp
AllowOfflineAccess = true
```

## Fixed Configuration

```csharp
new Client
{
    ClientId = "my-web-app",
    AllowedGrantTypes = GrantTypes.Code,
    ClientSecrets = { new Secret("super-secret-password".Sha256()) },
    RedirectUris = { "https://app.example.com/signin-oidc" },
    AllowedScopes = { "openid", "profile", "email", "api1" },
    AllowOfflineAccess = true
}
```
