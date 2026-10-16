# Implicit flow in a SPA

**Your colleague is right.** Implicit flow (`response_type=token` / `id_token token`) is deprecated.

## Why it's insecure
- Tokens are returned in the URL fragment: exposed to history, extensions, scripts, referrer leaks.
- No PKCE-style binding: a token (or injected response) can be replayed by anyone.
- No client authentication, no refresh tokens (so iframe-based silent renew, which breaks with third-party cookie restrictions).
- An XSS bug lets any script read tokens from JS-accessible storage.

## What to do instead
### Best: Backend-for-Frontend (BFF)
Authorization Code + PKCE runs on a server-side confidential client. Tokens never reach the browser; the SPA gets an HttpOnly, Secure, SameSite cookie and calls APIs through the BFF, which attaches the access token. See the `duende-bff` skill.

```csharp
builder.Services.AddBff();
builder.Services.AddAuthentication(o => { o.DefaultScheme = "cookie"; o.DefaultChallengeScheme = "oidc"; })
    .AddCookie("cookie", o => { o.Cookie.SameSite = SameSiteMode.Strict; o.Cookie.HttpOnly = true; })
    .AddOpenIdConnect("oidc", o =>
    {
        o.Authority = "https://identity.example.com";
        o.ClientId = "react-spa"; o.ClientSecret = "secret";
        o.ResponseType = "code"; o.SaveTokens = true;
        o.Scope.Add("api1"); o.Scope.Add("offline_access");
    });
app.UseAuthentication(); app.UseBff(); app.UseAuthorization();
app.MapBffManagementEndpoints();
app.MapRemoteBffApiEndpoint("/api", "https://api.example.com").RequireAccessToken();
```
Server client config: `AllowedGrantTypes = GrantTypes.Code`, `RequirePkce = true`, `AllowOfflineAccess = true`, `RefreshTokenUsage = TokenUsage.OneTimeOnly`, no implicit.

React calls `/api/...` with cookies (plus an anti-forgery header like `X-CSRF: 1`); login via `/bff/login`.

### Fallback: SPA-only code + PKCE
Keeps tokens in JS, so you accept XSS exposure. Mitigate with short lifetimes, rotated refresh tokens, strict redirect URIs/CORS, and consider DPoP. Prefer BFF.

Migration: change the client to code flow, drop implicit grant, replace the React library flow (or move to BFF cookies).
