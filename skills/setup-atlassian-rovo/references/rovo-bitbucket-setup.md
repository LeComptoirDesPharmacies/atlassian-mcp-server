# Atlassian Rovo MCP — token setup

Fixed procedure and values used by the `setup-atlassian-rovo` skill. Edit here — do not hardcode in
the SKILL.md.

## How the Atlassian MCP is wired (LCDP)

The vendored **`atlassian`** plugin — **our fork** `LeComptoirDesPharmacies/atlassian-mcp-server`
(upstream + patch) — owns the Atlassian MCP server: its `.mcp.json` declares a remote HTTP server
(`atlassian`) pointing at the Rovo endpoint with a **token** header referencing an env var:

```json
{ "mcpServers": { "atlassian": {
    "type": "http",
    "url": "https://mcp.atlassian.com/v1/mcp",
    "headers": { "Authorization": "Basic ${ATLASSIAN_ROVO_AUTH}" }
} } }
```

Claude Code **expands `${ATLASSIAN_ROVO_AUTH}` at connection time**, so the plugin ships **no secret** —
each dev just provides the env var. This is the only Atlassian server (there is no OAuth plugin
anymore): token auth surfaces **Jira + Confluence + Bitbucket** in one server.

**Why token and not OAuth:** Bitbucket Cloud tools are **not** exposed over OAuth — as of 2026-07 they
require **API-token auth only** ([Atlassian blog](https://www.atlassian.com/blog/bitbucket/the-atlassian-rovo-mcp-server-now-supports-bitbucket-cloud)).
Token auth is a strict superset of what OAuth gave (Jira + Confluence), plus Bitbucket.

## Fixed values

| Key | Value |
|---|---|
| endpoint | `https://mcp.atlassian.com/v1/mcp` (legacy `/v1/sse` retired after 2026-06-30) |
| transport | `http` (streamable HTTP) |
| `cloudId` | `lecomptoirdespharmacies.atlassian.net` |
| MCP server name | `atlassian` (provided by the vendored `atlassian` plugin — our fork) |
| env var | `ATLASSIAN_ROVO_AUTH` = `base64(email:token)` |
| env file | `${XDG_CONFIG_HOME:-$HOME/.config}/lcdp/atlassian-rovo.env` (mode `0600`) |

## Org-side setup — already done (LCDP)

The org-level prerequisites (API-token auth enabled for Rovo, and the Bitbucket Cloud workspace
linked to the org) are **already configured by the LCDP admins** — no dev action. Debug hint only:
if a valid token yields Jira/Confluence tools but **no `bitbucket*` tool**, the workspace link may
have regressed — ping the admins.

## Token + the env var (never in a prompt)

- Create a **scoped API token** at `id.atlassian.com/manage-profile/security/api-tokens` →
  *Create API token with scopes* → select the app **Rovo MCP** → grant **all available scopes**
  (covers Jira, Confluence and Bitbucket).
- **Never paste the token into a Claude prompt** — it would land in the conversation transcript. The
  token is entered only in the dev's own terminal, by `setup-atlassian-rovo.sh`, which reads it
  silently, base64-encodes `email:token`, and writes it to the `0600` env file as:

  ```bash
  export ATLASSIAN_ROVO_AUTH=<base64 value>
  ```

- The dev then `source`s that file from `~/.bashrc`/`~/.zshrc` so Claude Code sees the var **at
  startup**, and restarts Claude Code. The plugin's server picks it up — no `claude mcp add`, nothing
  in `~/.claude.json`.

For a shared/CI machine, a **service-account API key** works too; use a **Bearer** header instead of
Basic (adjust the plugin's `.mcp.json` header, or set the env var to the full `Bearer …` — keep the
scheme consistent).

## Missing env var = broken Jira

There is **no OAuth fallback**: if `ATLASSIAN_ROVO_AUTH` is unset (or wrong), the `atlassian` server
fails to authenticate and **every Jira/Confluence skill breaks**. So setting it is a required
onboarding step, and the `doctor` skill checks for it.

## Security

The `Basic` value is `base64(email:token)` — trivially decodable, **not** encryption. It lives only
in the `0600` env file (never in the MCP config, never in a prompt). Treat that file like a password:
keep it `0600` and uncommitted, use a token scoped to the **Rovo MCP** app, and rotate the token if
it leaks (including if it was ever pasted into a chat or added inline in an old `atlassian-rovo` MCP
entry).
