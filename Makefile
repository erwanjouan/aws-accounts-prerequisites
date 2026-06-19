REGION             ?= eu-west-3
PROFILE_MANAGEMENT ?= management
PROFILE_PRODUCTION ?= production
GITHUB_ORG         ?= erwanjouan
GITHUB_REPO        ?= *
OIDC_STACK_NAME    ?= GitHubOIDC

# ─── File targets ────────────────────────────────────────────────────────────

node_modules: package.json
	npm install
	@touch node_modules

# ─── OIDC setup (run once before the GitHub Actions workflow) ─────────────────

# Deploy the GitHub OIDC provider + IAM role to the management account.
deploy-oidc-management:
	aws cloudformation deploy \
		--template-file cf-github-oidc.yml \
		--stack-name $(OIDC_STACK_NAME) \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameter-overrides GitHubOrg=$(GITHUB_ORG) GitHubRepo=$(GITHUB_REPO) \
		--no-fail-on-empty-changeset \
		--profile $(PROFILE_MANAGEMENT)

# Deploy the GitHub OIDC provider + IAM role to the production account.
deploy-oidc-production:
	aws cloudformation deploy \
		--template-file cf-github-oidc.yml \
		--stack-name $(OIDC_STACK_NAME) \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameter-overrides GitHubOrg=$(GITHUB_ORG) GitHubRepo=$(GITHUB_REPO) \
		--no-fail-on-empty-changeset \
		--profile $(PROFILE_PRODUCTION)

# Deploy to both accounts (management first, though order doesn't matter here).
deploy-oidc: deploy-oidc-management deploy-oidc-production

# ─── CDK bootstrap ────────────────────────────────────────────────────────────

# Bootstrap the management account (CDK staging bucket + roles).
bootstrap-management: node_modules
	npx cdk bootstrap aws://$(MANAGEMENT_ACCOUNT_ID)/$(REGION) \
		--profile $(PROFILE_MANAGEMENT)

# Bootstrap the production account and trust the management account so it can
# deploy stacks there (--trust grants cross-account cdk deploy access).
bootstrap-production: node_modules
	npx cdk bootstrap aws://$(PRODUCTION_ACCOUNT_ID)/$(REGION) \
		--trust $(MANAGEMENT_ACCOUNT_ID) \
		--cloudformation-execution-policies arn:aws:iam::aws:policy/AdministratorAccess \
		--profile $(PROFILE_PRODUCTION)

# Bootstrap both accounts in order (management first so the trust is valid).
bootstrap: bootstrap-management bootstrap-production

.PHONY: deploy-oidc deploy-oidc-management deploy-oidc-production \
        bootstrap bootstrap-management bootstrap-production
