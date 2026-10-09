# Changelog

All notable changes to NSP.ClientScripts are documented here. Versions follow
[SemVer](https://semver.org/). `0.x` until it has real use outside NSP.

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
