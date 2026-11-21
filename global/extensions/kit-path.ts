/**
 * kit-path — inside pi (main session, subagents, headless runs) the kit's tools come first on PATH:
 * the pinned `openspec`, and pi-branch / pi-ship / pikit from ~/.local/bin. Your shell's PATH outside
 * pi is unchanged. Installed by pi-config.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const FIRST = ["{{KIT_NPM_BIN}}", "{{HOME_BIN}}"];

export default function (_pi: ExtensionAPI) {
	const rest = (process.env.PATH ?? "").split(":").filter((p) => p && !FIRST.includes(p));
	process.env.PATH = [...new Set(FIRST), ...rest].join(":");
}
