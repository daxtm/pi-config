#!/usr/bin/env bash
# pi-config install — writes this kit into ~/.pi/agent. Normally run by `pikit apply` from the
# deployed copy (~/.local/share/pi-config); safe to re-run.
#
# Installs/configures:
#   - uses your existing pi (pi.dev/install.sh); installs it only if missing
#   - OpenSpec CLI, Exa/Tavily/Firecrawl MCP servers (pinned), Command Code provider, RTK
#   - ~/.pi/agent: AGENTS.md, MAIN.md, agents/, prompts/, skills/, extensions/, settings + mcp keys
#   - commands on PATH: pinew pikit pi-ship pi-branch pi-gh-setup pi-test-branch
#   - git hooks in your kit projects (keep `test` up to date)
# Files this kit installed before but no longer ships are removed (tracked in ~/.pi/agent/.kit-manifest).
#
# Usage:  install.sh [--dry-run] [--skip-rtk]
set -euo pipefail

# ---- pinned versions ---------------------------------------------------------------------
PI_PKG="@earendil-works/pi-coding-agent";  PI_MIN_VERSION="1.5.2"
OPENSPEC_PKG="@fission-ai/openspec";       OPENSPEC_VERSION="2.1.1"
CC_PROVIDER_PKG="pi-commandcode-provider"; CC_PROVIDER_VERSION="0.8.6"
EXA_PKG="exa-mcp-server";                  EXA_VERSION="3.5.1"
TAVILY_PKG="tavily-mcp";                   TAVILY_VERSION="0.2.22"
FIRECRAWL_PKG="firecrawl-mcp";             FIRECRAWL_VERSION="3.41.0"
RTK_INSTALL_URL="https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
MIN_NODE="22.19.0"

KIT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
SECRETS_FILE="$HOME/.config/pi-kit/secrets.env"
MODELS_CONF="$KIT_DIR/agent-models.conf"

DRY_RUN=0; SKIP_RTK=0; PATH_CHANGED=0
for arg in "$@"; do
	case "$arg" in
	--dry-run) DRY_RUN=1 ;;
	--skip-rtk) SKIP_RTK=1 ;;
	-h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
	*) echo "Unknown option: $arg" >&2; exit 2 ;;
	esac
done

info() { printf '\033[36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m ok\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarn\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31merror\033[0m %s\n' "$*" >&2; exit 1; }
run()  { if (( DRY_RUN )); then printf '   [dry-run] %s\n' "$*"; else "$@"; fi; }
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

MANIFEST=()   # files in $AGENT_DIR this kit owns
install_file() { # src dest [mode]
	local src="$1" dest="$2" mode="${3:-644}"
	MANIFEST+=("${dest#"$AGENT_DIR"/}")
	[[ -f "$dest" ]] && cmp -s "$src" "$dest" && return 0
	run mkdir -p "$(dirname "$dest")"
	run install -m "$mode" "$src" "$dest"
	(( DRY_RUN )) || echo "   wrote $dest"
}
render() { # src dest — fill {{PLACEHOLDERS}}, then install
	local src="$1" dest="$2" tmp
	tmp="$TMP_DIR/render/${dest#"$AGENT_DIR"/}"; mkdir -p "$(dirname "$tmp")"
	sed -e "s|{{KIT_DIR}}|$KIT_DIR|g" -e "s|{{AGENT_DIR}}|$AGENT_DIR|g" -e "s|{{KIT_NPM_BIN}}|$NPM_PREFIX/bin|g" \
		-e "s|{{HOME_BIN}}|$HOME/.local/bin|g" -e "s|{{ZSH}}|${ZSH_BIN:-/bin/zsh}|g" "$src" > "$tmp"
	install_file "$tmp" "$dest"
}

