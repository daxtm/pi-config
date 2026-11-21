/**
 * web-scope — keeps the Exa / Tavily / Firecrawl MCP tools out of the
 * interactive main session so their schemas don't cost tokens on every turn.
 *
 * Subagents (spawned in JSON/print mode by the subagent extension) are not
 * touched: their `tools:` frontmatter decides what they get, so only the
 * researcher agent sees the web tools.
 *
 * /web        show status
 * /web on     expose web tools to the main session (this process only)
 * /web off    hide them again (default)
 *
 * Installed by pi-config.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const WEB_PREFIXES = ["mcp__exa__", "mcp__tavily__", "mcp__firecrawl__"];
const isWebTool = (name: string) => WEB_PREFIXES.some((p) => name.startsWith(p));

export default function (pi: ExtensionAPI) {
	let mainSessionWeb = false;

	pi.on("before_agent_start", (event, ctx) => {
		// Only the interactive main session (TUI or RPC). Subagents run in json/print mode.
		if (!ctx.hasUI || mainSessionWeb) return;
		const opts = event.systemPromptOptions as { selectedTools?: string[] } | undefined;
		const selected = opts?.selectedTools;
		if (!Array.isArray(selected) || !selected.some(isWebTool)) return;
		const kept = selected.filter((t) => !isWebTool(t));
		selected.length = 0;
		selected.push(...kept);
	});

	pi.registerCommand("web", {
		description: "Show or toggle web MCP tools (Exa/Tavily/Firecrawl) in the main session: /web [on|off]",
		handler: async (args, ctx) => {
			const arg = (args ?? "").trim().toLowerCase();
			if (arg === "on") mainSessionWeb = true;
			else if (arg === "off") mainSessionWeb = false;
			const state = mainSessionWeb ? "ON (main session sees web tools)" : "OFF (only the researcher agent sees web tools)";
			ctx.ui.notify(`web tools: ${state}`, "info");
		},
	});
}
