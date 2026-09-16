import * as vscode from "vscode";
import type { DocumentSelector, LanguageClientOptions } from "vscode-languageclient";

export const outputChannelName = "Postern Language Server";

export const documentSelector: DocumentSelector = [
  { language: "postgresql-conf" },
  { language: "pg-hba" },
  { language: "pg-ident" },
];

export interface InitializationOptions {
  pg?: number;
  connectionString?: string;
}

export function initializationOptions(): InitializationOptions {
  const config = vscode.workspace.getConfiguration("postern");
  const options: InitializationOptions = {};
  const pg = config.get<number | null>("pg", null);
  if (typeof pg === "number" && Number.isInteger(pg)) options.pg = pg;
  const connectionString = config.get<string>("connectionString", "").trim();
  if (connectionString !== "") options.connectionString = connectionString;
  return options;
}

export function clientOptions(output: vscode.LogOutputChannel): LanguageClientOptions {
  return {
    documentSelector,
    initializationOptions: initializationOptions(),
    outputChannel: output,
    markdown: { isTrusted: false },
  };
}

export function affectsServer(event: vscode.ConfigurationChangeEvent): boolean {
  return (
    event.affectsConfiguration("postern.path") ||
    event.affectsConfiguration("postern.pg") ||
    event.affectsConfiguration("postern.connectionString")
  );
}
