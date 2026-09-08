# Analyze your IdentityServer4 configuration before migrating

Yes — before changing any code, use Duende's **Migration Analysis Tool**. It inspects your **running** IdentityServer4 instance and produces a report with concrete migration recommendations.

## What it is

The tool is a single file, **`MigrationAnalysisController.cs`**, that you drop into your existing IdentityServer4 project. It needs no additional NuGet packages. Once added, you build, run, and browse to **`/MigrationAnalysis`** while authenticated to see the report.

Because it runs inside your live IS4 app, it reads your **actual, effective configuration** (clients from in-memory or EF Core stores, options, registered services) rather than guessing from static files.

## What it inspects and why it matters

| Data point | Why it matters |
|------------|---------------|
| **.NET runtime version** | Flags whether you need to upgrade the target framework (you're on `netcoreapp3.1`, so yes) |
| **IdentityServer4 version** | Determines whether you need the v3→v4 stage first |
| **Client inventory** | Counts **interactive** (authorization_code) vs. **non-interactive** (client_credentials) clients — this drives **which Duende license edition** you need |
| **Issuer URI** | Reports the configured (or inferred) issuer so you can preserve it and avoid breaking existing tokens |
| **Signing credential store & key ID** | Identifies custom signing stores and records the current key for signing-key migration planning |
| **Data protection application name** | Flags a missing or path-based **application discriminator** that will break after the .NET upgrade |
| **Data protection repository type** | Warns if keys are stored ephemerally (in-memory, lost on restart) instead of a persistent store |
| **Authentication schemes** | Lists all registered auth handlers and flags third-party ones that may need version updates for the new ASP.NET Core version |

## How to use it

1. Download `MigrationAnalysisController.cs` and add it to your IdentityServer4 project.
2. **Replace the placeholder authorization check** in the `Index()` method — the default sample checks for username `"scott"`; swap in your own authorization logic so the report isn't publicly accessible.
3. Build, run, and navigate to `/MigrationAnalysis` while authenticated.
4. Review the report and use it to plan the migration (framework upgrade, license edition, issuer preservation, data protection, auth handler updates).

If you use a custom client store, you may need to tweak the constructor to wire up your client retrieval so the client inventory is accurate.

> Duende also offers a **free IdentityServer4 upgrade assessment** to walk through your specific upgrade path.
