/**
 * /research <question> — runs the researcher agent directly: same model, tools and instructions as
 * ~/.pi/agent/agents/researcher.md, in a separate pi process. The main session never decides
 * whether to pass the question on, and spends no tokens routing it. The answer is added to the
 * conversation (so you can ask follow-ups) without starting a main-session turn.
 * Takes precedence over prompts/research.md. Installed by pi-config.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

const AGENT_FILE = "{{AGENT_DIR}}/agents/researcher.md";

type Agent = { model?: string; tools?: string; prompt: string };

function readAgent(file: string): Agent {
	const text = fs.readFileSync(file, "utf8").replace(/^﻿/, "");
	const m = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/.exec(text);
	if (!m) return { prompt: text };
	const field = (name: string) => {
		const line = m[1].split(/\r?\n/).find((l) => l.startsWith(`${name}:`));
		const v = line?.slice(name.length + 1).trim();
		return v ? v : undefined;
	};
	const tools = field("tools")
		?.split(",")
		.map((t) => t.trim())
		.filter(Boolean)
		.join(",");
	return { model: field("model"), tools: tools || undefined, prompt: m[2].trim() };
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("research", {
		description: "Research a question with the researcher agent directly (web by default): /research <question>",
		handler: async (args, ctx) => {
			const question = (args ?? "").trim();
			if (!question) return ctx.ui.notify("Usage: /research <question>", "warning");
			await ctx.waitForIdle();

			let agent: Agent;
			try {
				agent = readAgent(AGENT_FILE);
			} catch (e) {
				return ctx.ui.notify(`Can't read ${AGENT_FILE}: ${e instanceof Error ? e.message : String(e)}`, "error");
			}

			let dir = "";
			try {
				dir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-research-"));
				const promptFile = path.join(dir, "researcher.md");
				fs.writeFileSync(promptFile, agent.prompt);
				const argv = ["-p", "--no-session"];
				if (agent.model) argv.push("--model", agent.model);
				if (agent.tools) argv.push("--tools", agent.tools);
				argv.push("--append-system-prompt", promptFile, `Task: ${question}`);

				ctx.ui.notify(`Researching with ${agent.model ?? "the default model"}…`, "info");
				const r = await pi.exec("pi", argv, { cwd: ctx.cwd, timeout: 15 * 60_000 });
				const out = (r.stdout ?? "").trim() || (r.stderr ?? "").trim() || "(no output)";
				pi.sendMessage(
					{ customType: "research", content: `**/research** ${question}\n\n${out}`, display: true },
					{ triggerTurn: false },
				);
				if (r.code !== 0) ctx.ui.notify(`The researcher exited with an error (code ${r.code}) — its output is above.`, "warning");
			} catch (e) {
				ctx.ui.notify(`research failed to run: ${e instanceof Error ? e.message : String(e)}`, "error");
			} finally {
				if (dir) fs.rmSync(dir, { recursive: true, force: true });
			}
		},
	});
}
