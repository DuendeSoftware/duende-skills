---
name: identityserver-ui-flows
description: "Guide for building login, logout, consent, error, and federation gateway UI pages in Duende IdentityServer, including IIdentityServerInteractionService usage, external provider integration, and Home Realm Discovery strategies."
invocable: false
---

# IdentityServer UI Flows: Login, Logout, Consent, and Federation

## When to Use This Skill

- Building or customizing the login page (local credentials, MFA, passwordless)
- Integrating external identity providers (Google, Azure AD, SAML, etc.)
- Implementing the consent page for third-party client authorization
- Building the logout flow with session cleanup and client notifications
- Implementing a federation gateway with Home Realm Discovery (HRD)
- Handling and displaying error pages for protocol errors
- Using `IIdentityServerInteractionService` to interact with the protocol engine
- Redirecting users back to clients after login/logout

Docs: https://docs.duendesoftware.com/identityserver/ui

## Architecture Overview

IdentityServer separates the protocol engine from the user interface. The engine handles OAuth/OIDC endpoints and redirects to your UI pages as needed. Your UI code handles all user interaction and then communicates results back to the engine.

```
Browser → IdentityServer Middleware → UI Pages (Login, Consent, Logout, Error)
                                          ↕
                                   IIdentityServerInteractionService
                                          ↕
                                   IdentityServer Protocol Engine
```

### Required Pages

| Page    | Purpose                               | Default URL                               |
| ------- | ------------------------------------- | ----------------------------------------- |
| Login   | Establish authentication session      | Inferred from cookie handler `LoginPath`  |
| Logout  | Terminate session, notify clients     | Set via `opt.UserInteraction.LogoutUrl`   |
| Consent | Grant/deny client access to resources | `/consent`                                |
| Error   | Display protocol error information    | `/home/error`                             |

## Login Page

### Configuring the Login URL

```csharp
// Program.cs — explicit configuration
builder.Services.AddIdentityServer(opt => {
    opt.UserInteraction.LoginUrl = "/path/to/login";
});
```

If not set, IdentityServer infers the URL from the cookie handler's `LoginPath`:

```csharp
// Program.cs — with ASP.NET Identity
builder.Services.AddIdentityServer()
    .AddAspNetIdentity<ApplicationUser>();

builder.Services.ConfigureApplicationCookie(options =>
{
    options.LoginPath = "/path/to/login/for/aspnet_identity";
});
```

### Authorization Context

When IdentityServer redirects to the login page, it passes a `returnUrl` query parameter. Use `IIdentityServerInteractionService.GetAuthorizationContextAsync` to extract the original authorization request parameters:

```csharp
public class LoginModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public LoginModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

        // context contains:
        // - Client (the requesting client)
        // - IdP (requested identity provider hint)
        // - AcrValues (requested authentication context)
        // - Tenant (requested tenant)
        // - LoginHint (suggested username)
        // - Parameters (raw protocol parameters)

        // Use context for branding, HRD, MFA decisions, etc.
    }
}
```

**Important**: Do not parse the `returnUrl` yourself. Always use the interaction service.

### Establishing the Authentication Session

After validating credentials, create the authentication session:

```csharp
var user = new IdentityServerUser("unique_id_for_your_user")
{
    DisplayName = "Bob Smith"
};

await HttpContext.SignInAsync(user);

// Redirect back to the authorization endpoint
return Redirect(returnUrl);
```

Or with explicit claims:

```csharp
var claims = new Claim[] {
    new Claim("sub", "unique_id_for_your_user"),
    new Claim("name", "Bob Smith"),
    new Claim("amr", "pwd"),
    new Claim("idp", "local")
};
var identity = new ClaimsIdentity(claims, "pwd");
var principal = new ClaimsPrincipal(identity);

await HttpContext.SignInAsync(principal);
```

### Well-Known Session Claims

| Claim       | Purpose                                                                   | Default                    |
| ----------- | ------------------------------------------------------------------------- | -------------------------- |
| `sub`       | **Required.** Unique user identifier. Must never change or be reassigned. | None — you must provide it |
| `name`      | Display name of the user                                                  | None                       |
| `amr`       | Authentication method reference                                           | `pwd`                      |
| `auth_time` | Time user entered credentials (epoch)                                     | Current time               |
| `idp`       | Identity provider scheme name                                             | `local`                    |
| `tenant`    | Tenant identifier                                                         | None                       |

