# Pre-Migration Analysis: The Duende Migration Analysis Tool

## Yes — Use the Migration Analysis Tool

Before making any code changes, Duende provides a **Migration Analysis Tool** that you can run against your existing IdentityServer4 instance. It inspects your live configuration and produces a detailed report with specific migration recommendations.

## How It Works

The tool is a single file — **`MigrationAnalysisController.cs`** — that you drop into your existing IdentityServer4 project. It does not require any additional NuGet packages.

### Setup

1. Download `MigrationAnalysisController.cs` from the [Duende documentation](https://docs.duendesoftware.com/identityserver/upgrades/identityserver4-upgrade-analysis/)
2. Add it to your IdentityServer4 project
3. **Update the authorization check** in the `Index()` method — the default placeholder checks for username `"scott"`, which you must replace with your own authorization logic
4. Build and run your IdentityServer4 project
5. Navigate to `/MigrationAnalysis` while authenticated

### What the Tool Inspects

| Data Point | What It Tells You |
|------------|------------------|
| **.NET runtime version** | Whether you need to upgrade to a current LTS (.NET 8 or .NET 10) |
| **IdentityServer4 version** | Whether you need Stage 1 (v3 → v4) before proceeding to Duende |
| **Client inventory** | Counts **interactive clients** (authorization_code grant — web apps, SPAs, native apps) vs. **non-interactive clients** (client_credentials — machine-to-machine). This determines which Duende license edition you need. |
| **Issuer URI** | Reports the configured `IssuerUri` — must be preserved in Duende to avoid breaking existing tokens and client trust relationships |
| **Signing credential store type** | Identifies custom signing stores that may need compatibility updates |
| **Signing credential key ID** | Records the current key ID for signing key migration planning |
| **Data protection application name** | Flags missing or path-based discriminators that will break after .NET upgrade. If it shows `(not set)`, you need to configure `SetApplicationName()` |
| **Data protection repository type** | Warns if keys are stored ephemerally (in-memory, lost on restart) instead of a persistent store. If `(not set)`, add `PersistKeysToDbContext` or similar |
| **Authentication schemes** | Lists all registered authentication handlers — flags non-Microsoft, non-IdentityServer4 handlers (e.g., WS-Federation, SAML2P, social providers) that may need version updates for the new ASP.NET Core version |

### Client Store Compatibility

The tool automatically loads clients from:
- In-memory configuration (`AddInMemoryClients`)
- EF Core stores (`AddConfigurationStore`)

If you use a **custom client store** (implementing `IClientStore`), you will need to modify the controller's constructor to wire up your client retrieval.

## What You Get

The report gives you actionable information for planning:
- Whether you can go directly to Duende (v4.x) or need the v3 → v4 intermediate step
- Which Duende license edition matches your client count
- Whether your data protection configuration will survive the .NET upgrade
- Which third-party authentication handlers need package updates
- Your current signing key details for key migration planning

## Additional Resources

Duende also offers a [free IdentityServer4 upgrade assessment](https://duendesoftware.com) to walk through your upgrade path with their team.
