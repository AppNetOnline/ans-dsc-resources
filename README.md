# DscRemoteInstaller

Generic DSC resource for software deployment scenarios that need more control than a plain package install.

## Author

- Author: Jarod Roberts
- Company: Appalachian Network Services

## Module

`DscRemoteInstaller/RemoteInstaller` installs MSI or EXE installers that can be detected through the Windows uninstall registry keys.

It supports:

- Remote installer download.
- Local installer staging.
- MSI or EXE install modes.
- Desired version enforcement.
- Optional MSI properties.
- Optional remote prepare script for custom staging logic.

The prepare script hook is useful when the installer URL points to a bootstrapper, but the final install should run from a staged MSI.

## Layout

```text
configs/
  generic.remoteinstaller.example.dsc.yaml
  generic.remoteinstaller.with-prepare.example.dsc.yaml

modules/
  DscRemoteInstaller/

scripts/
  FortiClientVPN.Prepare.ps1

Install-DscResources.ps1
POWERSHELL_STYLE_GUIDE.md
```

## Install

Run from the repository root in an elevated Windows PowerShell session:

```powershell
.\Install-DscResources.ps1
```

Verify discovery:

```powershell
Get-DscResource -Module DscRemoteInstaller
```

## Example

```yaml
# yaml-language-server: $schema=https://aka.ms/configuration-dsc-schema/0.2
properties:
  resources:
    - resource: DscRemoteInstaller/RemoteInstaller
      settings:
        Name: FortiClientVPN
        Ensure: Present
        DisplayNamePattern: FortiClient.*VPN
        InstallerType: Msi
        InstallerUri: https://filestore.fortinet.com/forticlient/downloads/FortiClientVPNInstaller.exe
        InstallerFolder: C:\ProgramData\Installers\FortiClientVPN
        InstallerFileName: FortiClientVPN.msi
        PrepareScriptUri: https://raw.githubusercontent.com/AppNetOnline/ans-dsc-scripts/main/scripts/FortiClientVPN.Prepare.ps1
        PrepareTimeoutMinutes: 10
        MsiProperties: REBOOT=ReallySuppress DONT_PROMPT_REBOOT=1
  configurationVersion: 0.2.0
```
