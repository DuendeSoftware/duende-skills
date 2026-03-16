---
name: identityserver-clients-resources
description: Configuring clients and resources in Duende IdentityServer, including client types (M2M, interactive, SPA), grant types, API Scopes vs API Resources vs Identity Resources, secret management, CORS, and client authentication methods.
invocable: false
---

# Configuring Clients and Resources

## When to Use This Skill

- Defining client applications that request tokens from IdentityServer
- Choosing the correct grant type for a client scenario (M2M, interactive, SPA)
- Designing API surfaces with scopes and resources
- Configuring Identity Resources for user claims in tokens
- Setting up client secrets and choosing authentication methods
- Configuring CORS for browser-based clients
- Understanding the relationship between API Scopes, API Resources, and Identity Resources
- Configuring refresh token behavior and token lifetimes

## Resource Types: The Three Pillars

IdentityServer manages access to resources through three distinct types. Understanding when to use each is fundamental.

### Decision Matrix: Which Resource Type to Use

| Need                                    | Resource Type         | Purpose                                                |
| --------------------------------------- | --------------------- | ------------------------------------------------------ |
| User identity claims (name, email)      | **Identity Resource** | Groups claims requested via `scope` parameter          |
| API access control                      | **API Scope**         | Defines what operations a client can perform           |
| API grouping, audience (`aud`), signing | **API Resource**      | Groups scopes under a logical API with shared settings |

## Identity Resources

An identity resource is a named group of claims about a user, requested using the `scope` parameter.

The `openid` scope is mandatory per the OpenID Connect spec and returns the `sub` (subject id) claim.

### Standard Identity Resources

```csharp
public static IEnumerable<IdentityResource> IdentityResources =>
    new List<IdentityResource>
    {
        new IdentityResources.OpenId(),   // required: returns sub claim
        new IdentityResources.Profile(),  // name, family_name, etc.
        new IdentityResources.Email(),    // email, email_verified
        new IdentityResources.Phone(),    // phone_number, phone_number_verified
        new IdentityResources.Address()   // address JSON
    };
```

### Custom Identity Resources

```csharp
public static IEnumerable<IdentityResource> IdentityResources =>
    new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResource(
            name: "profile",
            userClaims: new[] { "name", "email", "website" },
            displayName: "Your profile data")
    };
```

### Granting Access to Identity Resources

```csharp
var client = new Client
{
    ClientId = "client",
    AllowedScopes = { "openid", "profile" }
};
```

The client requests the resource via the scope parameter:

```
https://identity.example.com/connect/authorize?client_id=client&scope=openid profile
```

## API Scopes

API Scopes define the scope of access a client requests. They represent operations or permissions.

### Defining API Scopes

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
    new List<ApiScope>
    {
        new ApiScope(name: "read",   displayName: "Read your data."),
        new ApiScope(name: "write",  displayName: "Write your data."),
        new ApiScope(name: "delete", displayName: "Delete your data.")
    };
```

### Scopes with User Claims

Add user claims to access tokens when a scope is granted:

```csharp
var writeScope = new ApiScope(
    name: "write",
    displayName: "Write your data.",
    userClaims: new[] { "user_level" });
```

### Scope Authorization in Tokens

When a scope is granted, it appears in the access token:

```json
{
  "typ": "at+jwt",
  "client_id": "mobile_app",
  "sub": "123",
  "scope": "read write delete"
}
```

### Important: Scopes Authorize Clients, Not Users

Scopes control what a client can do, not what a user is permitted to do. User-level authorization is application logic and not covered by OAuth.

```csharp
// ❌ WRONG mental model: "write" scope = user can write
// ✅ CORRECT mental model: "write" scope = client is allowed to invoke write operations
```

### Audience Behavior Without API Resources

When using only API Scopes (without API Resources), no `aud` claim is added to tokens. To get an audience claim, either:

- Use API Resources (recommended for multi-API systems)
- Enable `EmitStaticAudienceClaim` on the options (emits `{issuer}/resources`)

### Parameterized Scopes

For scopes with dynamic parameters (e.g., `transaction:123`):

```csharp
public class ParameterizedScopeParser : DefaultScopeParser
{
    public ParameterizedScopeParser(ILogger<DefaultScopeParser> logger) : base(logger)
    { }

