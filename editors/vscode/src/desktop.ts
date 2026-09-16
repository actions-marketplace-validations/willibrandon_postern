import { access, chmod } from "node:fs/promises";
import { join } from "node:path";
import * as readline from "node:readline";
import * as vscode from "vscode";
import {
  LanguageClient,
  TransportKind,
  type LanguageClientOptions,
  type ServerOptions,
  type StdioOptions,
} from "vscode-languageclient/node";
import { affectsServer, clientOptions, outputChannelName } from "./common.js";

let client: LanguageClient | undefined;

export async function activate(context: vscode.ExtensionContext): Promise<void> {
  const output = vscode.window.createOutputChannel(outputChannelName, { log: true });
  context.subscriptions.push(output);
  output.info("Activating Postern extension in the desktop extension host.");

  await start(context, output);

  context.subscriptions.push(
    vscode.commands.registerCommand("postern.restartServer", async (): Promise<void> => {
      output.info("Restarting Postern language server.");
      await stop();
      await start(context, output);
    }),
    vscode.commands.registerCommand("postern.showOutput", (): void => {
      output.show(true);
    }),
    vscode.workspace.onDidChangeConfiguration((event): void => {
      if (!affectsServer(event)) return;
      void (async (): Promise<void> => {
        output.info("Postern settings changed. Restarting language server.");
        await stop();
        await start(context, output);
      })();
    }),
  );
}

export async function deactivate(): Promise<void> {
  await stop();
}

async function start(
  context: vscode.ExtensionContext,
  output: vscode.LogOutputChannel,
): Promise<void> {
  const command = await resolveServer(context, output);
  const serverOptions: ServerOptions = {
    command,
    args: [],
    transport: TransportKind.stdio,
  };
  const options: LanguageClientOptions = {
    ...clientOptions(output),
    stdioOptions: stdioOptions(output),
  };
  client = new LanguageClient("postern", "Postern", serverOptions, options);
  context.subscriptions.push(client);
  output.info("Starting Postern language server.");
  try {
    await client.start();
    output.info("Postern language server started.");
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    output.error(`Postern language server failed to start with "${command}": ${message}`);
    void vscode.window.showErrorMessage(
      `Postern could not start "${command}". Set postern.path to the postern executable.`,
    );
  }
}

async function stop(): Promise<void> {
  const current = client;
  client = undefined;
  await current?.stop();
}

// The client library logs every line a server writes to stderr as an error.
// The server's own log lines say which level they are, and anything else on
// stderr, such as the runtime wrapper removing an older payload, is a notice.
function stdioOptions(output: vscode.LogOutputChannel): Required<StdioOptions> {
  const pipe = (input: NodeJS.ReadableStream): void => {
    readline
      .createInterface({ input, crlfDelay: Infinity, terminal: false, historySize: 0 })
      .on("line", (line: string): void => {
        if (line.trim() === "") return;
        if (line.includes("[error]")) output.error(line);
        else if (/\[warn(?:ing)?\]/u.test(line)) output.warn(line);
        else output.info(line);
      });
  };
  return { stdout: pipe, stderr: pipe };
}

async function resolveServer(
  context: vscode.ExtensionContext,
  output: vscode.LogOutputChannel,
): Promise<string> {
  const configured = vscode.workspace.getConfiguration("postern").get<string>("path", "").trim();
  if (configured !== "") {
    output.info(`Using postern from the postern.path setting: ${configured}`);
    return configured;
  }

  const bundled = join(
    context.extensionPath,
    "server",
    process.platform === "win32" ? "postern.exe" : "postern",
  );
  try {
    await access(bundled);
  } catch {
    output.info(
      "This package has no bundled postern for this platform. Using postern from the PATH.",
    );
    return "postern";
  }
  if (process.platform !== "win32") {
    // The VSIX is a zip archive, which does not always preserve the executable bit.
    await chmod(bundled, 0o755).catch(() => undefined);
  }
  return bundled;
}
