# Attaching the User's Token to a gRPC Client

Because `AddGrpcClient<T>()` returns an `IHttpClientBuilder`, you can chain Duende's `AddUserAccessTokenHandler()` onto it, just like a regular typed `HttpClient`. That handler adds the signed-in user's access token to each gRPC call. You need OpenID Connect token management configured first.

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// Authentication (cookie + OIDC)
builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie")
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.example.com";
        options.ClientId = "webapp";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.Scope.Add("openid");
        options.Scope.Add("offline_access");
        options.SaveTokens = true;
    });

// Token management (required so the handler can obtain the user's token)
builder.Services.AddOpenIdConnectAccessTokenManagement();

// gRPC client with the user access token handler
builder.Services.AddGrpcClient<Greeter.GreeterClient>(o =>
    {
        o.Address = new Uri("https://grpc.example.com");
    })
    .AddUserAccessTokenHandler();

var app = builder.Build();
app.Run();
```

## Using the client

```csharp
public class GreetingCaller
{
    private readonly Greeter.GreeterClient _client;

    public GreetingCaller(Greeter.GreeterClient client) => _client = client;

    public async Task<string> CallAsync(string name)
    {
        // Token is added to the call automatically
        var reply = await _client.SayHelloAsync(new HelloRequest { Name = name });
        return reply.Message;
    }
}
```

## Notes

- `AddUserAccessTokenHandler()` inserts a delegating handler that fetches the current user's access token from token management and attaches it as a bearer token; expired tokens are refreshed transparently when `offline_access` and `SaveTokens = true` are configured.
- Make sure the gRPC channel uses HTTPS (as above) so the credential isn't sent in the clear.
- If instead you want to call the downstream service as the application itself (machine-to-machine), use a client-credentials handler rather than the user handler.
