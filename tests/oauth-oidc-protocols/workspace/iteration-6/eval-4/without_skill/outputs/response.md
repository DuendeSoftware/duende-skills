# Implicit flow in a SPA: your colleague is right

**Yes, it's insecure and deprecated.** OAuth 2.0 Security BCP and OAuth 2.1 remove the implicit flow.

## Problems
- Access tokens are returned in the URL fragment: exposed to browser history, extensions, referrer leaks, JS injection.
- No client authentication and no way to bind the token to the client; token injection/replay is easy.
- No refresh tokens, forcing hidden iframe silent renew, which breaks with third-party cookie blocking.
- Any XSS gives full token access.

## What to do instead
### Option 1 (best): BFF pattern
Keep tokens out of the browser. A backend (Backend-for-Frontend) does the code flow as a confidential client, stores tokens server side, issues an HttpOnly, Secure, SameSite cookie to the SPA, and proxies API calls.

```csharp
// Duende.BFF
builder.Services.AddBff();
builder.Services.AddAuthentication(o => { o.DefaultScheme = "cookie"; o.DefaultChallengeScheme = "oidc"; })
  .AddCookie("cookie", o => { o.Cookie.SameSite = SameSiteMode.Strict; })
  .AddOpenIdConnect("oidc", o => {
      o.Authority = "https://identity.example.com";
      o.ClientId = "spa"; o.ClientSecret = "secret";
      o.ResponseType = "code"; o.SaveTokens = true;
      o.Scope.Add("api1"); o.Scope.Add("offline_access");
  });
app.UseBff(); app.UseAuthorization();
app.MapBffManagementEndpoints();
app.MapRemoteBffApiEndpoint("/api", "https://api.example.com").RequireAccessToken();
```

### Option 2: Pure SPA with code + PKCE
Use `response_type=code` with PKCE, `AllowedGrantTypes = GrantTypes.Code`, `RequireClientSecret = false`, strict redirect URIs/CORS, short-lived tokens, refresh token rotation. Tokens still live in JS, so XSS remains a risk.

Migrate: change the client's grant type on IdentityServer, remove `id_token token` response types, and switch your React OIDC library (e.g. oidc-client-ts) to code + PKCE or to BFF cookies.
