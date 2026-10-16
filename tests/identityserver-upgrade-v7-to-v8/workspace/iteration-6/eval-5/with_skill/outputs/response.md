# `IAuthorizationParametersMessageStore` → PAR

`IAuthorizationParametersMessageStore` is **removed in v8**. The replacement is **PAR (Pushed Authorization Requests, RFC 9126)**. It is the standards-based way to avoid large authorization request URLs.

## What to do
1. Delete the registration and your implementation:
```csharp
// ❌ remove
services.AddTransient<IAuthorizationParametersMessageStore, MyStore>();
```
2. Have the client push its authorization parameters to the PAR endpoint and send only the `request_uri` on the authorize redirect. To require this for a client, set `require_pushed_authorization_requests` (`RequirePushedAuthorization = true` on the `Client`).
3. In ASP.NET Core clients, the OpenID Connect handler on .NET 9+ supports PAR (`PushedAuthorizationBehavior`). In .NET 10 it is enabled by default when the server advertises the endpoint.

```csharp
new Client
{
    ClientId = "web",
    RequirePushedAuthorization = true,
    ...
}
```

## Notes
- Your login UI keeps working through `IIdentityServerInteractionService.GetAuthorizationContextAsync(returnUrl)`. It doesn't need the old message store.
- v8 also requires `net10.0`, the 8.x packages, and `CancellationToken` on custom stores.
