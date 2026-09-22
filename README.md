# Your app

This repo deploys a container app into **your** resource group via
GitHub Actions. There are no secrets here: the pipeline authenticates to
Azure with OIDC federation.

- Open a PR -> `terraform plan` runs and comments on the PR
- Merge to main -> `terraform apply` deploys

Start with `course/` module 02 in the class material.
