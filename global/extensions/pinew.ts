/**
 * /pinew — set up a project (same as `pinew` in the terminal) and move this pi session into it.
 *   /pinew <name>            create ~/workspace/projects/<name>
 *   /pinew /abs/path         set up that folder
 *   /pinew <name> --live <path> [--live-branch <b>]
 * All setup logic lives in {{KIT_DIR}}/new-project.sh. Installed by pi-config.
 */
import { type ExtensionAPI, SessionManager } from "@earendil-works/pi-coding-agent";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

const SCRIPT = "{{KIT_DIR}}/new-project.sh";
const q = (s: string) => `'${s.replace(/'/g, `'\\''`)}'`;

export default function (pi: ExtensionAPI) {
	pi.registerCommand("pinew", {
		description: "Set up a new project (or an existing folder) and move this session into it: /pinew <name|/path> [--live <path>]",
		handler: async (args, ctx) => {
			const argv = (args ?? "").trim().split(/\s+/).filter(Boolean).map((a) => (a.startsWith("~/") ? path.join(os.homedir(), a.slice(2)) : a));
			if (argv.length === 0) argv.push(ctx.cwd);
			await ctx.waitForIdle();
			const cdFile = path.join(os.tmpdir(), `pinew-${process.pid}-${Date.now()}`);
			ctx.ui.notify(`Setting up ${argv[0]}…`, "info");
			const r = await pi.exec("bash", ["-c", `PINEW_CD_FILE=${q(cdFile)} ${q(SCRIPT)} ${argv.map(q).join(" ")}`], { cwd: ctx.cwd, timeout: 600_000 });
			const out = [(r.stdout ?? "").trim(), (r.stderr ?? "").trim()].filter(Boolean).join("\n");
			let dir = "";
			try { dir = fs.readFileSync(cdFile, "utf8").trim(); fs.rmSync(cdFile, { force: true }); } catch { /* not written */ }
			if (r.code !== 0 || !dir) return ctx.ui.notify(`pinew failed:\n${out}`, "error");

			// A session for the new folder, then switch to it (like /resume into another project).
			// (pi only writes a session file once it has a message, so write the empty one ourselves)
			const sm = SessionManager.create(dir);
			sm.appendSessionInfo(path.basename(dir));
			const file = sm.getSessionFile();
			if (file && !fs.existsSync(file)) {
				try {
					fs.mkdirSync(path.dirname(file), { recursive: true });
					const lines = [sm.getHeader(), ...sm.getEntries()].filter(Boolean).map((e) => JSON.stringify(e));
					fs.writeFileSync(file, lines.join("\n") + "\n", { flag: "wx" });
				} catch { /* reported below */ }
			}
			if (!file || !fs.existsSync(file)) {
				return ctx.ui.notify(`${out}\n\nProject ready, but the session couldn't be moved. Quit and run: cd ${dir} && pi`, "warning");
			}
			const summary = out.split("\n").filter((l) => !/^\s*(Next:|cd |New project:|Existing project:|GitHub remote)/.test(l)).join("\n");
			await ctx.switchSession(file, {
				withSession: async (c) => {
					c.ui.notify(`${summary}\n\nNow working in ${dir}`, "info");
				},
			});
		},
	});
}
