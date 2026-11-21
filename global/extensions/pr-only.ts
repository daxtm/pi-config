/**
 * pr-only — what the AI may NOT do (main session, every subagent, headless runs):
 *   - merge, approve, review or auto-merge a PR
 *   - delete branches (local or remote) or repos; change repo visibility, rulesets or branch protection
 *   - push to main/master/test, or commit/merge while on one of them
 *   - edit the deployed pi setup (~/.pi/agent, ~/.local/share/pi-config) — change the pi-config
 *     project instead, so every config change goes branch → PR → your merge
 * The kit's own scripts (/ship, pikit, pi-test-branch) run outside the AI's tools and aren't affected,
 * and neither are commands you type yourself with `!`. Installed by pi-config.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import * as os from "node:os";
import * as path from "node:path";

const PROTECTED = /^(main|master|test)$/;
// `git`, optional global options (-C dir, -c k=v, --foo), then the subcommand.
const G = String.raw`\bgit(?:\s+(?:-[Cc]\s+\S+|--?[\w-]+(?:=\S+)?))*\s+`;
const sub = (name: string, rest = "") => new RegExp(G + name + String.raw`\b` + rest);
const WRITE_METHOD = String.raw`(-X|--method)\s*(POST|PUT|PATCH|DELETE)\b`;

const RULES: { re: RegExp; reason: string }[] = [
	{ re: /\bgh\s+pr\s+(merge|review)\b/, reason: "Merging and reviewing PRs is the user's job. Open the PR (/ship) and stop." },
	{ re: /\bgh\s+api\b[^\n]*\/pulls\/\d+\/(merge|reviews)\b/, reason: "Merging/approving PRs via the API is the user's job." },
	{ re: /\bgh\s+api\b[^\n]*\b(mergePullRequest|enablePullRequestAutoMerge|addPullRequestReview|submitPullRequestReview)\b/i, reason: "Merging/approving PRs is the user's job." },
	{ re: /\bgh\s+repo\s+(delete|archive|rename)\b|\bgh\s+repo\s+edit\b[^\n]*--visibility\b/, reason: "Deleting, archiving, renaming or re-publishing repos is the user's job." },
	{ re: new RegExp(String.raw`\bgh\s+api\b[^\n]*(${WRITE_METHOD}[^\n]*\/(rulesets|protection)\b|\/(rulesets|protection)\b[^\n]*${WRITE_METHOD})`, "i"), reason: "Changing GitHub rulesets/protection is done by pi-gh-setup, not the AI." },
	{ re: sub("branch", String.raw`[^\n;&|]*\s(-d|-D|--delete)(\s|$)`), reason: "Deleting branches is the user's job (they choose it when closing the PR)." },
	{ re: sub("push", String.raw`[^\n;&|]*(\s--delete\b|\s-d\b|\s:\S+)`), reason: "Deleting remote branches is the user's job (they choose it when closing the PR)." },
	{ re: /\bgh\s+api\b[^\n]*(-X|--method)\s*DELETE\b[^\n]*\/git\/refs\//i, reason: "Don't delete branches via the API." },
	{ re: sub("push", String.raw`[^\n;&|]*[\s:+](refs/heads/)?(main|master|test)(\s|$|[;&|])`), reason: "Never push to main/master/test. Push the feature branch; /ship opens the PR." },
];

const GIT_WRITE = [sub("push"), sub("commit"), sub("merge")];
const home = os.homedir();
const DEPLOYED = [path.join(home, ".pi", "agent"), path.join(home, ".local", "share", "pi-config")];

export default function (pi: ExtensionAPI) {
	const git = async (cwd: string, args: string[]) => {
		try {
			const r = await pi.exec("git", args, { cwd, timeout: 3000 });
			return r.code === 0 ? r.stdout.trim() : null;
		} catch {
			return null;
		}
	};

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName === "write" || event.toolName === "edit") {
			const p = String((event.input as { path?: unknown }).path ?? "");
			const abs = path.resolve(ctx.cwd, p.startsWith("~/") ? path.join(home, p.slice(2)) : p);
			if (DEPLOYED.some((d) => abs === d || abs.startsWith(d + path.sep))) {
				return { block: true, reason: `pr-only: ${abs} is the deployed pi setup. Change the pi-config project instead (\`pikit path\`), on a branch.` };
			}
			return;
		}
		if (event.toolName !== "bash") return;
		const command = String((event.input as { command?: unknown }).command ?? "");
		for (const rule of RULES) {
			if (rule.re.test(command)) return { block: true, reason: `pr-only: ${rule.reason}` };
		}
		if (GIT_WRITE.some((re) => re.test(command))) {
			const branch = (await git(ctx.cwd, ["branch", "--show-current"])) ?? "";
			if (PROTECTED.test(branch) && (await git(ctx.cwd, ["rev-parse", "--verify", "HEAD"])) !== null) {
				return { block: true, reason: `pr-only: you're on ${branch}. Start a branch first: pi-branch <feat|fix|chore|docs>/<slug>` };
			}
		}
	});
}
