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
        options.SaveTokens = true;
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.Name = "__Host-bff";
        options.Cookie.SameSite = SameSiteMode.Strict;
    })
    .AddRemoteApis();

var app = builder.Build();
app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapBffManagementEndpoints();
app.MapRemoteBffApiEndpoint("/api/data", new Uri("https://api.example.com"))
    .WithAccessToken(RequiredTokenType.User);
app.Run();
```

Changes:
- Remove manual `AddAuthentication/AddCookie/AddOpenIdConnect`; BFF v4 registers them with schemes and defaults. Use `ConfigureOpenIdConnect`/`ConfigureCookies`.
- `.RequireAccessToken(TokenType.User)` → `.WithAccessToken(RequiredTokenType.User)`.
- `AddRemoteApis()` needed for YARP proxy features.
- Keep `UseAuthentication`, `UseBff`, `UseAuthorization` in order.
