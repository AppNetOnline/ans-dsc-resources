#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $False)]
    [String]$DestinationRoot = 'C:\Program Files\WindowsPowerShell\Modules',

    [Parameter(Mandatory = $False)]
    [String[]]$Modules = @(
        'DscRemoteInstaller'
    )
);

Set-StrictMode -Version Latest;
$ErrorActionPreference = 'Stop';
$ConfirmPreference = 'None';
$ProgressPreference = 'SilentlyContinue';

ForEach ($Module in $Modules) {
    $Source = Join-Path $PSScriptRoot "modules\$Module";
    $Destination = Join-Path $DestinationRoot $Module;

    If (!(Test-Path $Source)) {
        Throw "Module source not found: $Source";
    };

    If (!(Test-Path $DestinationRoot)) {
        $NewItemParams = @{
            Path     = $DestinationRoot;
            ItemType = 'Directory';
            Force    = $True;
        };

        New-Item @NewItemParams | Out-Null;
    };

    If (Test-Path $Destination) {
        $RemoveItemParams = @{
            Path    = $Destination;
            Recurse = $True;
            Force   = $True;
        };

        Remove-Item @RemoveItemParams;
    };

    $CopyItemParams = @{
        Path        = $Source;
        Destination = $Destination;
        Recurse     = $True;
        Force       = $True;
    };

    Copy-Item @CopyItemParams;

    [PSCustomObject]@{
        ModuleName  = $Module;
        Source      = $Source;
        Destination = $Destination;
        Status      = 'Installed';
    };
};