### Protecting Against Open Redirects

Always validate the `returnUrl` before redirecting:

```csharp
// Option 1: Use ASP.NET Core helper
if (Url.IsLocalUrl(returnUrl))
{
    return Redirect(returnUrl);
}

// Option 2: Use IdentityServer interaction service
if (await _interaction.IsValidReturnUrl(returnUrl))
{
    return Redirect(returnUrl);
}
```

### Completing Login with CompleteLoginAsync

After establishing the authentication session, redirect the user back to the `returnUrl`. This causes the browser to re-issue the original authorize request, allowing IdentityServer to complete the protocol workflow.

## External Login (Federation)

### Registering External Providers

```csharp
// Program.cs
builder.Services.AddIdentityServer();

builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Employee Login", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        // configure authority, client ID, etc.
    });
```

### Triggering External Authentication

```csharp
var callbackUrl = Url.Action("MyCallback");

var props = new AuthenticationProperties
{
    RedirectUri = callbackUrl,
    Items =
    {
        { "scheme", "AAD" },
        { "returnUrl", returnUrl }
    }
};

return Challenge("AAD", props);
```

### Handling the Callback

```csharp
// 1. Read external identity from temporary cookie
var result = await HttpContext.AuthenticateAsync(
    IdentityServerConstants.ExternalCookieAuthenticationScheme);

if (result?.Succeeded != true)
    throw new Exception("External authentication error");

var externalUser = result.Principal;
var userId = externalUser.FindFirst("sub").Value;
var scheme = result.Properties.Items["scheme"];
var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";

// 2. Find or provision local user
var user = FindUserFromExternalProvider(scheme, userId);

// 3. Establish session
await HttpContext.SignInAsync(new IdentityServerUser(user.SubjectId)
{
    DisplayName = user.DisplayName,
    IdentityProvider = scheme
});

// 4. Clean up external cookie
await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

// 5. Return to protocol processing
return Redirect(returnUrl);
```

### SignInScheme and SignOutScheme

| Scenario                 | SignInScheme                                                 | SignOutScheme                           |
| ------------------------ | ------------------------------------------------------------ | --------------------------------------- |
| Without ASP.NET Identity | `IdentityServerConstants.ExternalCookieAuthenticationScheme` | `IdentityServerConstants.SignoutScheme` |
| With ASP.NET Identity    | `IdentityServerConstants.ExternalCookieAuthenticationScheme` | `IdentityConstants.ApplicationScheme`   |

### State and URL Length

If external provider state makes the URL too long (>2000 chars), use the IdentityServer-provided `IDistributedCache`-backed data format:

```csharp
// Program.cs — all OIDC handlers use server-side state
builder.Services.AddOidcStateDataFormatterCache();

// Or specific schemes only
builder.Services.AddOidcStateDataFormatterCache("aad", "demoidsrv");
```

## Logout Page

### Configuring the Logout URL

```csharp
// Program.cs
builder.Services.AddIdentityServer(opt => {
    opt.UserInteraction.LogoutUrl = "/path/to/logout";
});
```

### Logout Steps

1. **End the IdentityServer session** — remove the authentication cookie
2. **Sign out of external provider** — if an external login was used
3. **Notify client applications** — via front-channel, back-channel, or JS-based notifications
4. **Redirect back to client** — if the logout is client-initiated

### Client Notification Mechanisms

| Mechanism     | How It Works                                                         | Client Setting                       |
| ------------- | -------------------------------------------------------------------- | ------------------------------------ |
| Front-channel | Render `<iframe>` on logged-out page pointing to client's logout URI | `FrontChannelLogoutUri`              |
| Back-channel  | Server-to-server HTTP call with a logout JWT (`typ: logout+jwt`)     | `BackChannelLogoutUri`               |
| JS-based      | Client monitors `check_session_iframe`                               | Built into spec-compliant JS clients |

**Recommendation**: Use back-channel notifications for cross-site architectures. Front-channel and JS-based notifications rely on cookies in iframes, which may not work reliably across different sites.

