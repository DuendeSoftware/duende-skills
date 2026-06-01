# IAuthorizationParametersMessageStore Removed in v8

`IAuthorizationParametersMessageStore` has been **removed** in IdentityServer v8. The replacement is **PAR (Pushed Authorization Requests)**.

## What Was It For?

In v7, `IAuthorizationParametersMessageStore` was used to handle large authorization requests that exceeded URL length limits by storing parameters server-side and passing a reference.

## The v8 Replacement: PAR

PAR (Pushed Authorization Requests) is the standards-based replacement. With PAR, clients push their authorization parameters to a dedicated endpoint before redirecting the user:

1. Client POSTs authorization parameters to the PAR endpoint (`/connect/par`)
2. Server returns a `request_uri`
3. Client redirects to the authorize endpoint with just the `request_uri`

## Migration

```csharp
// ❌ Remove — no longer exists in v8
services.AddTransient<IAuthorizationParametersMessageStore, MyStore>();
```

Configure your clients to use PAR instead:

```csharp
new Client
{
    ClientId = "web",
    // Require clients to use PAR
    RequirePushedAuthorization = true,
    // ... other settings
}
```

Or set it globally:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.PushedAuthorization.Required = true;
});
```

## Benefits of PAR Over the Old Approach

- Standards-based (RFC 9126)
- Better security (parameters aren't exposed in the URL)
- Works across all OAuth/OIDC client libraries that support PAR
- No custom server-side store to maintain
