/**
 * branch-tools — automatic `test` branch + live copy, and quick branch switching. No model, no tokens.
 *
 * Automatic (in projects set up with new-project.sh / pinew):
 *   - every feature branch is merged into `test` (a normal branch, pushed to GitHub) whenever it gets
 *     new commits; conflicts are resolved by the model; main is never ahead of test
 *     (git hooks on every commit, plus here: on startup, after every pi turn, and once a minute)
 *   - ComfyUI nodes get a live copy in <ComfyUI>/custom_nodes/<project> automatically; any live copy
 *     follows its branch (default `test`) and is updated with it
 *   - the footer shows the test branch and live copy state; conflicts pop up as a notification
 *
 * Commands:
 *   /switch [branch]              go to a branch (default main) and pull
 *   /live                         show the live copy
 *   /live set <path> [branch]     one-time: make <path> a live copy, e.g. ~/ComfyUI/custom_nodes/my-node
 *   /live <branch>                make the live copy follow another branch (test, main, feat/x, …)
 *   /live restart <command>       run <command> after each live update (e.g. restart ComfyUI); "/live restart" = off
 *   /live off                     stop managing the live copy (folder left as is)
 *   /cleanup [--dry-run]          delete local branches that no longer exist on GitHub (only when you run it)
 *   /test-branch                  show the state of `test` (syncs now)
 *   /test-branch rebuild          start `test` over from main + the branches that exist now (drops
 *                                 abandoned work; force-pushed with lease). Only when you ask.
 *
 * Installed by pi-config; all git logic lives in {{KIT_DIR}}/bin/pi-test-branch.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SCRIPT = "{{KIT_DIR}}/bin/pi-test-branch";
const TICK_MS = 60_000;
const FETCH_EVERY_MS = 10 * 60_000;

type UI = { notify: (msg: string, level?: "info" | "warning" | "error") => void; setStatus?: (key: string, text: string | undefined) => void };
type Ctx = { cwd: string; hasUI?: boolean; ui: UI };

export default function (pi: ExtensionAPI) {
	let timer: ReturnType<typeof setInterval> | undefined;
	let lastFetch = 0;
	let running = false;
	let lastConflicts = "";
	let uiCtx: Ctx | undefined;

	const git = async (cwd: string, args: string[]) => {
		const r = await pi.exec("git", args, { cwd, timeout: 60_000 });
		return { ok: r.code === 0, out: (r.stdout ?? "").trim(), err: ((r.stderr ?? "").trim() || (r.stdout ?? "").trim()) };
	};
	const script = async (cwd: string, args: string[], timeout = 300_000) => {
		const r = await pi.exec(SCRIPT, args, { cwd, timeout });
		return { ok: r.code === 0, out: [(r.stdout ?? "").trim(), (r.stderr ?? "").trim()].filter(Boolean).join("\n") };
	};
	const isKitRepo = async (cwd: string) => (await git(cwd, ["config", "--local", "--get", "pi.kit"])).out === "true";

	async function refreshStatus(ctx: Ctx) {
		const st = await script(ctx.cwd, ["status"], 30_000);
		const lines = st.out.split("\n");
		const head = lines[0] ?? "";
		const live = lines.find((l) => l.startsWith("live copy →") || l.startsWith("live copy NOT") || l.startsWith("live copy missing") || l.startsWith("ComfyUI node detected"));
		ctx.ui.setStatus?.("test-branch", [head, live].filter(Boolean).join(" · "));
		const conflicts = lines.filter((l) => l.startsWith("conflict:") || l.includes("resolved by the model") || l.startsWith("live copy NOT") || l.startsWith("ComfyUI node detected") || l.startsWith("previous ") || l.includes("isn't managed")).join("\n");
		if (conflicts && conflicts !== lastConflicts) ctx.ui.notify(`Test branch:\n${conflicts}`, "warning");
		lastConflicts = conflicts;
	}

	async function autoSync(ctx: Ctx, opts: { fetch?: boolean } = {}) {
		if (running || !ctx.hasUI) return; // subagents (print/json mode) never run this
		running = true;
		try {
			if (!(await isKitRepo(ctx.cwd))) return;
			const fetch = opts.fetch || Date.now() - lastFetch > FETCH_EVERY_MS;
			if (fetch) lastFetch = Date.now();
			// Detached: a conflict handed to the model can take minutes; status is polled every tick.
			await pi.exec("bash", ["-c", `"$0" --quiet ${fetch ? "--fetch" : ""} >/dev/null 2>&1 &`, SCRIPT], { cwd: ctx.cwd, timeout: 10_000 });
			await refreshStatus(ctx);
		} catch {
			// background upkeep must never disturb the session
		} finally {
			running = false;
		}
	}

	pi.on("session_start", (_event, ctx) => {
		uiCtx = ctx as unknown as Ctx;
		if (!uiCtx.hasUI) return;
		void autoSync(uiCtx, { fetch: true });
		if (timer) clearInterval(timer);
		timer = setInterval(() => uiCtx && void autoSync(uiCtx), TICK_MS);
		(timer as { unref?: () => void }).unref?.();
	});
	pi.on("agent_settled", (_event, ctx) => void autoSync(ctx as unknown as Ctx));
	pi.on("session_shutdown", () => {
		if (timer) clearInterval(timer);
		timer = undefined;
	});

	// ---------------------------------------------------------------- /switch
	pi.registerCommand("switch", {
		description: "Go to a branch (default main) and pull: /switch [branch]",
		handler: async (args, ctx) => {
			const target = (args ?? "").trim() || "main";
			const top = await git(ctx.cwd, ["rev-parse", "--show-toplevel"]);
			if (!top.ok) return ctx.ui.notify("Not inside a git repository.", "error");
			const repo = top.out;
			const from = (await git(repo, ["branch", "--show-current"])).out;
			if ((await git(repo, ["status", "--porcelain"])).out) {
				return ctx.ui.notify(`Uncommitted changes on ${from || "this checkout"}. Run /commit first, then /switch ${target}.`, "warning");
			}
			const sw = await git(repo, ["switch", target]);
			if (!sw.ok) return ctx.ui.notify(`Could not switch to ${target}:\n${sw.err}`, "error");
			let note = "";
			if ((await git(repo, ["rev-parse", "--abbrev-ref", "@{u}"])).ok) {
				const pull = await git(repo, ["pull", "--ff-only"]);
				note = pull.ok ? " (pulled)" : `\nPull failed (diverged?):\n${pull.err}`;
			}
			ctx.ui.notify(`On ${target}${note}\n${(await git(repo, ["log", "-1", "--format=%h %s"])).out}`, "info");
			void autoSync(ctx as unknown as Ctx);
		},
	});

	// ---------------------------------------------------------------- /live
	pi.registerCommand("live", {
		description: "Live copy elsewhere (e.g. ComfyUI): /live | /live set <path> [branch] | /live <branch> | /live restart <cmd> | /live off",
		handler: async (args, ctx) => {
			const parts = (args ?? "").trim().split(/\s+/).filter(Boolean);
			let r;
			if (parts.length === 0) r = await script(ctx.cwd, ["status"]);
			else if (parts[0] === "set") {
				if (!parts[1]) return ctx.ui.notify("Usage: /live set <path> [branch]   (branch defaults to test)", "warning");
				r = await script(ctx.cwd, ["live-set", ...parts.slice(1, 3)]);
			} else if (parts[0] === "restart") r = await script(ctx.cwd, ["live-restart", parts.slice(1).join(" ")]);
			else if (parts[0] === "off") r = await script(ctx.cwd, ["live-off"]);
			else r = await script(ctx.cwd, ["live-branch", parts[0]]);
			ctx.ui.notify(r.out || "(no output)", r.ok ? "info" : "error");
			await refreshStatus(ctx as unknown as Ctx);
		},
	});

	// ---------------------------------------------------------------- /cleanup
	pi.registerCommand("cleanup", {
		description: "Delete local branches that no longer exist on GitHub (you deleted them there). /cleanup --dry-run = just list them",
		handler: async (args, ctx) => {
			const dry = /(^|\s)(--dry-run|dry)(\s|$)/.test((args ?? "").trim());
			const r = await script(ctx.cwd, ["cleanup", ...(dry ? ["--dry-run"] : [])], 120_000);
			ctx.ui.notify(r.out || "(no output)", r.ok ? "info" : "error");
		},
	});

	// ---------------------------------------------------------------- /test-branch
	pi.registerCommand("test-branch", {
		description: "Show the state of the `test` branch (syncs now). /test-branch rebuild = start test over from main + current branches",
		handler: async (args, ctx) => {
			if (!(await isKitRepo(ctx.cwd))) {
				return ctx.ui.notify("This project isn't set up by the kit. Run pinew in it first.", "warning");
			}
			const arg = (args ?? "").trim();
			if (arg === "rebuild" || arg === "rebuild --dry-run") {
				const rb = await script(ctx.cwd, arg.split(/\s+/), 3_600_000);
				ctx.ui.notify(rb.out, rb.ok ? "info" : "error");
				return refreshStatus(ctx as unknown as Ctx);
			}
			if (arg) return ctx.ui.notify("Usage: /test-branch [rebuild [--dry-run]]", "warning");
			const sync = await script(ctx.cwd, ["--quiet", "--fetch"], 3_600_000);
			if (!sync.ok) return ctx.ui.notify(sync.out || "Test branch sync failed", "error");
			const st = await script(ctx.cwd, ["status"]);
			ctx.ui.notify(st.out, st.out.includes("conflict:") ? "warning" : "info");
			await refreshStatus(ctx as unknown as Ctx);
		},
	});
}