### Getting Logout Context

```csharp
var context = await _interaction.GetLogoutContextAsync(logoutId);

// context.SignOutIFrameUrl — render in <iframe> for front-channel logout
// context.PostLogoutRedirectUri — where to send the user after logout
```

### Back-Channel Logout

Back-channel logout happens automatically when you call `HttpContext.SignOutAsync()` — IdentityServer uses `IBackChannelLogoutService` to notify all clients that have `BackChannelLogoutUri` configured.

For .NET clients: use the BFF framework which has built-in back-channel logout support, or see the IdentityServer samples.

## Consent Page

### When Consent Is Required

Consent applies **only to user-based (interactive) authorization requests**. Client-credentials (M2M) flows never prompt for consent — there `Client.AllowedScopes` alone governs access.

Consent is controlled per client via `RequireConsent` (default: `false`). Set `RequireConsent = false` for first-party clients to suppress the scope prompt; set `true` for third-party clients. When enabled, IdentityServer redirects to the consent page before completing authorization.

The `offline_access` scope always triggers consent when the client has consent enabled.

### Required vs. Optional Scopes

`IdentityResource` and `ApiScope` expose a `Required` bool:

- If the consent response **omits a `Required` scope**, IdentityServer returns `access_denied` and the request fails.
- **Optional** scopes can be declined and the flow still succeeds — the issued tokens/userinfo simply omit that data.

```csharp
new IdentityResource("profile", /* ... */) { Required = true }; // cannot be declined
new ApiScope("api.read") { Required = false };                  // may be declined
```

### Remembered Consent

Enable persistence with `Client.AllowRememberConsent` (bool) and `Client.ConsentLifetime` (expiry). Granted scopes are stored in the operational (persisted grant) store; set `RememberConsent = true` on the `ConsentResponse` to persist a grant.

IdentityServer **re-prompts** for consent when:

- there is no remembered consent, or it has expired,
- a new, not-previously-granted scope is requested,
- the request includes `offline_access`,
- the request contains a parameterized scope value, or
- `AllowRememberConsent = false`.

**Device flow**: in IdentityServer v8, device-flow (Device Authorization Grant) consent is **never remembered** — the user consents on every device authorization.

### Revoking Consent

Use `IIdentityServerInteractionService.RevokeUserConsentAsync(clientId)` for the current user. This removes **all** persisted grants for that user/client — remembered consent, reference tokens, and refresh tokens.

```csharp
await _interaction.RevokeUserConsentAsync("web.app");
```

### Consent Page Flow

```csharp
// 1. Get authorization context
var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

// 2. Show user: client info, requested scopes/resources
// context.Client — the requesting client
// Use IClientStore and IResourceStore for additional details

// 3. User grants or denies consent
await _interaction.GrantConsentAsync(context, new ConsentResponse
{
    ScopesValuesConsented = new[] { "openid", "profile", "api1" },
    RememberConsent = true  // persist for future requests
});

// 4. Redirect back
return Redirect(returnUrl);
```

### Denying Consent

```csharp
await _interaction.DenyAuthorizationAsync(context, AuthorizationError.AccessDenied);
```

### Validating returnUrl

```csharp
// Use interaction service
if (await _interaction.IsValidReturnUrl(returnUrl))
{
    return Redirect(returnUrl);
}
// Or check if GetAuthorizationContextAsync returns non-null
```

## User Registration (prompt=create)

The `prompt=create` OIDC parameter sends the user straight to a registration page instead of login.

### Host Configuration

Set `CreateAccountUrl` in `AddIdentityServer`. This makes IdentityServer advertise `create` in `prompt_values_supported` in discovery. If unset, `prompt=create` is **ignored and not advertised**.

```csharp
// Program.cs
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.CreateAccountUrl = "/Account/Register";
});
```

`prompt=create` must be the **only** prompt value — it cannot be combined with `login`, `consent`, `select_account`, or `none`.

### Triggering Registration from an ASP.NET Core Client

```csharp
return Results.Challenge(
    new OpenIdConnectChallengeProperties { Prompt = "create", RedirectUri = "/" },
    ["oidc"]);
```

### Registration Page Handler (Host)

