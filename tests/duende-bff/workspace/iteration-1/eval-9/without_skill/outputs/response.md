# Migrating BFF to V4

Here's the updated code for BFF v4:

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

This migrates to the v4 fluent API for OIDC configuration.
