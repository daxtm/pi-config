/**
 * main-only — gives MAIN.md (routing and sizing rules) to the interactive main session only.
 * Subagents and headless runs don't get it, so they don't pay for it. Added as a stable named prompt
 * section, so it stays in the provider's prompt cache. Installed by pi-config.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import * as fs from "node:fs";

const FILE = "{{AGENT_DIR}}/MAIN.md";

export default function (pi: ExtensionAPI) {
	let text = "";
	try {
		text = fs.readFileSync(FILE, "utf8").trim();
	} catch {
		return;
	}
	pi.on("before_agent_start", (event, ctx) => {
		if (!ctx.hasUI || !text) return;
		const opts = event.systemPromptOptions as { sections?: Record<string, string> } | undefined;
		if (!opts) return;
		opts.sections ??= {};
		opts.sections.main = text;
	});
}