    public override void ParseScopeValue(ParseScopeContext scopeContext)
    {
        const string transactionScopeName = "transaction";
        const string separator = ":";
        const string transactionScopePrefix = transactionScopeName + separator;

        var scopeValue = scopeContext.RawValue;

        if (scopeValue.StartsWith(transactionScopePrefix))
        {
            var parts = scopeValue.Split(separator, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 2)
            {
                scopeContext.SetParsedValues(transactionScopeName, parts[1]);
            }
            else
            {
                scopeContext.SetError("transaction scope missing transaction parameter value");
            }
        }
        else if (scopeValue != transactionScopeName)
        {
            base.ParseScopeValue(scopeContext);
        }
        else
        {
            scopeContext.SetIgnore();
        }
    }
}
```

## API Resources

API Resources group scopes under a logical API, providing:

- JWT `aud` (audience) claim based on the resource name
- Common user claims across all contained scopes
- Introspection support via API secrets
- Per-resource signing algorithm configuration

### Defining API Resources

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
    new List<ApiScope>
    {
        new ApiScope(name: "invoice.read",   displayName: "Reads your invoices."),
        new ApiScope(name: "invoice.pay",    displayName: "Pays your invoices."),
        new ApiScope(name: "customer.read",  displayName: "Reads customer information."),
        new ApiScope(name: "customer.contact", displayName: "Allows contacting customers."),
        new ApiScope(name: "manage",         displayName: "Provides administrative access."),
        new ApiScope(name: "enumerate",      displayName: "Allows enumerating data.")
    };

public static IEnumerable<ApiResource> ApiResources =>
    new List<ApiResource>
    {
        new ApiResource("invoice", "Invoice API")
        {
            Scopes = { "invoice.read", "invoice.pay", "manage", "enumerate" }
        },
        new ApiResource("customer", "Customer API")
        {
            Scopes = { "customer.read", "customer.contact", "manage", "enumerate" }
        }
    };
```

### Token Audience Examples

Requesting `invoice.read` and `invoice.pay`:

```json
{
  "aud": "invoice",
  "scope": "invoice.read invoice.pay"
}
```

Requesting `invoice.read` and `customer.read`:

```json
{
  "aud": ["invoice", "customer"],
  "scope": "invoice.read customer.read"
}
```

Requesting `manage` (shared scope):

```json
{
  "aud": ["invoice", "customer"],
  "scope": "manage"
}
```

### API Resource User Claims

Add claims to access tokens regardless of which scope is requested:

```csharp
var customerResource = new ApiResource("customer", "Customer API")
{
    Scopes = { "customer.read", "customer.contact", "manage", "enumerate" },
    UserClaims = { "department_id", "sales_region" }
};
```

### Per-Resource Signing Algorithm

```csharp
var invoiceApi = new ApiResource("invoice", "Invoice API")
{
    Scopes = { "invoice.read", "invoice.pay", "manage", "enumerate" },
    AllowedAccessTokenSigningAlgorithms = { SecurityAlgorithms.RsaSsaPssSha256 }
};
```

### Resource Isolation (Enterprise Edition)

Use the `resource` parameter (RFC 8707) to request tokens scoped to a single API resource, preventing over-privileged tokens.

```csharp
var resources = new[]
{
    new ApiResource("urn:invoices")
    {
        Scopes = { "read", "write" },
        RequireResourceIndicator = true  // audience only included when explicitly requested
    }
};
```

## Client Types and Grant Types

### Decision Matrix: Choosing the Right Client Type

| Scenario                      | Grant Type                     | `RequireClientSecret` | Has User |
| ----------------------------- | ------------------------------ | --------------------- | -------- |
| Server-to-server (M2M)        | `GrantTypes.ClientCredentials` | `true`                | No       |
| Web application (server-side) | `GrantTypes.Code`              | `true`                | Yes      |
| SPA / mobile / native         | `GrantTypes.Code`              | `false`               | Yes      |
| Device (TV, IoT)              | `GrantTypes.DeviceFlow`        | varies                | Yes      |

### Machine-to-Machine Client

No interactive user, service-to-service communication:

```csharp
new Client
{
    ClientId = "service.client",
    ClientSecrets = { new Secret("secret".Sha256()) },

    AllowedGrantTypes = GrantTypes.ClientCredentials,
    AllowedScopes = { "api1", "api2.read_only" }
}
```

