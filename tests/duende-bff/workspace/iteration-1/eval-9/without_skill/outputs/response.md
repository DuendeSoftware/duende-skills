# Upgrading Duende BFF V3 to V4

Here are the key changes for migrating your BFF setup to V4:

## Updated Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// V4 uses the fluent API — replace manual auth setup with ConfigureOpenIdConnect
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
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapBffManagementEndpoints();
app.MapRemoteBffApiEndpoint("/api/data", new Uri("https://api.example.com"))
    .RequireAccessToken(TokenType.User);

app.Run();
```

## Changes Made

1. **Replaced `AddAuthentication().AddCookie().AddOpenIdConnect()`** with `AddBff().ConfigureOpenIdConnect().ConfigureCookies()` — V4's fluent API handles the authentication scheme wiring automatically with recommended defaults.

2. **Added `UseRouting()`** before `UseAuthentication()` — required for correct middleware ordering.

3. **Preserved all original settings** — Authority, ClientId, ClientSecret, ResponseType, scopes, SaveTokens, cookie name, and SameSite mode.

4. I've kept `MapBffManagementEndpoints()` and the remote API endpoint syntax as-is. Check the V4 release notes for any additional changes to these APIs.
