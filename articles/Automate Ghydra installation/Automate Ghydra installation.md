---
title: Ghidra on Linux Zero Fuss Install
tags: [ghidra, reverse-engineering, linux, java]
published: true
cover_image: <https://blog.attify.com/content/images/size/w1600/2021/10/aQYgUYwnCsM.png>
# devto_id: will be set automatically
---

## Ghidra on Linux: Zero Fuss Install

A straightforward, distro-agnostic way to install Ghidra under /opt without touching your system Java alternatives, plus environment wiring that makes upgrades safe and re-runs idempotent.

Disclaimer:
This post assumes you’re comfortable using the terminal with sudo, have basic knowledge of environment variables, and can install a few command‑line tools (wget, unzip, tar) with your distro’s package manager.

## What you’ll get

- Ghidra 11.4.1 installed under `/opt/ghidra` (atomic replace with backups on re-run)
- A local Temurin (Adoptium) JDK 21 under `/opt/java-temurin` without touching system alternatives
- `GHIDRA_INSTALL_DIR` and `GHIDRA_JAVA_HOME` added to your shell RC (`~/.bashrc` or `~/.zshrc`)
- A process that is safe to re-run for upgrades and repairs

Note: The approach works across common Linux distributions. The automated script tries to install helper tools via `apt` when available, but it gracefully skips on other distros—so on RPM/Arch-based systems, just install `wget`, `unzip`, and `tar` via your package manager first.

Customization tip:
You can change the Ghidra version, release date, download URL, or even inject checksum verification simply by editing the constants at the top of the referenced script (`GHIDRA_VERSION`, `GHIDRA_DATE`, `GHIDRA_URL`, `GHIDRA_SHA256`, plus the Java bits like `TEMURIN_MAJOR`, `TEMURIN_API_URL`, `TEMURIN_SHA256`). Adjust them, re-run the script, and it will perform an atomic upgrade while backing up previous installs.

## 1) Prerequisites

Install the few tools we’ll use to fetch and unpack files.

- Debian/Ubuntu:
  - `sudo apt-get update && sudo apt-get install -y wget unzip tar`
- Fedora/RHEL/CentOS:
  - `sudo dnf install -y wget unzip tar` (or `yum` on older releases)
- Arch/Manjaro:
  - `sudo pacman -S --needed wget unzip tar`

Also ensure you have sudo privileges.

## 2) Install a private Temurin JDK 21 under /opt

Why: Ghidra runs best on a modern LTS JDK. Installing a local Temurin JDK avoids messing with system-wide Java alternatives and keeps Ghidra isolated.

Key details:

