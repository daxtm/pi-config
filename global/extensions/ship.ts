/**
 * /ship [branch] — runs bin/pi-ship: brings the branch up to date with main, checks and archives its
 * OpenSpec change, pushes, and opens (or updates) the PR to main. A script, not a prompt: no tokens,
 * same result every time. You merge the PR on GitHub after local checks pass. Installed by pi-config.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SCRIPT = "{{KIT_DIR}}/bin/pi-ship";

export default function (pi: ExtensionAPI) {
	pi.registerCommand("ship", {
		description: "Ship a branch: archive its finished OpenSpec change, push, open/update its PR to main — no model: /ship [branch]",
		handler: async (args, ctx) => {
			await ctx.waitForIdle();
			const argv = (args ?? "").trim().split(/\s+/).filter(Boolean).slice(0, 1);
			ctx.ui.notify(`Shipping ${argv[0] ?? "this branch"}…`, "info");
			try {
				const r = await pi.exec(SCRIPT, argv, { cwd: ctx.cwd, timeout: 45 * 60_000 });
				const out = [(r.stdout ?? "").trim(), (r.stderr ?? "").trim()].filter(Boolean).join("\n");
				ctx.ui.notify(out || "(no output)", r.code === 0 ? "info" : "error");
			} catch (e) {
				ctx.ui.notify(`ship failed to run: ${e instanceof Error ? e.message : String(e)}`, "error");
			}
		},
	});
}
