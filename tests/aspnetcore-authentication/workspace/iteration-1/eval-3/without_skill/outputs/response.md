# Combined JWT and Reference Token Validation

To support both JWT and reference tokens, you'll need both JWT Bearer and introspection handlers:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
    })
    .AddOAuth2Introspection("introspection", options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "catalog-api";
        options.ClientSecret = "api-secret";
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.Run();
```

You'll need a way to switch between the two schemes based on the token format. You could use a policy scheme or a forwarding mechanism to detect whether the incoming token is a JWT (starts with `eyJ`) or a reference token and route accordingly.
