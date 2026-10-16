```csharp
using Duende.IdentityServer.Validation;

public class TransactionScopeParser : DefaultScopeParser
{
    public TransactionScopeParser(ILogger<DefaultScopeParser> logger) : base(logger) { }

    public override void ParseScopeValue(ParseScopeContext scopeContext)
    {
        const string prefix = "transaction:";
        var value = scopeContext.RawValue;
        if (value.StartsWith(prefix) && value.Length > prefix.Length)
        {
            scopeContext.SetParsedValues("transaction", value[prefix.Length..]);
        }
        else
        {
            base.ParseScopeValue(scopeContext);
        }
    }
}

builder.Services.AddIdentityServer()
    .AddScopeParser<TransactionScopeParser>()
    .AddInMemoryApiScopes(new[] { new ApiScope("transaction") });
```
Profile service:
```csharp
public Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var tx = context.RequestedResources.ParsedScopes
        .Where(s => s.ParsedName == "transaction")
        .Select(s => s.ParsedParameter);
    foreach (var t in tx)
        context.IssuedClaims.Add(new Claim("transaction", t));
    return Task.CompletedTask;
}
```
Register the profile service with `.AddProfileService<MyProfileService>()`. The `ApiScope("transaction")` is the base name that parsed scopes resolve to.
