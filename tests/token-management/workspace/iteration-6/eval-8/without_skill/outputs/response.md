# gRPC client with the user's access token

Use the gRPC client factory and attach the token handler of Duende.AccessTokenManagement.

```csharp
builder.Services.AddOpenIdConnectAccessTokenManagement();

builder.Services.AddGrpcClient<Greeter.GreeterClient>(o =>
{
    o.Address = new Uri("https://grpc.example.com");
})
.AddUserAccessTokenHandler();
```

`AddUserAccessTokenHandler()` adds a `DelegatingHandler` that gets the current user's token via `IUserTokenManager` (refreshing it if needed) and sets the `Authorization: Bearer` header on the underlying HTTP/2 request, which gRPC uses, so no per-call credentials are needed.

Requirements: the host must have cookie + OIDC authentication with `SaveTokens = true` and `offline_access`, and the call must happen within a request with an authenticated `HttpContext`. For a purely machine-to-machine call use `.AddClientCredentialsTokenHandler("client-name")` instead.

Inject `Greeter.GreeterClient` into your service as usual.