# ---- 1. prerequisites ---------------------------------------------------------------------
info "Checking prerequisites"
for c in git node npm flock; do command -v "$c" >/dev/null || die "$c is required"; done
NODE_V="$(node -p 'process.versions.node')"
version_ge "$NODE_V" "$MIN_NODE" || die "Node.js $NODE_V is too old; pi needs >= $MIN_NODE"
ORIG_PATH="$PATH"
TMP_DIR="$(mktemp -d)"; trap 'rm -rf "$TMP_DIR"' EXIT
NPM_PREFIX="$(npm prefix -g)"
if [[ ! -w "$NPM_PREFIX" ]]; then NPM_PREFIX="$HOME/.local"; export npm_config_prefix="$NPM_PREFIX"; fi
run mkdir -p "$NPM_PREFIX/bin" "$NPM_PREFIX/lib" "$HOME/.local/bin"
export PATH="$NPM_PREFIX/bin:$HOME/.local/bin:$PATH"
ZSHRC="$HOME/.zshrc"
for dir in "$NPM_PREFIX/bin" "$HOME/.local/bin"; do
	case ":$ORIG_PATH:" in *":$dir:"*) continue ;; esac
	[[ -f "$ZSHRC" ]] && grep -qF "# pi-workflow-kit PATH $dir" "$ZSHRC" && continue
	if (( DRY_RUN )); then echo "   [dry-run] add $dir to PATH in $ZSHRC"; else
		printf '\n# pi-workflow-kit PATH %s\nexport PATH="%s:$PATH"\n' "$dir" "$dir" >> "$ZSHRC"; PATH_CHANGED=1
	fi
done
command -v gh >/dev/null || warn "gh (GitHub CLI) not found — /ship needs it: install it, then gh auth login"
ZSH_BIN="$(PATH="$ORIG_PATH" command -v zsh || true)"
ok "node $NODE_V, npm tools in $NPM_PREFIX"

# ---- 2. pi --------------------------------------------------------------------------------
pi_version() { "$1" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1; }
PI_BIN="$(command -v pi || true)"
[[ -z "$PI_BIN" && -x "$HOME/.local/bin/pi" ]] && PI_BIN="$HOME/.local/bin/pi"
if [[ -n "$PI_BIN" ]]; then
	PI_HAVE="$(pi_version "$PI_BIN")"; [[ -n "$PI_HAVE" ]] || die "'$PI_BIN --version' failed"
	if ! version_ge "$PI_HAVE" "$PI_MIN_VERSION"; then run "$PI_BIN" update --self; (( DRY_RUN )) || PI_HAVE="$(pi_version "$PI_BIN")"; fi
else
	run npm install -g --ignore-scripts --no-fund --no-audit "$PI_PKG@$PI_MIN_VERSION" >/dev/null
	PI_BIN="$NPM_PREFIX/bin/pi"; PI_HAVE="$PI_MIN_VERSION"
fi
ok "pi $PI_HAVE ($PI_BIN)"

# ---- 3. npm tools -------------------------------------------------------------------------
npm_global() { # pkg version bin
	local pkg="$1" want="$2" bin="$3" have
	have="$(npm ls -g --depth=0 --json 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(JSON.parse(s).dependencies?.[process.argv[1]]?.version||"")}catch{}})' "$pkg" || true)"
	if [[ "$have" == "$want" ]]; then ok "$pkg $have"; return 0; fi
	info "Installing $pkg@$want${have:+ (had $have)}"
	run npm install -g --ignore-scripts --no-fund --no-audit "$pkg@$want" >/dev/null
	(( DRY_RUN )) || [[ -x "$NPM_PREFIX/bin/$bin" ]] || die "$bin not found after installing $pkg"
}
npm_global "$OPENSPEC_PKG" "$OPENSPEC_VERSION" openspec
npm_global "$EXA_PKG" "$EXA_VERSION" exa-mcp-server
npm_global "$TAVILY_PKG" "$TAVILY_VERSION" tavily-mcp
npm_global "$FIRECRAWL_PKG" "$FIRECRAWL_VERSION" firecrawl-mcp
(( DRY_RUN )) || printf 'KIT_NPM_BIN=%q\nOPENSPEC_BIN=%q\n' "$NPM_PREFIX/bin" "$NPM_PREFIX/bin/openspec" > "$KIT_DIR/.kit-paths"

# ---- 4. ~/.pi/agent -----------------------------------------------------------------------
info "Configuring $AGENT_DIR"
OLD_MANIFEST=()
[[ -f "$AGENT_DIR/.kit-manifest" ]] && mapfile -t OLD_MANIFEST < "$AGENT_DIR/.kit-manifest"

