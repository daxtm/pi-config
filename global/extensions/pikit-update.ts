/**
 * pikit-update — when you start pi, deploys pi-config if the branch it follows (main) moved, e.g.
 * after you merged a pi-config PR. Runs in the background; tells you when something changed.
 * No model, no tokens. Installed by pi-config.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PIKIT = "{{KIT_DIR}}/bin/pikit";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		if (!ctx.hasUI || process.env.PIKIT_DEPLOYING) return; // not in subagents, not during a deploy
		void (async () => {
			try {
				const r = await pi.exec(PIKIT, ["apply", "--if-changed", "--quiet"], { timeout: 10 * 60_000 });
				const out = [(r.stdout ?? "").trim(), (r.stderr ?? "").trim()].filter(Boolean).join("\n");
				if (r.code !== 0) ctx.ui.notify(`pi-config update failed:\n${out}`, "warning");
				else if (out) ctx.ui.notify(out, "info");
			} catch {
				// background upkeep must never disturb the session
			}
		})();
	});
}
