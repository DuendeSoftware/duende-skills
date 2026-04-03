# Migration Analysis Tool

Yes — Duende provides a **Migration Analysis Tool** (`MigrationAnalysisController.cs`) that you add to your running IdentityServer4 project before making any code changes. It inspects your live configuration and produces a report with specific migration recommendations.

## How to Use It

1. Download `MigrationAnalysisController.cs` and add it to your existing IdentityServer4 project
2. Update the authorization check in the `Index()` method (the default checks for username `"scott"` — replace with your own authorization logic)
3. Build, run, and navigate to `/MigrationAnalysis` while authenticated
4. Review the report

The tool does not require additional NuGet packages — it's a single file that works with your existing IdentityServer4 setup.

## What the Tool Inspects

| Data Point | Why It Matters |
|---|---|
| **.NET runtime version** | Flags if you need to upgrade to .NET 8 or .NET 10 |
| **IdentityServer4 version** | Determines if v3 → v4 migration is needed first |
| **Client inventory** | Counts **interactive clients** (authorization_code) vs. **non-interactive clients** (client_credentials) — this determines which Duende license edition you need |
| **Issuer URI** | Reports the configured issuer so you can preserve it in Duende |
| **Signing credential store type** | Identifies custom signing stores that may need updates |
| **Signing credential key ID** | Records the current key ID for signing key migration planning |
| **Data protection application name** | Flags missing or path-based discriminators that will break after .NET upgrade |
| **Data protection repository type** | Warns if keys are stored ephemerally (lost on restart) |
| **Authentication schemes** | Lists all registered authentication handlers — third-party handlers may need version updates for the new ASP.NET Core version |

The tool loads clients from in-memory configuration or EF Core stores automatically.

Duende also offers a [free IdentityServer4 upgrade assessment](https://duendesoftware.com) to walk through your upgrade path.
