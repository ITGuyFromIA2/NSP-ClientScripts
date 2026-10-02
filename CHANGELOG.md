# Changelog

All notable changes to NSP.ClientScripts are documented here. Versions follow
[SemVer](https://semver.org/). `0.x` until it has real use outside NSP.

## 0.1.1

- From the 2026-10-02 review: removed an unused copy of the sibling-module loader (this module needs
  no other NSP module), and the loader dot-sources files in name order.

## 0.1.0

First release.

The other NSP modules it needs are installed from the PowerShell Gallery the first time they're needed,
so `Install-Module` of this one module is enough. Set `NSP_NO_AUTOINSTALL=1` to turn that off.
