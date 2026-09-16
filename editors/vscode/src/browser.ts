import * as vscode from "vscode";
import { outputChannelName } from "./common.js";

export function activate(context: vscode.ExtensionContext): void {
  const output = vscode.window.createOutputChannel(outputChannelName, { log: true });
  context.subscriptions.push(output);
  output.info("Activating Postern extension in the web extension host.");
  output.info(
    "The Postern language server runs on desktop and remote hosts. This host provides syntax highlighting only.",
  );

  const unavailable = async (): Promise<void> => {
    await vscode.window.showInformationMessage(
      "The Postern language server is not available in a browser extension host.",
    );
  };
  context.subscriptions.push(
    vscode.commands.registerCommand("postern.restartServer", unavailable),
    vscode.commands.registerCommand("postern.disableTrustHints", unavailable),
    vscode.commands.registerCommand("postern.showOutput", (): void => {
      output.show(true);
    }),
  );
}

export function deactivate(): void {
  // Nothing to stop in the browser.
}
