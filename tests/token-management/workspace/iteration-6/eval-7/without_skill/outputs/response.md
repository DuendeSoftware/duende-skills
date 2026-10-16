# Problems found

1. **Mixed up token handlers/registrations**: `AddClientCredentialsTokenHandler("catalog.client")` requires `AddClientCredentialsTokenManagement().AddClient("catalog.client", ...)`, which is not registered. Fails at runtime.
2. **Missing `SaveTokens = true`** on OIDC: user tokens are not stored in the cookie, so user token management can't find them.
3. **No `offline_access` scope**: no refresh token, so tokens can't be renewed.
4. **Schemes not set**: `AddAuthentication()` has no default scheme / challenge scheme; "cookie" and "oidc" are never wired.
5. **Secret in code** (`"secret"`): use configuration/secret store.
6. **Manual caching of the token in a field** (`_cachedToken`): defeats expiry/refresh handling, is not thread-safe, and the service may be singleton so it would be shared among users. The library already caches. Always get the token on each call (or use a handler).
7. **Wrong use of the API**: `GetToken()` on a result likely throws on failure; check `WasSuccessful` instead. Also `AccessToken.ToString()` fine, but returning the token from `CallApi` is odd.
8. **Typed client with a user token**: user-based access should use `AddUserAccessTokenHttpClient`/`AddUserAccessTokenHandler`; client credentials handler is for machine calls – pick the right one.
9. **No CancellationToken** passed to calls.
10. **MapInboundClaims / GetClaimsFromUserInfoEndpoint** not configured (minor).

Fix:

```csharp
builder.Services.AddAuthentication(o => { o.DefaultScheme = "cookie"; o.DefaultChallengeScheme = "oidc"; })
    .AddCookie("cookie")
    .AddOpenIdConnect("oidc", o =>
    {
        o.Authority = "https://sts.example.com";
        o.ClientId = "webapp";
        o.ClientSecret = builder.Configuration["Oidc:Secret"];
        o.ResponseType = "code";
        o.SaveTokens = true;
        o.Scope.Add("openid"); o.Scope.Add("api1"); o.Scope.Add("offline_access");
    });
builder.Services.AddOpenIdConnectAccessTokenManagement();
builder.Services.AddClientCredentialsTokenManagement().AddClient("catalog.client", c => { /* ... */ });
builder.Services.AddHttpClient<ApiClient>(c => c.BaseAddress = new Uri("https://api.example.com"))
    .AddClientCredentialsTokenHandler(ClientCredentialsClientName.Parse("catalog.client"));
```
