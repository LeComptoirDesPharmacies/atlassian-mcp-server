#!/usr/bin/env bash
#
# Provide the ATLASSIAN_ROVO_AUTH secret for the vendored atlassian MCP plugin, WITHOUT exposing the token.
#
# RUN THIS IN YOUR OWN TERMINAL — not through Claude, not with the `!` prefix.
#
# The vendored atlassian plugin already declares the Rovo MCP server (token auth). It only needs the env
# var ATLASSIAN_ROVO_AUTH = base64(email:token) to be present when Claude Code starts. This script
# reads the token silently (read -s), never prints it, and writes it to a 0600 file you source from
# your shell profile. Nothing is added to the MCP config; no secret is stored there.
#
set -euo pipefail

ENV_VAR="ATLASSIAN_ROVO_AUTH"
ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/lcdp/atlassian-rovo.env"

read -rp  "Atlassian account email : " EMAIL
read -rsp "Scoped API token (Bitbucket scopes) : " TOKEN; echo
[ -n "${EMAIL:-}" ] && [ -n "${TOKEN:-}" ] || { echo "email and token are both required" >&2; exit 1; }

# Basic auth value = base64(email:token). Never printed.
B64="$(printf '%s' "${EMAIL}:${TOKEN}" | base64 | tr -d '\n')"
unset TOKEN

umask 077
mkdir -p "$(dirname "$ENV_FILE")"
printf 'export %s=%s\n' "$ENV_VAR" "$B64" > "$ENV_FILE"
chmod 600 "$ENV_FILE"
unset B64
echo "Secret written to $ENV_FILE (mode 600)."

# Clean up any earlier standalone entry that stored the token in clear (pre-plugin approach).
if command -v claude >/dev/null 2>&1; then
  claude mcp remove atlassian-rovo --scope user >/dev/null 2>&1 || true
fi

cat <<EOF

Finish in your terminal:

  1. Load the secret from your shell profile so Claude Code sees it at startup. Add to
     ~/.bashrc / ~/.zshrc (or your secrets manager):
         source "$ENV_FILE"
     …then reload:  source "$ENV_FILE"

  2. Restart Claude Code (fresh session, so the env var is in its environment). The vendored atlassian
     plugin's 'atlassian' server connects with this token — check /mcp shows it connected and that
     bitbucket* tools are listed. No bitbucket* tool => the Bitbucket workspace is not linked to the
     org (admin prerequisite).

Security follow-ups:
  - If a token was ever added in clear (an old 'atlassian-rovo' entry) or pasted into a chat, it is
    compromised — rotate it at id.atlassian.com/manage-profile/security/api-tokens.
  - $ENV_FILE holds base64(email:token) — decodable, treat it like a password (0600, never commit).
EOF
