# Changelog

All notable changes to NSP.ClientScripts are documented here. Versions follow
[SemVer](https://semver.org/). `0.x` until it has real use outside NSP.

## 0.1.6

- `ToolShim` recipe v2, with three opt-in switches on `New-NSPToolShim`. Without them a shim
  behaves as before.
  - `-StartInShimFolder`: the tool starts in the shim's folder instead of System32.
  - `-PauseOnExit`: waits for Enter after the tool returns, and reports a failure instead of closing.
  - `-WithCmd`: also writes a double-clickable `<name>.cmd` beside the shim.
- Used by NSP.SSLCertificates 0.2.0 for the certificate-install shim it writes next to the PFX.

## 0.1.5

- `HuntressInstaller` recipe v4: `LocalDirectory` - the folder a GPO copies the script into. Every run first
  limits it to SYSTEM and Administrators (ProgramData is readable by all users; the copy carries the account key).

## 0.1.4

- `HuntressInstaller` recipe v3: an installed agent is checked, not just found - **orphaned** (`bad status code: 401`
  in the agent log's last lines) or registered to **another account** is re-registered (the new installer is
  downloaded and signature-checked first, then `Uninstall.exe /S` and the registry key go, then a fresh install),
  at most once per `RetryDays` (default 7) per computer; registered to **another organization** is reported only.
  Status values: Installed, Reinstalled, AlreadyInstalled, OrgMismatch, Orphaned, AccountMismatch, Failed.
- Also: checks for an installed agent before starting a transcript (a GPO task
  runs it at every unlock), names transcripts by computer, and with the new `ReportDirectory` (a UNC
  folder) writes `Status\<COMPUTER>.json` on every run and copies install transcripts to
  `Transcripts\`. Used by NSP.ActiveDirectory's `Import-NSPADGpoRecipe -Recipe Huntress`.

## 0.1.3

- Release routine: `tools\Publish-ToGallery.ps1` now runs `Publish-NSPModule` from NSP.RepoTools, the checks every NSP module shares (including a client-reference sweep of the Git history). No change to the module itself.

## 0.1.2

- New recipes `ControlInstaller` (ConnectWise Control access agent, from the Cookbook prototype) and
  `HuntressInstaller` (Huntress agent). Both verify the installer's Authenticode signature and signer
  before running it, install silently, keep a transcript and exit 0/1.

## 0.1.1

- From the 2026-10-02 review: removed an unused copy of the sibling-module loader (this module needs
  no other NSP module), and the loader dot-sources files in name order.

## 0.1.0

First release.

The other NSP modules it needs are installed from the PowerShell Gallery the first time they're needed,
so `Install-Module` of this one module is enough. Set `NSP_NO_AUTOINSTALL=1` to turn that off.
