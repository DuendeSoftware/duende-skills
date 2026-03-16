# Pre-Migration Analysis with the Migration Analysis Tool

Yes — Duende provides a **Migration Analysis Tool** (`MigrationAnalysisController.cs`) that you can add to your existing IdentityServer4 project before making any code changes. It inspects your running IdentityServer4 instance and produces a report with specific migration recommendations.

## How to Use It

1. Download `MigrationAnalysisController.cs` from the [Duende documentation](https://docs.duendesoftware.com/identityserver/upgrades/identityserver4-upgrade-analysis/) and add it to your IS4 project
2. Update the authorization check in the `Index()` method (the default checks for username `"scott"`)
3. Build, run, and navigate to `/MigrationAnalysis` while authenticated
4. Review the report

No additional NuGet packages are needed — it works with your existing IS4 dependencies.

## What the Tool Inspects

| Data Point | Why It Matters |
|------------|---------------|
| **.NET runtime version** | Flags if you need to upgrade to a current LTS (.NET 8 or .NET 10) |
| **IdentityServer4 version** | Determines if you need the v3→v4 migration stage first |
| **Client inventory (interactive vs. non-interactive)** | Counts authorization code clients vs. client credentials clients — **this determines which Duende license edition you need** |
| **Issuer URI** | Reports the configured issuer that must be preserved after migration |
| **Signing credential store type and key ID** | Identifies custom signing stores and current key ID for migration planning |
| **Data protection application name** | Flags missing or path-based discriminators that will break after .NET upgrade. Checks whether an explicit `SetApplicationName` is configured or if the default content root path is being used |
| **Data protection repository type** | Warns if keys are stored ephemerally (lost on restart). Flags `(not set)` if no persistent store is configured |
| **Authentication schemes** | Lists all registered authentication handlers. **Flags non-Microsoft, non-IdentityServer4 handlers** (e.g., WS-Federation, SAML2P, custom social providers) that may need NuGet package updates for the new ASP.NET Core version |

The tool automatically loads clients from in-memory configuration or EF Core stores. If you use a custom client store, you'll need to modify the constructor to wire up your client retrieval.

## Recommendation

Run this tool as your first step before any migration work. The output gives you a concrete, data-driven migration plan.
