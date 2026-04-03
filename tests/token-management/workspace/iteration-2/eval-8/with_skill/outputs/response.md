# gRPC Client with User Access Token

Here's how to register a gRPC client with Duende.AccessTokenManagement so the current user's access token is automatically attached to all gRPC calls.

## `Program.cs`

```csharp
using Duende.AccessTokenManagement;

var builder = WebApplication.CreateBuilder(args);

// Configure authentication: cookie + OIDC (prerequisite for user token management)
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("cookie", options =>
{
    options.Events.OnSigningOut = async e =>
    {
        await e.HttpContext.RevokeRefreshTokenAsync();
    };
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://sts.example.com";
    options.ClientId = "webapp";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("grpc.api");
    options.Scope.Add("offline_access");
    options.SaveTokens = true;
});

// Register user token management services (prerequisite)
builder.Services.AddOpenIdConnectAccessTokenManagement();

// Register the typed gRPC client with automatic user access token attachment
builder.Services.AddGrpcClient<Greeter.GreeterClient>(o =>
{
    o.Address = new Uri("https://grpc.example.com");
})
.AddUserAccessTokenHandler();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/greet", async (Greeter.GreeterClient grpcClient, CancellationToken ct) =>
{
    // Token is attached automatically by the handler
    var reply = await grpcClient.SayHelloAsync(
        new HelloRequest { Name = "World" },
        cancellationToken: ct);
    return Results.Ok(reply.Message);
}).RequireAuthorization();

app.Run();
```

## Key Points

1. **`AddGrpcClient<T>()`** registers the typed gRPC client with the downstream endpoint address.
2. **`.AddUserAccessTokenHandler()`** chains onto the gRPC client registration to automatically attach the current user's access token to every gRPC call. If the token is expired, it's refreshed silently using the refresh token.
3. **`AddOpenIdConnectAccessTokenManagement()`** is required as a prerequisite — it registers the user token management services that the handler depends on.
4. You can also use `.AddClientAccessTokenHandler()` for gRPC clients that need client credentials tokens instead of user tokens.

## Packages Required

```xml
<PackageReference Include="Duende.AccessTokenManagement.OpenIdConnect" Version="4.0.0" />
<PackageReference Include="Grpc.Net.ClientFactory" Version="2.x.x" />
```