### Interactive Web Application Client

Authorization code flow with PKCE, back-channel token exchange, refresh tokens:

```csharp
new Client
{
    ClientId = "interactive",

    AllowedGrantTypes = GrantTypes.Code,
    AllowOfflineAccess = true,
    ClientSecrets = { new Secret("secret".Sha256()) },

    RedirectUris =           { "https://myapp.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://myapp.com/" },
    FrontChannelLogoutUri =    "https://myapp.com/signout-oidc",

    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        IdentityServerConstants.StandardScopes.Email,
        "api1", "api2.read_only"
    }
}
```

### Defining Clients in appsettings.json

Clients can be defined in configuration files and loaded via `AddInMemoryClients`:

```json
{
  "IdentityServer": {
    "Clients": [
      {
        "Enabled": true,
        "ClientId": "local-dev",
        "ClientName": "Local Development",
        "ClientSecrets": [
          {
            "Value": "<Insert Sha256 hash of the secret encoded as Base64 string>"
          }
        ],
        "AllowedGrantTypes": ["client_credentials"],
        "AllowedScopes": ["api1"]
      }
    ]
  }
}
```

```csharp
// Program.cs
AddInMemoryClients(configuration.GetSection("IdentityServer:Clients"))
```

## Client Properties Reference

### Basics

| Property               | Default    | Description                                      |
| ---------------------- | ---------- | ------------------------------------------------ |
| `ClientId`             | (required) | Unique client identifier                         |
| `ClientSecrets`        | empty      | Credentials for token endpoint                   |
| `RequireClientSecret`  | `true`     | Set `false` for public clients (SPA, mobile)     |
| `AllowedGrantTypes`    | (required) | Grant types the client can use                   |
| `RequirePkce`          | `true`     | Require PKCE for authorization code flow         |
| `AllowPlainTextPkce`   | `false`    | Allow plain text PKCE (not recommended)          |
| `RedirectUris`         | empty      | Allowed redirect URIs                            |
| `AllowedScopes`        | empty      | Scopes the client can request                    |
| `AllowOfflineAccess`   | `false`    | Allow refresh tokens                             |
| `RequireRequestObject` | `false`    | Require JWT-secured authorization requests (JAR) |

### Token Settings

| Property                           | Default       | Description                              |
| ---------------------------------- | ------------- | ---------------------------------------- |
| `AccessTokenLifetime`              | 3600 (1 hour) | Access token lifetime in seconds         |
| `IdentityTokenLifetime`            | 300 (5 min)   | Identity token lifetime in seconds       |
| `AuthorizationCodeLifetime`        | 300 (5 min)   | Authorization code lifetime in seconds   |
| `AccessTokenType`                  | `Jwt`         | `Jwt` or reference token                 |
| `IncludeJwtId`                     | `true`        | Include `jti` claim in JWT access tokens |
| `AlwaysIncludeUserClaimsInIdToken` | `false`       | Put user claims in id_token vs userinfo  |

### Refresh Token Settings

| Property                           | Default           | Description                                         |
| ---------------------------------- | ----------------- | --------------------------------------------------- |
| `AbsoluteRefreshTokenLifetime`     | 2592000 (30 days) | Max refresh token lifetime                          |
| `SlidingRefreshTokenLifetime`      | 1296000 (15 days) | Sliding window lifetime                             |
| `RefreshTokenUsage`                | `ReUse`           | `ReUse` (same handle) or `OneTimeOnly` (new handle) |
| `RefreshTokenExpiration`           | `Absolute`        | `Absolute` or `Sliding`                             |
| `UpdateAccessTokenClaimsOnRefresh` | `false`           | Refresh claims on token refresh                     |

### Session Settings

| Property                            | Default | Description                            |
| ----------------------------------- | ------- | -------------------------------------- |
| `UserSsoLifetime`                   | `null`  | Max duration since last authentication |
| `CoordinateLifetimeWithUserSession` | `false` | Tie token lifetimes to user session    |

## Client Authentication Methods

### Recommendation

Use asymmetric credentials (`private_key_jwt` or mTLS) over shared secrets in production.

### Method Comparison

