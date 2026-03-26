#!/usr/bin/env bash
set -euo pipefail

# In run-evals.sh, I have code to evaluate the skills in this repo. However, the evals are too much for GitHub Models quota and rate limits. Can you run these evals through one of your subagents, bypassing GitHub Models and using your own? Make sure to write all output files as expected. Next, update the README with a summary.

for dir in tests/*/workspace/iteration-1; do [ -d "$dir" ] && echo "Removing: $dir" && rm -rf "$dir"; done && echo "Done"

./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "aspnetcore-authentication"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "aspnetcore-authorization"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "claims-authorization"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "duende-bff"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identity-security-hardening"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identity-testing-patterns"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-api-protection"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-aspire"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-configuration"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-dcr"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-deployment"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-hosting-setup"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-key-management"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-saml"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-sessions-providers"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-stores"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-token-lifecycle"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-token-security"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "identityserver-ui-flows"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "oauth-oidc-protocols"
./scripts/run-evals.sh --iteration 1 --model "openai/gpt-4.1" --verbose --skill "token-management"
