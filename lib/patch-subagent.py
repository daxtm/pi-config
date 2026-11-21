"""Add opt-in build sessions to the installed Pi subagent example."""
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()

def replace(old, new):
    global source
    if source.count(old) != 1:
        sys.exit(f"Cannot patch this Pi subagent example: {old!r}")
    source = source.replace(old, new)

replace('const PER_TASK_OUTPUT_CAP = 50 * 1024;', 'const PER_TASK_OUTPUT_CAP = 4 * 1024;')
source = 'import { createHash } from "node:crypto";\nimport { execFileSync } from "node:child_process";\n' + source
replace('): Promise<SingleResult> {\n\tif (signal?.aborted)', '\ttaskId?: string,\n): Promise<SingleResult> {\n\tif (signal?.aborted)')
replace('const args: string[] = ["--mode", "json", "-p", "--no-session"];', '''const args: string[] = ["--mode", "json", "-p"];
	let sessionDir: string | undefined;
	if (taskId && agentName === "build") {
		const git = (...args: string[]) => execFileSync("git", args, { cwd: effectiveCwd, encoding: "utf8" }).trim();
		let branch: string;
		try {
			branch = git("branch", "--show-current");
		} catch {
			return createUnstartedResult(agentName, task, step, "failed", "A builder task ID requires a Git work branch.");
		}
		if (!branch || ["main", "master", "test"].includes(branch)) {
			return createUnstartedResult(agentName, task, step, "failed", "Switch to the task branch before starting a builder session.");
		}
		const key = createHash("sha256").update(JSON.stringify([effectiveCwd, branch, taskId, agent.model, agent.systemPrompt])).digest("hex");
		sessionDir = path.join(getAgentDir(), "builder-sessions", key);
		fs.mkdirSync(sessionDir, { recursive: true, mode: 0o700 });
		args.push("--session-dir", sessionDir, "--continue");
	} else {
		args.push("--no-session");
	}''')
replace('proc = spawn(invocation.command, invocation.args, {', '''const command = sessionDir ? "flock" : invocation.command;
				const argv = sessionDir
					? ["--no-fork", "--nonblock", "--conflict-exit-code", "75", path.join(sessionDir, "lock"), invocation.command, ...invocation.args]
					: invocation.args;
				proc = spawn(command, argv, {''')
replace('const SubagentParams = Type.Object({', '''const SubagentParams = Type.Object({
	taskId: Type.Optional(Type.String({ maxLength: 128, description: "Single build only. Reuse the same task ID for follow-ups on the same branch. Use a new ID for unrelated work." })),''')
replace('makeDetails("single"),\n\t\t\t\t);','makeDetails("single"),\n\t\t\t\t\tparams.taskId,\n\t\t\t\t);')
path.write_text(source)
