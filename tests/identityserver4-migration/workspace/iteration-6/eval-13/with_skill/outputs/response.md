**Yes — Duende provides a Migration Analysis Tool.** It's a single file, `MigrationAnalysisController.cs` (from the Duende docs, "IdentityServer4 upgrade analysis"), that you drop into your existing IdentityServer4 project. No extra NuGet packages are needed.

### Using it
1. Add the file to your IS4 project.
2. Update the authorization check in `Index()` — the placeholder checks for username `"scott"`; replace it with your own logic (don't leave the report exposed).
3. Build, run, and navigate to `/MigrationAnalysis` while authenticated.
4. Use the report to plan. It loads clients from in-memory config or EF stores; with a custom client store you must wire up retrieval in the constructor.

### What it reports
| Data point | Why it matters |
|---|---|
| .NET runtime version | Whether you need to upgrade (net8.0 for v7, net10.0 for v8) |
| IdentityServer4 version | Whether a v3 → v4 stage is needed first |
| Client inventory (interactive vs. non-interactive) | Determines the Duende license edition |
| Issuer URI | Must be preserved so tokens and client trust still work |
| Signing credential store type / key ID | Plan signing key migration |
| Data protection application name | Flags missing or path-based discriminators that break after .NET upgrade |
| Data protection repository type | Warns if keys are ephemeral (`(not set)`) |
| Authentication schemes | Lists third-party handlers that may need version updates |

For your sample (netcoreapp3.1, `AddDeveloperSigningCredential`, EF stores, no explicit issuer), expect flags for: framework upgrade, dev signing key, issuer inference, and data-protection settings. Duende also offers a free IdentityServer4 upgrade assessment.
