```csharp
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("my.client", c =>
    {
        c.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        c.ClientId = ClientId.Parse("worker");
        c.ClientSecret = ClientSecret.Parse("secret");
        c.Scope = Scope.Parse("api1");
    });

builder.Services.AddClientCredentialsHttpClient("api", ClientCredentialsClientName.Parse("my.client"),
    c => c.BaseAddress = new Uri("https://api.example.com/"));
```
Then `factory.CreateClient("api")`; the token is acquired, cached and attached automatically.
