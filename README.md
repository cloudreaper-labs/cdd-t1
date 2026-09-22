# Your team's app

This repository **is** your team's web app. Everything it runs in Azure is
described in the Terraform files here, and GitHub Actions deploys it for you.
You never run `terraform` on your own laptop, and there is no password or
secret anywhere in this repo.

Your whole team shares this repo and one Azure resource group. A change one of
you merges changes the app for all five of you.

## Before your first push

**This repository is public.** Anything you commit, including the email address
on your commits, can be read by anyone and can't be taken back.

Turn on GitHub's private commit email first:

1. **GitHub → Settings → Emails → tick "Keep my email addresses private".**
   The page then shows your private address. It looks like
   `12345678+yourname@users.noreply.github.com`: a number, a `+`, your
   GitHub username.
2. On the same page, also tick **"Block command line pushes that expose my
   email"**. If you forget step 3, GitHub refuses the push instead of
   publishing your address.
3. In your copy of this repo, tell git to use that address, then check it:

   ```bash
   git config user.email "12345678+yourname@users.noreply.github.com"   # yours, from step 1
   git config user.email                                                # prints what git will use
   ```

   This applies to this repo only. Add `--global` to use it for every repo on
   your machine.

Never commit a password, key, or token. The pipeline doesn't need one.

The workflow logs and the plan comments are public too. Terraform hides values
it knows are secret (they show as `(sensitive value)`), so never undo that with
`nonsensitive()`, and never `echo` a secret in a workflow step. Anything a log
prints, anyone can read.

## Your first change, start to finish

1. **Agree who's driving.** If five people edit the same line at once, the
   first pull request merges and the other four get conflicts. One person makes
   the change; everyone else reviews it.
2. **Make a branch and change the greeting.** In `variables.tf`, find:

   ```hcl
   variable "greeting" {
     type        = string
     default     = "hello from v1"
   ```

   Change `hello from v1` to something your team will recognize, for example
   `hello from team 3`. Commit it on a new branch and push the branch.
3. **Open a pull request into `main`.** Go to the **Actions** tab: a workflow
   called **terraform plan** starts. After a minute or two it posts a comment
   on your pull request showing exactly what would change in Azure.
4. **Read the plan comment before merging.** This is the review. For a greeting
   change you should see one resource updated *in place* (`~`) and nothing
   destroyed. If the plan says `destroy` or `must be replaced` and you didn't
   expect it, stop and ask.
5. **Merge the pull request.** A workflow called **terraform apply** runs on
   `main` and makes the change for real. The first apply for your team takes a
   few minutes, because it creates the app's environment; later ones are
   quicker.
6. **Find your app's address.** Open the finished **terraform apply** run, then
   the step **show app url**. It prints a line like
   `app_url = "https://hello.<something>.azurecontainerapps.io"`.
   Open that URL: the page shows your greeting.

The very first request after a quiet spell can take several seconds. The app
scales to zero when nobody is using it, so it has to start up first. That's
expected, not a bug.

## Looking at it in the Azure portal

Optional: everything above works without it. To see your team's resources:

1. Accept the Azure invitation email your instructor's setup sent you.
2. Sign in with the **link in this repo's About box** (top right of the repo
   page), **not** plain `portal.azure.com`.
3. Use the email address you were invited with. If it isn't a Microsoft
   account, Azure emails you a one-time code instead of asking for a password.

You'll see one resource group: your team's.

| If you see | It means |
|---|---|
| "This account doesn't exist" | You used plain `portal.azure.com`. Use the About-box link. |
| Signed in, but no resources | Top right → **Switch directory**, pick the class's directory. |
| "You don't have permission" changing the resource group's tags | Expected. The expiry date and tags are locked. |
| Something you changed in the portal disappeared | Expected. The next apply puts everything back to what the code says. Make lasting changes through a pull request. |

## What's in this repo

| File | What it does |
|---|---|
| `main.tf` | The Azure resources: a Log Analytics workspace, a Container Apps environment, and the app itself (a tiny web server that prints `greeting`). |
| `variables.tf` | The settings you're meant to change. `greeting` is the safe one to start with. |
| `outputs.tf` | Prints `app_url` after each apply. |
| `.github/workflows/plan.yml` | Runs `terraform plan` on every pull request and comments the result. |
| `.github/workflows/apply.yml` | Runs `terraform apply` on every push to `main`. |
| `.github/workflows/destroy.yml` | Deletes everything. Manual only; see below. |

Changing `app_name` renames the app, which means Azure **replaces** it: the
plan will say `must be replaced` and the URL will change. Try it on purpose
some time, so you know what that looks like in a plan.

## How it deploys without a password

Look through the files in `.github/workflows/`. They read a handful of
settings as `vars.AZURE_CLIENT_ID`, `vars.AZURE_TENANT_ID`, and so on: IDs and
names. There is no `secrets.` anywhere. The IDs aren't credentials; knowing
them gets an attacker nothing.

Instead of a password, the workflow uses **OIDC federation**:

1. When a workflow runs, GitHub issues it a short-lived signed token that says
   which repo and branch the run is for.
2. Azure has been told to trust tokens for exactly this repo, and only for
   specific triggers.
3. A **pull request** can only act as a **read-only** identity, so the plan
   can look at Azure but never change it. Only a push to **`main`** can act as
   the identity that's allowed to make changes.

That's why a pull request, whatever it contains, can never write to Azure, and
why there's nothing to leak or rotate.

## Rules of the road

- **Everything is deleted on the expiry date** your instructor gives you. An
  automated cleanup job removes your team's resource group on that day. Don't
  keep anything here you need afterwards.
- **You can't change the resource group's expiry or tags.** That's deliberate.
  Ask your instructor if your team needs more time.
- **`main` is protected.** Every change goes through a pull request, so the plan
  is always visible first. Nobody has to approve it, but read it.
- **The destroy workflow deletes your whole team's app.** It only runs if you
  start it by hand from the **Actions** tab and type your team's resource group
  name to confirm. The name appears in every plan and apply log (look for
  `resource_group_name`), and your instructor can tell you. Agree as a team
  before anyone runs it.

## When something goes wrong

| What you see | What it means |
|---|---|
| The plan or apply log says `terraform init failed ... retrying in 30s` | Normal in the first minutes after your team's environment was set up: permissions take time to reach Azure Storage. It retries on its own. |
| No plan comment appeared on the pull request | Open the **Actions** tab and look at the **terraform plan** run. If it failed, the error is in the log. |
| The URL shows your old greeting | Wait for the **terraform apply** run to finish, then refresh. |
| The apply failed after you merged | Read the error in the log first. A failed apply can leave some changes made and others not; fix the problem in a new pull request, and the next successful apply brings Azure back in line with `main`. |
| `AuthorizationFailed` in a log | Something tried to do more than your team is allowed to, such as changing tags on the resource group. Check what the change was trying to do. |