```csharp
public async Task<IActionResult> OnPost(string returnUrl, CancellationToken ct)
{
    // Returns null for an invalid returnUrl → prevents open redirect
    var context = await _interaction.GetAuthorizationContextAsync(returnUrl, ct);
    if (context is null) return Redirect("~/");

    // Create + persist the local user
    var user = await _users.CreateAsync(/* ... */);

    // Sign in ONLY after email confirmation / approval / MFA — not on submit
    await HttpContext.SignInAsync(new IdentityServerUser(user.SubjectId));

    return Redirect(returnUrl);
}
```

**Important**: `GetAuthorizationContextAsync` returning `null` signals an invalid `returnUrl` — redirect away instead of trusting it. Establish the session only after any required confirmation/approval/MFA step.

## Error Page

### Configuration

```csharp
// Program.cs
builder.Services.AddIdentityServer(opt => {
    opt.UserInteraction.ErrorUrl = "/path/to/error";
    opt.UserInteraction.ErrorIdParameter = "errorId"; // query string parameter name; default: "errorId"
});
```

### Retrieving Error Details

```csharp
var errorContext = await _interaction.GetErrorContextAsync(errorId);

// errorContext contains:
// - Error (error code)
// - ErrorDescription
// - RequestId
// - ClientId
// - DisplayMode
// - UiLocales
```

Errors are commonly due to misconfiguration. The error page should inform the user something went wrong without exposing sensitive details.

### Errors Returned to the Client vs. Error Page

Not every authorize-endpoint error reaches your error page. A fixed set of "safe" codes is sent to the client's `redirect_uri` (honoring the response mode) with `error`, `error_description` and `state`:
`login_required`, `consent_required`, `interaction_required`, `account_selection_required`, `access_denied`, `temporarily_unavailable`, `unmet_authentication_requirements` (RFC 9470 step-up).

Everything else (`invalid_request`, `unauthorized_client`, `unsupported_response_type`, `invalid_scope`, `invalid_target`, `invalid_request_uri`, `invalid_request_object`, `request_uri_not_supported`, `server_error`, and any custom code) shows the error page, because the request isn't trustworthy enough to redirect to (prevents open redirects). The set of safe codes is not configurable. Clients using `prompt=none` must handle `login_required` in their callback.

A custom `AuthorizeInteractionResponseGenerator` can return an error by setting `InteractionResponse.Error` (and optionally `ErrorDescription`); `IsError` is `Error != null`. It's routed by the same rule, so a custom string shows the error page, while e.g. `unmet_authentication_requirements` goes to the client.

## Federation Gateway and Home Realm Discovery

### What Is a Federation Gateway?

A federation gateway architecture shields clients from authentication complexity. Clients trust only IdentityServer; the gateway coordinates with external providers, handling protocol bridging (OIDC, SAML, WS-Fed), claim transformation, and trust management.

### Home Realm Discovery (HRD) Strategies

| Strategy                       | Description                                        | Best For                               |
| ------------------------------ | -------------------------------------------------- | -------------------------------------- |
| Show all providers             | Present a list of available authentication methods | Simple setups with few providers       |
| Email/identifier-based         | Ask for email, infer provider from domain          | SaaS with corporate federation         |
| Client hint via `acr_values`   | Client passes `idp:provider_name`                  | Known provider per client/URL          |
| `IdentityProviderRestrictions` | Restrict available providers per client            | Multi-tenant with per-client providers |

### Restricting Providers Per Client

```csharp
var client = new Client
{
    ClientId = "tenant_a_app",
    IdentityProviderRestrictions = { "AAD", "local" }
    // Only Azure AD and local login are available
};
```

### HRD via acr_values

Clients can hint at the desired provider:

```
GET /connect/authorize?
    client_id=app&
    acr_values=idp:AAD&
    ...
```

Your login page checks `context.IdP` from `GetAuthorizationContextAsync` and can skip the login UI entirely, redirecting straight to the external provider.