| Method                | Security                   | Complexity | Use Case                        |
| --------------------- | -------------------------- | ---------- | ------------------------------- |
| **Shared secret**     | Lower (secret transmitted) | Low        | Development, simple M2M         |
| **Private Key JWT**   | Higher (asymmetric)        | Medium     | Production confidential clients |
| **mTLS certificates** | Highest (TLS-bound)        | High       | High-security, FAPI compliance  |

### Shared Secrets

```csharp
// Production: load hash from secure storage
var hash = loadSecretHash();
var secret = new Secret(hash);

// Prototyping only - NEVER use in production
var compromisedSecret = new Secret("just for demos, not prod!".Sha256());
```

```csharp
// ❌ WRONG: Clear text secret in source code
var client = new Client
{
    ClientSecrets = { new Secret("MyProductionSecret".Sha256()) }
};

// ✅ CORRECT: Load secret hash from configuration or vault
var client = new Client
{
    ClientSecrets = { new Secret(Configuration["ClientSecretHash"]) }
};
```

### Private Key JWT

Register a client with X.509 certificate or JWK secret:

```csharp
var client = new Client
{
    ClientId = "client.jwt",
    ClientSecrets =
    {
        new Secret
        {
            Type = IdentityServerConstants.SecretTypes.X509CertificateBase64,
            Value = "MIID...xBXQ="
        },
        new Secret
        {
            Type = IdentityServerConstants.SecretTypes.JsonWebKey,
            Value = "{'e':'AQAB','kid':'...','kty':'RSA','n':'...'}"
        }
    },
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    AllowedScopes = { "api1", "api2" }
};
```

Enable the JWT bearer client authentication in DI:

```csharp
// Implicitly enabled when using AddJwtBearerClientAuthentication
idsvrBuilder.AddJwtBearerClientAuthentication();
```

### mTLS Client Certificates

```csharp
new Client
{
    ClientId = "mtls.client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    AllowedScopes = { "api1" },
    ClientSecrets =
    {
        new Secret(@"CN=client, OU=production, O=company", "client.dn")
        {
            Type = IdentityServerConstants.SecretTypes.X509CertificateName
        },
        new Secret("bca0d040847f843c5ee0fa6eb494837470155868", "mtls.tb")
        {
            Type = IdentityServerConstants.SecretTypes.X509CertificateThumbprint
        }
    }
}
```

Enable mTLS validators:

```csharp
// Program.cs
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.MutualTls.Enabled = true;
});

idsvrBuilder.AddMutualTlsSecretValidators();
```

### Secret Rollover

Assign multiple secrets to a client for zero-downtime secret rotation:

```csharp
var primary = new Secret("foo");
var secondary = new Secret("bar");

client.ClientSecrets = new[] { primary, secondary };
```

## CORS Configuration

For JavaScript/SPA clients that make cross-origin requests, configure `AllowedCorsOrigins`:

```csharp
var spaClient = new Client
{
    ClientId = "spa",
    AllowedCorsOrigins = { "https://spa.example.com" },
    // ...
};
```

IdentityServer's built-in CORS policy service (both in-memory and EF) uses this property automatically.

## Registering Resources and Clients

```csharp
// Program.cs
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources)  // only if using API Resources
    .AddInMemoryClients(Config.Clients);
```

## Common Pitfalls

1. **Mixing up API Scopes and API Resources** - API Scopes define permissions; API Resources group scopes and add `aud` claims. Start with API Scopes only; add API Resources when you need audience claims or per-API settings.

2. **Forgetting `AllowOfflineAccess`** - Refresh tokens require `AllowOfflineAccess = true` on the client and the `offline_access` scope in the request.

3. **Storing plain text secrets in code** - Secrets should be stored as SHA256 or SHA512 hashes. The `Sha256()` extension is a convenience for demos; never commit clear-text secrets to source control.

4. **No `RedirectUris` for interactive clients** - Authorization code flow requires at least one redirect URI. Requests with unregistered redirect URIs are rejected.

5. **Using `GrantTypes.Implicit`** - The implicit flow is discouraged for security reasons. Use `GrantTypes.Code` with PKCE for all interactive clients including SPAs.

6. **Assuming scopes authorize users** - Scopes authorize clients, not users. User-level authorization must be implemented separately in your APIs.

7. **Not registering identity resources** - If a client requests `openid` or `profile` scopes but no `IdentityResource` is registered for them, the request fails silently or returns no claims.
