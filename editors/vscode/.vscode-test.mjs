import { defineConfig } from "@vscode/test-cli";

export default defineConfig({
  files: "out/test/suite/**/*.test.js",
  workspaceFolder: "test/fixtures",
  version: process.env.VSCODE_VERSION ?? "stable",
  launchArgs: ["--disable-extensions"],
  mocha: { ui: "tdd", timeout: 90_000 },
});
