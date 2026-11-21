/**
 * zsh-bang — your `!` and `!!` commands run in zsh with your ~/.zshrc (aliases, functions, PATH),
 * like your terminal. The AI agents' bash tool is unchanged (they write bash).
 * Turn off for this session: /zsh off   (back on: /zsh on). Installed by pi-config.
 */
import { createLocalBashOperations, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ZSH = "{{ZSH}}";
const q = (s: string) => `'${s.replace(/'/g, `'\\''`)}'`;

export default function (pi: ExtensionAPI) {
	let enabled = true;

	pi.on("user_bash", (_event) => {
		if (!enabled) return;
		const local = createLocalBashOperations();
		return {
			operations: {
				exec(command, cwd, options) {
					// interactive zsh = loads ~/.zshrc; no Oh My Zsh update prompts inside pi
					return local.exec(`DISABLE_AUTO_UPDATE=true exec ${q(ZSH)} -i -c ${q(command)}`, cwd, options);
				},
			},
		};
	});

	pi.registerCommand("zsh", {
		description: "Run your ! commands in zsh (with ~/.zshrc) or bash: /zsh on|off",
		handler: async (args, ctx) => {
			const a = (args ?? "").trim();
			if (a === "off") enabled = false;
			else if (a === "on") enabled = true;
			ctx.ui.notify(`! commands run in ${enabled ? "zsh (with ~/.zshrc)" : "bash"}`, "info");
		},
	});
}
