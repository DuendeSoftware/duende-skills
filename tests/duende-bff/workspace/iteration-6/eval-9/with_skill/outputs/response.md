# V3 → V4 migration

```csharp
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "spa";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.Scope.Add("api1");
        options.Scope.Add("offline_access");  // needed for token refresh
        options.SaveTokens = true;
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.Name = "__Host-bff";
        options.Cookie.SameSite = SameSiteMode.Strict; // Lax if IDP is cross-site
    })
    .AddRemoteApis();

var app = builder.Build();
app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// MapBffManagementEndpoints() removed — auto-registered in v4

app.MapRemoteBffApiEndpoint("/api/data", new Uri("https://api.example.com"))
    .WithAccessToken(RequiredTokenType.User);

app.Run();
```

What changed:
- Manual `AddAuthentication`/`AddCookie`/`AddOpenIdConnect` → `ConfigureOpenIdConnect()` / `ConfigureCookies()`; v4 wires schemes for you.
- `MapBffManagementEndpoints()` is no longer needed.
- `.RequireAccessToken(TokenType.User)` → `.WithAccessToken(RequiredTokenType.User)`.
- Remote APIs need `.AddRemoteApis()` and `Duende.BFF.Yarp`.
- `UseBff()` stays between `UseRouting`/`UseAuthentication` and `UseAuthorization` (v4 can auto-register middleware; `AutomaticallyRegisterBffMiddleware`).
- If you used `EnableSessionCleanup`, replace with `.AddSessionCleanupBackgroundProcess()`; `DefaultAccessTokenRetriever` subclasses must implement `IAccessTokenRetriever`.
