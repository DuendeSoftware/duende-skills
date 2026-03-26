# Custom Dynamic Google Provider

To create a custom Google dynamic provider, you need to register a handler and map configuration.

## GoogleIdentityProvider Class

```csharp
public class GoogleIdentityProvider : IdentityProvider
{
    public const string ProviderType = "google";

    public GoogleIdentityProvider() : base(ProviderType) { }

    public string ClientId { get; set; }
    public string ClientSecret { get; set; }
}
```

## Registration

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.DynamicProviders
        .AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>(
            GoogleIdentityProvider.ProviderType);
});
```

## Options Mapper

```csharp
public class GoogleOptionsMapper : IConfigureNamedOptions<GoogleOptions>
{
    private readonly IIdentityProviderStore _store;

    public GoogleOptionsMapper(IIdentityProviderStore store)
    {
        _store = store;
    }

    public void Configure(string name, GoogleOptions options)
    {
        var provider = _store.GetBySchemeAsync(name).GetAwaiter().GetResult();
        if (provider is GoogleIdentityProvider google)
        {
            options.ClientId = google.ClientId;
            options.ClientSecret = google.ClientSecret;
        }
    }

    public void Configure(GoogleOptions options) { }
}
```

Register:
```csharp
builder.Services.ConfigureOptions<GoogleOptionsMapper>();
```