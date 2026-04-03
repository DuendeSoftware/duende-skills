# Setting Up Certificate-Based Client Authentication

To use certificate-based authentication instead of shared secrets, you'll need to configure the client with a certificate and set up the server to validate JWT assertions.

## Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
})
    .AddInMemoryIdentityResources(new[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("api1")
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "webapp.jwt",
            AllowedGrantTypes = GrantTypes.Code,

            // Load the certificate
            ClientSecrets =
            {
                new Secret
                {
                    Type = "X509Certificate",
                    Value = Convert.ToBase64String(certificate.RawData)
                }
            },

            RedirectUris = { "https://webapp.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },

            AllowedScopes = { "openid", "profile", "api1" }
        }
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

## Explanation

The client is configured with a certificate-based secret instead of a shared string secret. The `Type` is set to `"X509Certificate"` and the `Value` contains the base64-encoded certificate data.

On the client side, when making a token request, the client creates a JWT assertion signed with its private key and sends it as the `client_assertion` parameter. IdentityServer validates this JWT using the registered public certificate.

This is more secure than shared secrets because the private key never needs to be transmitted. The server only needs the public certificate to validate the assertions.

Make sure to load the certificate from a secure location like the certificate store or a key vault, rather than hardcoding it.
