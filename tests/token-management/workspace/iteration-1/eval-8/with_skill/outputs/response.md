# gRPC Client with User Access Token — Duende.AccessTokenManagement

To call a downstream gRPC endpoint using the current user's access token with automatic token management, you need:

1. **Duende.AccessTokenManagement.OpenIdConnect** for user token management
2. **Grpc.Net.ClientFactory** for gRPC client factory integration
3. The `.AddUserAccessTokenHandler()` extension on the gRPC client registration

## Package References

```xml
<PackageReference Include="Duende.AccessTokenManagement.OpenIdConnect" Version="4.*" />
<PackageReference Include="Grpc.Net.ClientFactory" Version="2.*" />
<PackageReference Include="Google.Protobuf" Version="3.*" />
<PackageReference Include="Grpc.Tools" Version="2.*" PrivateAssets="All" />
```

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// Authentication setup (cookie + OIDC)
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("cookie", options =>
{
    options.Cookie.Name = "web";
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
    options.SaveTokens = true; // Required for user token management
});

// Register user token management
builder.Services.AddOpenIdConnectAccessTokenManagement();

// Register typed gRPC client with user access token handler
builder.Services.AddGrpcClient<Greeter.GreeterClient>(o =>
{
    o.Address = new Uri("https://grpc.example.com");
})
.AddUserAccessTokenHandler();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/greet", async (Greeter.GreeterClient grpcClient) =>
{
    // Token is attached automatically by the handler
    var reply = await grpcClient.SayHelloAsync(new HelloRequest { Name = "World" });
    return Results.Ok(reply.Message);
}).RequireAuthorization();

app.Run();
```

## How It Works

1. **`AddOpenIdConnectAccessTokenManagement()`** registers the user token management services that handle access token retrieval, caching, and refresh token rotation.

2. **`AddGrpcClient<T>()`** registers the typed gRPC client with the gRPC client factory (from `Grpc.Net.ClientFactory`), specifying the downstream service address.

3. **`.AddUserAccessTokenHandler()`** chains a delegating handler onto the gRPC client's HTTP pipeline that:
   - Retrieves the current user's access token from the authentication session
   - Attaches it as a Bearer token to outgoing gRPC requests
   - Automatically refreshes the token using the refresh token if it has expired

This works identically to how `AddUserAccessTokenHandler()` works on regular HTTP clients — gRPC clients in .NET use `HttpClient` under the hood, so the same delegating handler pattern applies.

## Client Credentials Alternative

If you need machine-to-machine authentication for gRPC (no user context), use `AddClientAccessTokenHandler()` instead:

```csharp
builder.Services.AddGrpcClient<Inventory.InventoryClient>(o =>
{
    o.Address = new Uri("https://grpc.example.com");
})
.AddClientAccessTokenHandler();
```