install_file "$KIT_DIR/global/AGENTS.md" "$AGENT_DIR/AGENTS.md"
install_file "$KIT_DIR/global/MAIN.md" "$AGENT_DIR/MAIN.md"
for f in "$KIT_DIR"/global/extensions/*.ts; do
	name="$(basename "$f")"
	[[ "$name" == zsh-bang.ts && -z "$ZSH_BIN" ]] && { warn "zsh not found — ! commands stay in bash"; continue; }
	render "$f" "$AGENT_DIR/extensions/$name"
done
for f in "$KIT_DIR"/global/prompts/*.md; do render "$f" "$AGENT_DIR/prompts/$(basename "$f")"; done
while IFS= read -r -d '' f; do install_file "$f" "$AGENT_DIR/skills/${f#"$KIT_DIR/global/skills/"}"; done \
	< <(find "$KIT_DIR/global/skills" -type f -print0)

# subagent extension: Pi's official example for the pi version you run
if (( DRY_RUN )); then echo "   [dry-run] fetch the subagent example from $PI_PKG@$PI_HAVE"; else
	mkdir -p "$TMP_DIR/pi-pkg"
	tarball="$(npm pack --silent --pack-destination "$TMP_DIR/pi-pkg" "$PI_PKG@$PI_HAVE" | tail -n1)"
	tar -xzf "$TMP_DIR/pi-pkg/$tarball" -C "$TMP_DIR/pi-pkg" package/examples/extensions/subagent
	for f in index.ts agents.ts; do
		install_file "$TMP_DIR/pi-pkg/package/examples/extensions/subagent/$f" "$AGENT_DIR/extensions/subagent/$f"
	done
fi

# agents, with models from agent-models.conf
model_for() { grep -E "^[[:space:]]*$1[[:space:]]*=" "$MODELS_CONF" | tail -n1 | cut -d= -f2- | sed -E 's/#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//'; }
for f in "$KIT_DIR"/global/agents/*.md; do
	agent="$(basename "$f" .md)"; model="$(model_for "$agent")"
	if [[ -n "$model" ]]; then sed "s|^{{MODEL_LINE}}\$|model: $model|" "$f" > "$TMP_DIR/$agent.md"
	else sed '/^{{MODEL_LINE}}$/d' "$f" > "$TMP_DIR/$agent.md"; fi
	install_file "$TMP_DIR/$agent.md" "$AGENT_DIR/agents/$agent.md"
	echo "   $agent -> ${model:-main session model}"
done

# your own files: global/user/** → ~/.pi/agent/** as-is
if [[ -d "$KIT_DIR/global/user" ]]; then
	while IFS= read -r -d '' f; do install_file "$f" "$AGENT_DIR/${f#"$KIT_DIR/global/user/"}"; done \
		< <(find "$KIT_DIR/global/user" -type f -print0)
fi

# settings.json: yours, plus the main model from agent-models.conf
MAIN_MODEL="$(model_for main)"
node - "$AGENT_DIR/settings.json" "$TMP_DIR/settings.json" "$MAIN_MODEL" <<'NODE'
const fs = require("fs");
const [file, out, spec] = process.argv.slice(2);
let cfg = {};
if (fs.existsSync(file)) { try { cfg = JSON.parse(fs.readFileSync(file, "utf8")); } catch (e) { console.error(`Cannot parse ${file}: ${e.message}`); process.exit(1); } }
if (spec) {
  const levels = ["off", "minimal", "low", "medium", "high", "xhigh", "max"];
  let model = spec; const i = spec.lastIndexOf(":");
  if (i > 0 && levels.includes(spec.slice(i + 1))) { model = spec.slice(0, i); cfg.defaultThinkingLevel = spec.slice(i + 1); }
  const slash = model.indexOf("/");
  cfg.defaultProvider = model.slice(0, slash); cfg.defaultModel = model.slice(slash + 1);
}
cfg.showCacheMissNotices = true;
fs.writeFileSync(out, JSON.stringify(cfg, null, 2) + "\n");
NODE
run install -m 644 "$TMP_DIR/settings.json" "$AGENT_DIR/settings.json"

# web MCP servers (your other servers in mcp.json are left alone)
SECRET_BIN="$KIT_DIR/bin/pi-kit-secret"
node - "$AGENT_DIR/mcp.json" "$TMP_DIR/mcp.json" "$NPM_PREFIX/bin" "$SECRET_BIN" <<'NODE'
const fs = require("fs");
const [file, out, bin, secret] = process.argv.slice(2);
let cfg = {};
if (fs.existsSync(file)) { try { cfg = JSON.parse(fs.readFileSync(file, "utf8")); } catch (e) { console.error(`Cannot parse ${file}: ${e.message}`); process.exit(1); } }
cfg.mcpServers ??= {};
const server = (cmd, key, description, tools) => ({
  command: `${bin}/${cmd}`, env: { [key]: `!${secret} ${key}` }, description,
  exposure: "hidden", toolExposure: Object.fromEntries(tools.map((t) => [t, "direct"])),
});
cfg.mcpServers.exa = server("exa-mcp-server", "EXA_API_KEY", "Exa web search and page fetch", ["web_search_exa", "web_fetch_exa"]);
cfg.mcpServers.tavily = server("tavily-mcp", "TAVILY_API_KEY", "Tavily web search and URL extraction", ["tavily_search", "tavily_extract"]);
cfg.mcpServers.firecrawl = server("firecrawl-mcp", "FIRECRAWL_API_KEY", "Firecrawl page scraping, site maps and developer search", ["firecrawl_scrape", "firecrawl_map", "firecrawl_developer_search"]);
fs.writeFileSync(out, JSON.stringify(cfg, null, 2) + "\n");
NODE
run install -m 600 "$TMP_DIR/mcp.json" "$AGENT_DIR/mcp.json"
if [[ ! -f "$SECRETS_FILE" ]] && (( ! DRY_RUN )); then
	mkdir -p "$(dirname "$SECRETS_FILE")"
	( umask 077; printf '# Keys for pi'"'"'s MCP servers (read by pi-kit-secret). Env vars with the same names win.\nEXA_API_KEY=\nTAVILY_API_KEY=\nFIRECRAWL_API_KEY=\n' > "$SECRETS_FILE" )
	echo "   created $SECRETS_FILE — put your keys in it"
fi

# ---- 5. Command Code provider, RTK --------------------------------------------------------
CC_SPEC="npm:$CC_PROVIDER_PKG@$CC_PROVIDER_VERSION"
if (( ! DRY_RUN )) && PI_CODING_AGENT_DIR="$AGENT_DIR" "$PI_BIN" list 2>/dev/null | grep -qF "$CC_SPEC"; then ok "$CC_SPEC"
else run env PI_CODING_AGENT_DIR="$AGENT_DIR" "$PI_BIN" install "$CC_SPEC"; fi

if (( ! SKIP_RTK )); then
	RTK_BIN="$(command -v rtk || true)"
	if [[ -z "$RTK_BIN" ]]; then
		if (( DRY_RUN )); then echo "   [dry-run] install rtk to $HOME/.local/bin"; else
			command -v curl >/dev/null || die "curl is needed to install RTK (or use --skip-rtk)"
			curl -fsSL "$RTK_INSTALL_URL" -o "$TMP_DIR/rtk-install.sh"
			RTK_INSTALL_DIR="$HOME/.local/bin" sh "$TMP_DIR/rtk-install.sh" >/dev/null
		fi
		RTK_BIN="$HOME/.local/bin/rtk"
	fi
	if (( ! DRY_RUN )); then
		"$RTK_BIN" gain >/dev/null 2>&1 || die "$RTK_BIN isn't rtk-ai/rtk ('rtk gain' failed)"
		PI_CODING_AGENT_DIR="$AGENT_DIR" "$RTK_BIN" init -g --agent pi >/dev/null
		ok "$("$RTK_BIN" --version)"
	fi
fi
for f in extensions/rtk.ts extensions/.rtk-agents; do [[ -e "$AGENT_DIR/$f" ]] && MANIFEST+=("$f"); done   # RTK's, kept with --skip-rtk too

# ---- 6. retire files an earlier version installed but this one doesn't ---------------------
for rel in "${OLD_MANIFEST[@]}"; do
	[[ -n "$rel" && "$rel" != *..* ]] || continue
	case "$rel" in settings.json|mcp.json|auth.json|trust.json|sessions/*) continue ;; esac
	printf '%s\n' "${MANIFEST[@]}" | grep -qxF "$rel" && continue
	[[ -e "$AGENT_DIR/$rel" ]] || continue
	run rm -f "$AGENT_DIR/$rel"
	(( DRY_RUN )) || echo "   removed retired $AGENT_DIR/$rel"
done
(( DRY_RUN )) || printf '%s\n' "${MANIFEST[@]}" | sort -u > "$AGENT_DIR/.kit-manifest"

# ---- 7. commands on PATH, pinew for zsh, git hooks ----------------------------------------
link_cmd() { # name target
	local link="$HOME/.local/bin/$1"
	[[ "$(readlink -f "$link" 2>/dev/null)" == "$(readlink -f "$2")" ]] && return 0
	if [[ -e "$link" && ! -L "$link" ]]; then warn "$link exists and isn't a link — left alone"; return 0; fi
	run ln -sfn "$2" "$link"
}
link_cmd pinew "$KIT_DIR/new-project.sh"
for c in pikit pi-ship pi-branch pi-gh-setup pi-test-branch; do link_cmd "$c" "$KIT_DIR/bin/$c"; done
# links an earlier version made into this kit that now point nowhere (e.g. a retired command)
for link in "$HOME"/.local/bin/*; do
	[[ -L "$link" && ! -e "$link" ]] || continue
	case "$(readlink "$link")" in "$KIT_DIR"/*) run rm -f "$link"; (( DRY_RUN )) || echo "   removed retired command $(basename "$link")" ;; esac
done

if (( ! DRY_RUN )); then
	mkdir -p "$KIT_DIR/shell"
	cat > "$KIT_DIR/shell/pinew.zsh" <<EOF
# pinew for interactive zsh: set up the project, then cd into it (written by pi-config install.sh)
pinew() {
	local cd_file dir rc
	cd_file="\$(mktemp)"
	PINEW_CD_FILE="\$cd_file" "$KIT_DIR/new-project.sh" "\$@"; rc=\$?
	dir="\$(cat "\$cd_file" 2>/dev/null)"; rm -f "\$cd_file"
	(( rc == 0 )) || return \$rc
	[[ -n "\$dir" && -d "\$dir" ]] && cd "\$dir"
}
EOF
fi
ZSH_LINE="[ -f \"$KIT_DIR/shell/pinew.zsh\" ] && source \"$KIT_DIR/shell/pinew.zsh\" # pi-workflow-kit pinew"
if [[ -f "$ZSHRC" ]] && ! grep -qxF "$ZSH_LINE" "$ZSHRC"; then
	if (( DRY_RUN )); then echo "   [dry-run] set the pinew line in $ZSHRC"; else
		grep -vF "# pi-workflow-kit pinew" "$ZSHRC" > "$TMP_DIR/zshrc" || true
		printf '%s\n' "$ZSH_LINE" >> "$TMP_DIR/zshrc"; cat "$TMP_DIR/zshrc" > "$ZSHRC"
	fi
fi

HOOK_LINE="[ -n \"\$PI_TEST_BRANCH\" ] || [ ! -x \"$HOME/.local/bin/pi-test-branch\" ] || ( \"$HOME/.local/bin/pi-test-branch\" --quiet >/dev/null 2>&1 & ) # pi-workflow-kit"
if [[ -f "$AGENT_DIR/trust.json" ]] && (( ! DRY_RUN )); then
	while IFS= read -r proj; do
		[[ -e "$proj/.git" ]] || continue
		[[ "$(git -C "$proj" config --local --get pi.kit 2>/dev/null)" == "true" ]] || continue
		hooks="$(git -C "$proj" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)" || continue
		for h in post-commit post-merge post-rewrite; do
			f="$hooks/$h"
			[[ -f "$f" ]] && grep -qxF "$HOOK_LINE" "$f" && continue
			[[ -f "$f" ]] || printf '#!/bin/sh\n' > "$f"
			sed -i '/# pi-workflow-kit$/d' "$f"; printf '%s\n' "$HOOK_LINE" >> "$f"; chmod +x "$f"
		done
	done < <(node -e 'try{for(const [k,v] of Object.entries(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))))if(v===true)console.log(k)}catch{}' "$AGENT_DIR/trust.json")
fi

# ---- 8. model IDs pi doesn't know ---------------------------------------------------------
if (( ! DRY_RUN )); then
	KNOWN="$(PI_CODING_AGENT_DIR="$AGENT_DIR" timeout 60 "$PI_BIN" --list-models 2>/dev/null | awk 'NR>1 {print $1"/"$2}' || true)"
	if [[ -n "$KNOWN" ]]; then
		for role in main spec build debugger resolver researcher; do
			m="$(model_for "$role")"; [[ -n "$m" ]] || continue
			id="$m"; [[ "${m##*:}" =~ ^(off|minimal|low|medium|high|xhigh|max)$ ]] && id="${m%:*}"
			grep -qxF "$id" <<<"$KNOWN" || warn "$role: pi doesn't list '$id' — log in to ${id%%/*} with /login (check: pi --list-models)"
		done
	fi
fi

echo
ok "pi-config installed into $AGENT_DIR from $KIT_DIR"
(( PATH_CHANGED )) && warn "PATH updated in $ZSHRC — run: exec zsh"
exit 0
