# Separate DCR Host

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServerConfiguration(options =>
{
    options.IdentityServerBaseUrl = "https://identity.example.com";
});

builder.Services.AddAuthentication()
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapDynamicClientRegistration()
    .RequireAuthorization();

app.Run();
```

This creates a separate application that handles DCR while the main IdentityServer handles everything else. Make sure both applications can access the same client store.
