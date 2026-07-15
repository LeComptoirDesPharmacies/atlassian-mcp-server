---
name: setup-atlassian-rovo
description: Provide the API token that the vendored atlassian MCP plugin (our fork) needs, so Jira/Confluence AND Bitbucket Cloud tools connect. Use when onboarding a dev, when the atlassian MCP server is disconnected/failing to authenticate, or when someone asks to set up the Atlassian token / get bitbucket* tools in Claude Code. Reads references/rovo-bitbucket-setup.md for the fixed values.
---

# Provide the Atlassian Rovo token (for the vendored `atlassian` MCP plugin)

The vendored `atlassian` plugin (our fork `LeComptoirDesPharmacies/atlassian-mcp-server`) **already
declares** the Rovo MCP server (`atlassian`, remote HTTP,
token auth) — see its `.mcp.json`. It just needs the env var **`ATLASSIAN_ROVO_AUTH`** =
`base64(email:token)` present in the environment when Claude Code starts. This skill helps the dev
set that env var securely. Nothing is added to the MCP config here; the plugin owns the server.

Fixed values (endpoint, prerequisites, security) live in **`references/rovo-bitbucket-setup.md`**.

## The token must never pass through Claude

A token pasted into a Claude prompt lands in the transcript (seen by the model, logged). So **this
skill never asks for, receives, or echoes the token.** The secret is entered by the dev in their
**own terminal**, via the bundled `setup-atlassian-rovo.sh` (same folder), which reads it silently
(`read -s`), stores it as an env var in a `0600` file, and never prints it. Your job is to guide and
verify, **not** to handle the secret. If the user pastes a token anyway, tell them it is compromised
(rotate it) and continue with the script flow.

## Step 1 — Check the admin prerequisites (blocking)

Two things must already be true org-side (an org admin sets them on `admin.atlassian.com`; a dev
cannot). Ask the user to confirm both; if either is missing, stop and say who to ask:

1. **API-token auth enabled** for the MCP server (Admin Hub → Rovo → Rovo MCP server).
2. **Bitbucket Cloud workspace linked** to the Atlassian organization — without it, no `bitbucket*`
   tool appears even with a valid token.

## Step 2 — Have the dev create a scoped token

Point them to `id.atlassian.com/manage-profile/security/api-tokens` → **Create API token with
scopes**, with the Bitbucket scopes they need. They keep it to themselves — do **not** ask for it.

## Step 3 — Hand off the script (they run it, not you)

Give the dev the absolute path to `setup-atlassian-rovo.sh` (resolve it from this skill's directory)
and tell them to run it **in their own terminal**:

```
bash <path>/setup-atlassian-rovo.sh
```

Do **not** run it yourself (Bash tool / `!`): it prompts for the token, which must not reach the
conversation. The script base64-encodes `email:token`, writes it to a `0600` env file as
`ATLASSIAN_ROVO_AUTH`, and cleans up any old standalone `atlassian-rovo` entry that stored a token in
clear. It does **not** touch the MCP config — the server comes from the plugin.

## Step 4 — Finish and verify

Remind the dev to (per the script's output):
1. `source` the env file from their shell profile so Claude Code sees `ATLASSIAN_ROVO_AUTH` at
   startup, then **restart Claude Code** (the var must be in its environment).
2. Check `/mcp` shows the `atlassian` server connected and `bitbucket*` tools listed. If it connects
   but no `bitbucket*` tool appears → Step 1.2 (workspace not linked to the org).

**If the env var is missing, the `atlassian` server fails to authenticate and every Jira/Confluence
skill breaks** — there is no OAuth fallback in this setup. So this token step is a required part of
onboarding, not optional. The `doctor` skill flags a missing `ATLASSIAN_ROVO_AUTH`.

## Step 5 — Rotation

If a token was ever pasted into a chat, or added in clear in a previous `atlassian-rovo` MCP entry,
it is compromised — rotate it at `id.atlassian.com/manage-profile/security/api-tokens`. The `0600`
env file holds `base64(email:token)` (decodable) — keep it uncommitted.