- Location: `/opt/java-temurin/<jdk-version>` with a stable symlink at `/opt/java-temurin/current`
- Source: [Adoptium API](https://api.adoptium.net/) for the latest GA JDK 21 (linux x64, HotSpot) — or browse [Temurin releases](https://adoptium.net/temurin/releases)
- Optional integrity: You can verify checksums if you provide `TEMURIN_SHA256`

Steps (high level):

1. Create the base directory: `/opt/java-temurin`
2. Download the latest GA tarball for JDK 21 from Adoptium’s API
3. (Optional) Verify the tarball with `sha256sum`
4. Extract to a versioned folder under `/opt/java-temurin` and update the `current` symlink atomically

On re-run, the previous version is backed up and replaced. The stable `current` symlink is what we’ll point Ghidra to.

## 3) Install Ghidra 11.4.1 under /opt/ghidra

Ghidra publishes zip archives per release. We’ll unpack into `/opt/ghidra` and keep upgrades atomic.

Key details:

- Download from the official NSA GitHub [Ghidra releases](https://github.com/NationalSecurityAgency/ghidra/releases) page for 11.4.1
- Optional integrity: provide `GHIDRA_SHA256` from the release page to verify with `sha256sum`
- The process backs up any existing `/opt/ghidra` before replacing it

Steps (high level):

1. Download the Ghidra 11.4.1 zip
2. (Optional) Verify its checksum
3. Unzip into a temporary directory, then move to `/opt/ghidra` atomically

## 4) Wire your shell environment

Two environment variables make life easier:

- `GHIDRA_INSTALL_DIR`: points to `/opt/ghidra`
- `GHIDRA_JAVA_HOME`: points to the Temurin JDK (preferred) or falls back to an existing valid `JAVA_HOME`

What gets added to your shell RC (`~/.bashrc` for bash, `~/.zshrc` for zsh):

- `export GHIDRA_INSTALL_DIR=/opt/ghidra`
- `export PATH="$PATH:$GHIDRA_INSTALL_DIR/support"` (so `analyzeHeadless` is on PATH)
- `export GHIDRA_JAVA_HOME=/opt/java-temurin/current` (or another detected JDK)

Open a new shell or `source ~/.bashrc` / `source ~/.zshrc` to apply the changes.

### Optional: add Ghidra binaries to PATH

If you want to call both the headless tools and the GUI launcher from anywhere, add both the `support` directory and the root install dir to PATH.

- Bash:

```bash
echo 'export GHIDRA_INSTALL_DIR=/opt/ghidra' >> ~/.bashrc
echo 'export PATH="$PATH:$GHIDRA_INSTALL_DIR/support:$GHIDRA_INSTALL_DIR"' >> ~/.bashrc
source ~/.bashrc
```

- Zsh:

```bash
echo 'export GHIDRA_INSTALL_DIR=/opt/ghidra' >> ~/.zshrc
echo 'export PATH="$PATH:$GHIDRA_INSTALL_DIR/support:$GHIDRA_INSTALL_DIR"' >> ~/.zshrc
source ~/.zshrc
```

## 5) Verify the installation

Quick checks you can run:

- Print Ghidra’s internal version from its properties file
- Run a short, non-interactive headless/CLI command to validate scripts are reachable

Examples:

```bash
grep -E '^application\.version=' /opt/ghidra/Ghidra/application.properties | cut -d'=' -f2

"$GHIDRA_INSTALL_DIR"/support/analyzeHeadless -version

"$GHIDRA_INSTALL_DIR"/ghidraRun -h
```

If those commands execute without errors, you’re set.

## 6) Upgrades and re-runs

This setup is designed to be re-run safely:

- Temurin: new JDK drops into a versioned folder, `current` symlink is updated atomically
- Ghidra: any existing `/opt/ghidra` is backed up to `/opt/ghidra.bak-<timestamp>` before replacement
- Env: `GHIDRA_JAVA_HOME` is updated or inserted once; subsequent runs update it if needed

To upgrade to a newer Ghidra release, adjust the version/date variables (or pull the latest script) and re-run. Your environment variables remain compatible.

## 7) Uninstall or roll back

- Remove Ghidra: `sudo rm -rf /opt/ghidra`
- Remove Temurin: `sudo rm -rf /opt/java-temurin`
- Clean your shell RC: remove the lines that export `GHIDRA_INSTALL_DIR`, modify `PATH`, and `GHIDRA_JAVA_HOME`
- To roll back: if you see a recent backup like `/opt/ghidra.bak-YYYYmmddHHMMSS`, you can move it back to `/opt/ghidra`

## 8) Troubleshooting

- Missing tools on non-Debian distros: install `wget`, `unzip`, `tar` via your package manager
- Permission denied under `/opt`: you need `sudo` privileges for system locations
- GUI on servers/WSL: Ghidra’s GUI requires an X server; use headless mode with `analyzeHeadless` if you don’t have a display
- Java detection: if Ghidra prompts for a JDK, ensure `GHIDRA_JAVA_HOME` is set and points to a valid JDK with `bin/java`

## 9) Optional: headless workflow teaser

Ghidra ships `analyzeHeadless` for automation. For example, to run a simple analysis in a CI runner, you can call it with a temporary project directory and scripts. This is out of scope for this post, but the steps above already place the tool on your PATH for easy use.

## Full automation script (reference)

All the steps above are automated in a single idempotent script that you can read and run:

- Script: <https://github.com/andremmfaria/rexis/blob/main/scripts/install-ghidra.sh>

What it does for you:

- Installs Temurin JDK 21 under `/opt/java-temurin` and creates a stable `current` symlink
- Downloads and installs Ghidra 11.4.1 under `/opt/ghidra` with atomic replace and timestamped backups
- Wires `GHIDRA_INSTALL_DIR`, updates `PATH`, and sets `GHIDRA_JAVA_HOME`
- Verifies the installation non‑interactively

Safe to re-run. If you want checksum verification for either download, export `GHIDRA_SHA256` and/or `TEMURIN_SHA256` before running it.

Thanks for reading, and happy reversing!

## Further references

- Ghidra official site: <https://ghidra-sre.org/>
- Ghidra GitHub repository: <https://github.com/NationalSecurityAgency/ghidra>
- Ghidra releases (official zips + checksums): <https://github.com/NationalSecurityAgency/ghidra/releases>
- Ghidra Getting Started: <https://github.com/NationalSecurityAgency/ghidra/blob/master/GhidraDocs/GettingStarted.md>
- Adoptium Temurin releases: <https://adoptium.net/temurin/releases>
- Adoptium API (programmatic downloads): <https://api.adoptium.net/>