Details:
- `acr_values` is space-separated, so hints combine: `acr_values=idp:Google tenant:acme` → `AuthorizationRequest.IdP` / `.Tenant`. Well-known values are removed from `AcrValues`.
- IdentityServer does **not** redirect or verify the scheme exists; the login page must challenge `context.IdP` after checking `IAuthenticationSchemeProvider.GetSchemeAsync(context.IdP)` (this also resolves dynamic providers). The quickstart UI does this.
- If the client has `IdentityProviderRestrictions` and the idp isn't allowed, it's dropped (`context.IdP` null, no error).
- If the session came from a different idp, the login page is shown again.
- `idp:local` (`IdentityServerConstants.LocalIdentityProvider`) is reserved: show only the local login form.
- From the ASP.NET Core OIDC handler / BFF, set it in `OnRedirectToIdentityProvider`: `ctx.ProtocolMessage.AcrValues = "idp:Google";`

### Tenant Hints (`acr_values=tenant:...`)

The client may pass `tenant:acme` in `acr_values`. It's an **untrusted hint** exposed as `AuthorizationRequest.Tenant` (also on CIBA `BackchannelUserLoginRequest.Tenant`, and SAML `AuthnContextClassRef`; not processed at the token endpoint). Use it for branding, scoping user lookup, or HRD; always verify the signed-in user belongs to the tenant.

```csharp
var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
var tenant = context?.Tenant;   // null when not requested

var isuser = new IdentityServerUser(user.SubjectId) { DisplayName = user.Username, Tenant = tenant };
await HttpContext.SignInAsync(isuser);   // issues the `tenant` session claim (cookie only; emit via profile service for tokens)
```

By default a signed-in user is reused even if a different tenant is requested. Set `options.ValidateTenantOnAuthorization = true` to re-show the login page when the requested tenant differs from the session's `tenant` claim (or the session has none). The tenant hint is **not** Spaces: Spaces are selected by the server from origin/path, isolate data and issuers, and are never selected via `acr_values` (see `identityserver-spaces`).

## Common Anti-Patterns

- ❌ Parsing `returnUrl` manually to extract authorization parameters
- ✅ Use `IIdentityServerInteractionService.GetAuthorizationContextAsync(returnUrl)`

- ❌ Redirecting to `returnUrl` without validation, enabling open redirect attacks
- ✅ Validate with `Url.IsLocalUrl()` or `_interaction.IsValidReturnUrl()`

- ❌ Forgetting to delete the external authentication cookie after callback processing
- ✅ Always call `HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme)`

- ❌ Using front-channel logout across different sites/domains (cookie/iframe issues)
- ✅ Use back-channel logout for cross-site architectures

- ❌ Issuing the authentication session without a `sub` claim
- ✅ The `sub` claim is required — it uniquely identifies the user and must never change

- ❌ Trusting the `tenant:` acr value as proof of tenant membership
- ✅ Treat it as a hint and verify membership server-side (or use Spaces for real isolation)

- ❌ Hardcoding external provider list without checking both static schemes and dynamic providers
- ✅ Query `IAuthenticationSchemeProvider` for static schemes and `IIdentityProviderStore` for dynamic providers

## Common Pitfalls

1. **Login page does not preserve `returnUrl`**: The `returnUrl` must survive across all page transitions (post-backs, external redirects, MFA steps). Store it in hidden form fields, route data, or the `AuthenticationProperties.Items` dictionary.

2. **Cookie handler `LoginPath` mismatch**: If no explicit `LoginUrl` is configured, IdentityServer infers it from the cookie handler's `LoginPath`. Make sure the cookie handler `LoginPath` matches your actual login page route. The `LogoutUrl` is not inferred from the cookie handler — it must always be set explicitly via `opt.UserInteraction.LogoutUrl`.

3. **SignOutScheme differs with ASP.NET Identity**: When using ASP.NET Identity, the `SignOutScheme` for external providers should be `IdentityConstants.ApplicationScheme`, not `IdentityServerConstants.SignoutScheme`.

4. **Consent persistence is temporary by default**: The consent result between the consent page and authorization endpoint is stored in a cookie. For custom persistence, implement `IConsentMessageStore`.

5. **Error messages are deliberately brief**: For security, error messages returned to clients are minimal. Check the IdentityServer logs (at `Debug` level) for full error details.

6. **External provider `sub` is provider-specific**: The `sub` claim from an external provider is that provider's unique ID. Map it to your local user database — do not use it directly as the IdentityServer `sub`.
