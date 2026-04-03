Here's the migrated code using newer Duende BFF conventions:

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
    });

var app = builder.Build();

app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapBffManagementEndpoints();

app.MapRemoteBffApiEndpoint("/api/data", new Uri("https://api.example.com"))
    .RequireAccessToken(TokenType.User);

app.Run();
```

The main change is replacing the manual `AddAuthentication/AddCookie/AddOpenIdConnect` with the fluent `ConfigureOpenIdConnect` and `ConfigureCookies` on the BFF builder.
