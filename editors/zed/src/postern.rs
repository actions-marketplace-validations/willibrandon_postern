//! The Zed extension for Postern. It finds `postern` on the PATH, or
//! downloads the binary for this platform from the latest GitHub release.

use std::fs;
use zed::settings::LspSettings;
use zed_extension_api::{self as zed, LanguageServerId, Result, serde_json};

const REPOSITORY: &str = "willibrandon/postern";

struct PosternExtension {
    cached_binary_path: Option<String>,
}

impl PosternExtension {
    fn binary_path(
        &mut self,
        language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<String> {
        if let Some(path) = worktree.which("postern") {
            return Ok(path);
        }

        if let Some(path) = &self.cached_binary_path
            && fs::metadata(path).is_ok_and(|stat| stat.is_file())
        {
            return Ok(path.clone());
        }

        zed::set_language_server_installation_status(
            language_server_id,
            &zed::LanguageServerInstallationStatus::CheckingForUpdate,
        );
        let release = zed::latest_github_release(
            REPOSITORY,
            zed::GithubReleaseOptions {
                require_assets: true,
                pre_release: false,
            },
        )?;

        // Release assets are named postern-<version>-<target>, with .exe on Windows.
        let (os, arch) = zed::current_platform();
        let target = match (os, arch) {
            (zed::Os::Mac, zed::Architecture::Aarch64) => "darwin-arm64",
            (zed::Os::Mac, _) => "darwin-x64",
            (zed::Os::Linux, zed::Architecture::Aarch64) => "linux-arm64",
            (zed::Os::Linux, _) => "linux-x64",
            (zed::Os::Windows, _) => "win32-x64.exe",
        };
        let version = release.version.trim_start_matches('v');
        let asset_name = format!("postern-{version}-{target}");
        let asset = release
            .assets
            .iter()
            .find(|asset| asset.name == asset_name)
            .ok_or_else(|| format!("the release has no asset named {asset_name}"))?;

        let version_dir = format!("postern-{version}");
        let binary_path = format!("{version_dir}/{asset_name}");
        if !fs::metadata(&binary_path).is_ok_and(|stat| stat.is_file()) {
            zed::set_language_server_installation_status(
                language_server_id,
                &zed::LanguageServerInstallationStatus::Downloading,
            );
            fs::create_dir_all(&version_dir)
                .map_err(|err| format!("failed to create {version_dir}: {err}"))?;
            zed::download_file(
                &asset.download_url,
                &binary_path,
                zed::DownloadedFileType::Uncompressed,
            )
            .map_err(|err| format!("failed to download {asset_name}: {err}"))?;
            zed::make_file_executable(&binary_path)?;

            // Older downloads are no longer needed.
            let entries =
                fs::read_dir(".").map_err(|err| format!("failed to list the extension directory: {err}"))?;
            for entry in entries.flatten() {
                if entry.file_name().to_str() != Some(&version_dir) {
                    fs::remove_dir_all(entry.path()).ok();
                }
            }
        }

        self.cached_binary_path = Some(binary_path.clone());
        Ok(binary_path)
    }
}

impl zed::Extension for PosternExtension {
    fn new() -> Self {
        Self {
            cached_binary_path: None,
        }
    }

    fn language_server_command(
        &mut self,
        language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        Ok(zed::Command {
            command: self.binary_path(language_server_id, worktree)?,
            args: vec![],
            env: Default::default(),
        })
    }

    // `"lsp": { "postern": { "initialization_options": { "reportTrust": false } } }`
    // in Zed's settings reaches the server.
    fn language_server_initialization_options(
        &mut self,
        _language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<Option<serde_json::Value>> {
        let settings = LspSettings::for_worktree("postern", worktree)?;
        Ok(settings.initialization_options)
    }
}

zed::register_extension!(PosternExtension);
