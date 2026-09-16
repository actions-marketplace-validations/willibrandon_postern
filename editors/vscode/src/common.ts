import * as vscode from "vscode";
import type {
  DocumentSelector,
  ExecuteCommandSignature,
  LanguageClientOptions,
} from "vscode-languageclient";

export const outputChannelName = "Postern Language Server";

export const documentSelector: DocumentSelector = [
  { language: "postgresql-conf" },
  { language: "pg-hba" },
  { language: "pg-ident" },
];

export interface InitializationOptions {
  pg?: number;
  connectionString?: string;
  reportTrust?: boolean;
}

export function initializationOptions(): InitializationOptions {
  const config = vscode.workspace.getConfiguration("postern");
  const options: InitializationOptions = {};
  const pg = config.get<number | null>("pg", null);
  if (typeof pg === "number" && Number.isInteger(pg)) options.pg = pg;
  const connectionString = config.get<string>("connectionString", "").trim();
  if (connectionString !== "") options.connectionString = connectionString;
  if (!config.get<boolean>("hba.reportTrust", true)) options.reportTrust = false;
  return options;
}

export function clientOptions(output: vscode.LogOutputChannel): LanguageClientOptions {
  return {
    documentSelector,
    initializationOptions: initializationOptions(),
    outputChannel: output,
    markdown: { isTrusted: false },
    middleware: {
      // The server advertises this command so every editor can run its quick
      // fix. Here it is handled in the editor, where the choice can be saved;
      // the settings listener then restarts the server.
      executeCommand: async (
        command: string,
        args: unknown[],
        next: ExecuteCommandSignature,
      ): Promise<unknown> => {
        if (command !== "postern.disableTrustHints") return next(command, args);
        await vscode.workspace
          .getConfiguration("postern")
          .update("hba.reportTrust", false, vscode.ConfigurationTarget.Global);
        output.info("Trust hints turned off in user settings (postern.hba.reportTrust).");
        return undefined;
      },
    },
  };
}

export function affectsServer(event: vscode.ConfigurationChangeEvent): boolean {
  return (
    event.affectsConfiguration("postern.path") ||
    event.affectsConfiguration("postern.pg") ||
    event.affectsConfiguration("postern.connectionString") ||
    event.affectsConfiguration("postern.hba.reportTrust")
  );
}
