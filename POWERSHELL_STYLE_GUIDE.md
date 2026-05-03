# Jarod Roberts PowerShell Formatting Style Guide

Use this formatting style when writing or rewriting PowerShell scripts.

## General Script Style

- Target Windows PowerShell 5.1 unless otherwise requested.
- Use advanced functions with `[CmdletBinding()]`.
- Prefer strong typing for parameters and variables where practical.
- Use explicit `Param()` blocks.
- Use capitalized PowerShell keywords:
  - `Function`
  - `Param`
  - `If`
  - `Else`
  - `ElseIf`
  - `ForEach`
  - `Try`
  - `Catch`
  - `Finally`
  - `Return`
- Use trailing semicolons at the end of statements and after closing braces.
- Use backtick line continuation for long commands.
- Use splatting for commands with multiple parameters.
- Prefer readable, explicit logic over compact one-liners.

## Standard Header

```powershell
#Requires -Version 5.1

Set-StrictMode -Version Latest;
$ErrorActionPreference = 'Stop';
$ConfirmPreference = 'None';
$ProgressPreference = 'SilentlyContinue';
```

Use `#Requires -RunAsAdministrator` when the script requires elevation.

## Function Layout

```powershell
Function Verb-Noun {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [String]$Name,

        [Parameter(Mandatory = $False)]
        [Switch]$Force
    );

    Begin {
        Write-Verbose "Starting Verb-Noun.";
    };

    Process {
        If ([String]::IsNullOrWhiteSpace($Name)) {
            Throw "Name cannot be empty.";
        };

        Write-Verbose "Processing [$Name].";
    };

    End {
        Return $True;
    };
};
```

## Parameter Formatting

- Each parameter should be on its own block.
- Use `[Parameter(Mandatory = $True)]` or `[Parameter(Mandatory = $False)]`.
- Use `$True` and `$False`, not `$true` and `$false`.
- Use PascalCase parameter names.
- Prefer type accelerators:
  - `[String]`
  - `[Int]`
  - `[Bool]`
  - `[Switch]`
  - `[Array]`
  - `[Hashtable]`
  - `[PSCustomObject]`
  - `[IPAddress]`
  - `[Version]`
  - `[DateTime]`

Example:

```powershell
Param(
    [Parameter(Mandatory = $True)]
    [IPAddress]$IPAddress,

    [Parameter(Mandatory = $True)]
    [String]$DnsName,

    [Parameter(Mandatory = $False)]
    [Switch]$WhatIf
);
```

## Splatting

Prefer this:

```powershell
$InvokeRestMethodParams = @{
    Method      = 'Get';
    Uri         = $Uri;
    Headers     = $Headers;
    ErrorAction = 'Stop';
};

$Response = Invoke-RestMethod @InvokeRestMethodParams;
```

Instead of this:

```powershell
$Response = Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers -ErrorAction Stop;
```

## Object Output

Prefer returning structured objects instead of raw strings when the output may be consumed by another script.

```powershell
$Result = [PSCustomObject]@{
    Name      = $Name;
    Installed = $Installed;
    Version   = $Version;
    Compliant = $Compliant;
};

Return $Result;
```
