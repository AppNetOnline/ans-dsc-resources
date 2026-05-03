#Requires -Version 5.1

Set-StrictMode -Version Latest;
$ErrorActionPreference = 'Stop';
$ConfirmPreference = 'None';
$ProgressPreference = 'SilentlyContinue';

Function Get-InstallerSafeName {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [String]$Name
    );

    Return (($Name -replace '[^A-Za-z0-9._-]', '').Trim());
};

Function Get-InstallerFolder {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [String]$Name,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFolder
    );

    If ($InstallerFolder) {
        Return $InstallerFolder;
    };

    Return (Join-Path 'C:\ProgramData\Installers' (Get-InstallerSafeName -Name $Name));
};

Function Get-InstallerFileName {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [String]$Name,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFileName,

        [Parameter(Mandatory = $False)]
        [String]$InstallerUri,

        [Parameter(Mandatory = $False)]
        [String]$InstallerType = 'Exe'
    );

    If ($InstallerFileName) {
        Return $InstallerFileName;
    };

    If ($InstallerUri) {
        Return (Split-Path $InstallerUri -Leaf);
    };

    If ($InstallerType -eq 'Msi') {
        Return "$(Get-InstallerSafeName -Name $Name).msi";
    };

    Return "$(Get-InstallerSafeName -Name $Name).exe";
};

Function Get-InstallerPath {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [String]$Name,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFolder,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFileName,

        [Parameter(Mandatory = $False)]
        [String]$InstallerUri,

        [Parameter(Mandatory = $False)]
        [String]$InstallerType = 'Exe'
    );

    $Folder = Get-InstallerFolder -Name $Name -InstallerFolder $InstallerFolder;
    $FileName = Get-InstallerFileName `
        -Name $Name `
        -InstallerFileName $InstallerFileName `
        -InstallerUri $InstallerUri `
        -InstallerType $InstallerType;

    Return (Join-Path $Folder $FileName);
};

Function Get-ObjectPropertyValue {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [Object]$InputObject,

        [Parameter(Mandatory = $True)]
        [String]$Name
    );

    If (!$InputObject) {
        Return $Null;
    };

    $Property = $InputObject.PSObject.Properties[$Name];

    If (!$Property) {
        Return $Null;
    };

    Return $Property.Value;
};

Function Get-InstalledApplication {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [String]$DisplayNamePattern
    );

    $UninstallRoots = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    );

    ForEach ($Root in $UninstallRoots) {
        $Apps = Get-ItemProperty -Path $Root -ErrorAction SilentlyContinue;

        ForEach ($App in $Apps) {
            $DisplayName = Get-ObjectPropertyValue -InputObject $App -Name 'DisplayName';

            If ($DisplayName -and $DisplayName -match $DisplayNamePattern) {
                Return $App;
            };
        };
    };

    Return $Null;
};

Function Get-DesiredVersionString {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [String]$Name,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFolder,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFileName,

        [Parameter(Mandatory = $False)]
        [String]$InstallerUri,

        [Parameter(Mandatory = $False)]
        [String]$InstallerType = 'Exe',

        [Parameter(Mandatory = $False)]
        [String]$DesiredVersion
    );

    If ($DesiredVersion) {
        Return $DesiredVersion;
    };

    $Folder = Get-InstallerFolder -Name $Name -InstallerFolder $InstallerFolder;
    $VersionPath = Join-Path $Folder "$(Get-InstallerSafeName -Name $Name).desiredversion";

    If (Test-Path $VersionPath) {
        Return (Get-Content -Path $VersionPath -Raw).Trim();
    };

    $InstallerPath = Get-InstallerPath `
        -Name $Name `
        -InstallerFolder $InstallerFolder `
        -InstallerFileName $InstallerFileName `
        -InstallerUri $InstallerUri `
        -InstallerType $InstallerType;

    If (Test-Path $InstallerPath) {
        $Version = (Get-Item $InstallerPath).VersionInfo.ProductVersion;

        If ($Version) {
            Return $Version;
        };
    };

    Return '0.0.0.0';
};

Function Invoke-PrepareScript {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [String]$Name,

        [Parameter(Mandatory = $True)]
        [String]$PrepareScriptUri,

        [Parameter(Mandatory = $False)]
        [String]$InstallerUri,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFolder,

        [Parameter(Mandatory = $False)]
        [String]$InstallerPath,

        [Parameter(Mandatory = $False)]
        [UInt32]$PrepareTimeoutMinutes = 10
    );

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

    $InvokeRestMethodParams = @{
        Uri             = $PrepareScriptUri;
        UseBasicParsing = $True;
    };

    $Script = Invoke-RestMethod @InvokeRestMethodParams;

    If ([String]::IsNullOrWhiteSpace($Script)) {
        Throw "Failed to download prepare script from $PrepareScriptUri.";
    };

    $ScriptBlock = [ScriptBlock]::Create($Script);

    & $ScriptBlock `
        -Name $Name `
        -InstallerUri $InstallerUri `
        -InstallerFolder $InstallerFolder `
        -InstallerPath $InstallerPath `
        -PrepareTimeoutMinutes $PrepareTimeoutMinutes;
};

Function Get-TargetResource {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [String]$Name,

        [Parameter(Mandatory = $True)]
        [String]$DisplayNamePattern,

        [Parameter(Mandatory = $False)]
        [ValidateSet('Present', 'Absent')]
        [String]$Ensure = 'Present',

        [Parameter(Mandatory = $False)]
        [ValidateSet('Exe', 'Msi')]
        [String]$InstallerType = 'Exe',

        [Parameter(Mandatory = $False)]
        [String]$InstallerUri,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFolder,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFileName,

        [Parameter(Mandatory = $False)]
        [String]$DesiredVersion,

        [Parameter(Mandatory = $False)]
        [String]$PrepareScriptUri,

        [Parameter(Mandatory = $False)]
        [String]$InstallArguments,

        [Parameter(Mandatory = $False)]
        [String]$MsiProperties,

        [Parameter(Mandatory = $False)]
        [UInt32]$PrepareTimeoutMinutes = 10
    );

    $Installed = Get-InstalledApplication -DisplayNamePattern $DisplayNamePattern;
    $InstalledVersion = Get-ObjectPropertyValue -InputObject $Installed -Name 'DisplayVersion';

    Return @{
        Name                  = $Name;
        DisplayNamePattern    = $DisplayNamePattern;
        Ensure                = $Ensure;
        InstallerType         = $InstallerType;
        InstallerUri          = $InstallerUri;
        InstallerFolder       = Get-InstallerFolder -Name $Name -InstallerFolder $InstallerFolder;
        InstallerFileName     = Get-InstallerFileName -Name $Name -InstallerFileName $InstallerFileName -InstallerUri $InstallerUri -InstallerType $InstallerType;
        DesiredVersion        = Get-DesiredVersionString -Name $Name -InstallerFolder $InstallerFolder -InstallerFileName $InstallerFileName -InstallerUri $InstallerUri -InstallerType $InstallerType -DesiredVersion $DesiredVersion;
        PrepareScriptUri      = $PrepareScriptUri;
        InstallArguments      = $InstallArguments;
        MsiProperties         = $MsiProperties;
        PrepareTimeoutMinutes = $PrepareTimeoutMinutes;
        InstalledVersion      = If ($InstalledVersion) { [String]$InstalledVersion } Else { $Null };
        ResolvedInstallerPath = Get-InstallerPath -Name $Name -InstallerFolder $InstallerFolder -InstallerFileName $InstallerFileName -InstallerUri $InstallerUri -InstallerType $InstallerType;
    };
};

Function Test-TargetResource {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [String]$Name,

        [Parameter(Mandatory = $True)]
        [String]$DisplayNamePattern,

        [Parameter(Mandatory = $False)]
        [ValidateSet('Present', 'Absent')]
        [String]$Ensure = 'Present',

        [Parameter(Mandatory = $False)]
        [ValidateSet('Exe', 'Msi')]
        [String]$InstallerType = 'Exe',

        [Parameter(Mandatory = $False)]
        [String]$InstallerUri,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFolder,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFileName,

        [Parameter(Mandatory = $False)]
        [String]$DesiredVersion,

        [Parameter(Mandatory = $False)]
        [String]$PrepareScriptUri,

        [Parameter(Mandatory = $False)]
        [String]$InstallArguments,

        [Parameter(Mandatory = $False)]
        [String]$MsiProperties,

        [Parameter(Mandatory = $False)]
        [UInt32]$PrepareTimeoutMinutes = 10
    );

    If ($Ensure -eq 'Absent') {
        Throw 'Ensure = Absent is not supported by this resource.';
    };

    $Installed = Get-InstalledApplication -DisplayNamePattern $DisplayNamePattern;

    If (!$Installed) {
        Return $False;
    };

    $Desired = [Version](Get-DesiredVersionString `
        -Name $Name `
        -InstallerFolder $InstallerFolder `
        -InstallerFileName $InstallerFileName `
        -InstallerUri $InstallerUri `
        -InstallerType $InstallerType `
        -DesiredVersion $DesiredVersion);

    If ($Desired -eq [Version]'0.0.0.0') {
        Return $True;
    };

    $InstalledVersion = Get-ObjectPropertyValue -InputObject $Installed -Name 'DisplayVersion';

    If (!$InstalledVersion) {
        Return $False;
    };

    Return ([Version]$InstalledVersion -ge $Desired);
};

Function Set-TargetResource {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [String]$Name,

        [Parameter(Mandatory = $True)]
        [String]$DisplayNamePattern,

        [Parameter(Mandatory = $False)]
        [ValidateSet('Present', 'Absent')]
        [String]$Ensure = 'Present',

        [Parameter(Mandatory = $False)]
        [ValidateSet('Exe', 'Msi')]
        [String]$InstallerType = 'Exe',

        [Parameter(Mandatory = $False)]
        [String]$InstallerUri,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFolder,

        [Parameter(Mandatory = $False)]
        [String]$InstallerFileName,

        [Parameter(Mandatory = $False)]
        [String]$DesiredVersion,

        [Parameter(Mandatory = $False)]
        [String]$PrepareScriptUri,

        [Parameter(Mandatory = $False)]
        [String]$InstallArguments,

        [Parameter(Mandatory = $False)]
        [String]$MsiProperties,

        [Parameter(Mandatory = $False)]
        [UInt32]$PrepareTimeoutMinutes = 10
    );

    If ($Ensure -eq 'Absent') {
        Throw 'Ensure = Absent is not supported by this resource.';
    };

    $Folder = Get-InstallerFolder -Name $Name -InstallerFolder $InstallerFolder;

    If (!(Test-Path $Folder)) {
        $NewItemParams = @{
            Path      = $Folder;
            ItemType  = 'Directory';
            Force     = $True;
            ErrorAction = 'Stop';
        };

        New-Item @NewItemParams | Out-Null;
    };

    $InstallerPath = Get-InstallerPath `
        -Name $Name `
        -InstallerFolder $InstallerFolder `
        -InstallerFileName $InstallerFileName `
        -InstallerUri $InstallerUri `
        -InstallerType $InstallerType;

    If ($PrepareScriptUri) {
        Invoke-PrepareScript `
            -Name $Name `
            -PrepareScriptUri $PrepareScriptUri `
            -InstallerUri $InstallerUri `
            -InstallerFolder $Folder `
            -InstallerPath $InstallerPath `
            -PrepareTimeoutMinutes $PrepareTimeoutMinutes;
    }
    ElseIf (!(Test-Path $InstallerPath)) {
        If (!$InstallerUri) {
            Throw 'InstallerUri is required when PrepareScriptUri is not specified and installer is not already staged.';
        };

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

        $InvokeWebRequestParams = @{
            Uri             = $InstallerUri;
            OutFile         = $InstallerPath;
            UseBasicParsing = $True;
            ErrorAction     = 'Stop';
        };

        Invoke-WebRequest @InvokeWebRequestParams;
    };

    If (!(Test-Path $InstallerPath)) {
        Throw "Installer was not found: $InstallerPath";
    };

    $Installed = Get-InstalledApplication -DisplayNamePattern $DisplayNamePattern;
    $InstalledVersion = Get-ObjectPropertyValue -InputObject $Installed -Name 'DisplayVersion';
    $Desired = [Version](Get-DesiredVersionString `
        -Name $Name `
        -InstallerFolder $InstallerFolder `
        -InstallerFileName $InstallerFileName `
        -InstallerUri $InstallerUri `
        -InstallerType $InstallerType `
        -DesiredVersion $DesiredVersion);

    If ($Installed -and $InstalledVersion -and $Desired -ne [Version]'0.0.0.0') {
        If ([Version]$InstalledVersion -ge $Desired) {
            Return;
        };
    };

    $LogName = "$(Get-InstallerSafeName -Name $Name)-install-$(Get-Date -Format 'yyyyMMddHHmmss').log";
    $LogPath = Join-Path $Folder $LogName;

    If ($InstallerType -eq 'Msi') {
        $Properties = If ($MsiProperties) { " $MsiProperties" } Else { '' };
        $Arguments = "/i `"$InstallerPath`" /qn /norestart /L*v `"$LogPath`"$Properties";

        $StartProcessParams = @{
            FilePath     = 'msiexec.exe';
            ArgumentList = $Arguments;
            Wait         = $True;
            PassThru     = $True;
        };

        $Process = Start-Process @StartProcessParams;
    }
    Else {
        $Arguments = If ($InstallArguments) { $InstallArguments } Else { '/quiet /norestart' };

        $StartProcessParams = @{
            FilePath     = $InstallerPath;
            ArgumentList = $Arguments;
            Wait         = $True;
            PassThru     = $True;
        };

        $Process = Start-Process @StartProcessParams;
    };

    If ($Process.ExitCode -notin @(0, 3010)) {
        Throw "$Name installer failed with exit code $($Process.ExitCode). See $LogPath.";
    };

    $Installed = Get-InstalledApplication -DisplayNamePattern $DisplayNamePattern;
    $InstalledVersion = Get-ObjectPropertyValue -InputObject $Installed -Name 'DisplayVersion';

    If (!$Installed) {
        Throw "$Name was not detected after installation.";
    };

    If ($Desired -ne [Version]'0.0.0.0' -and (!$InstalledVersion -or [Version]$InstalledVersion -lt $Desired)) {
        Throw "$Name version $InstalledVersion is lower than desired version $Desired.";
    };
};

Export-ModuleMember -Function Get-TargetResource, Set-TargetResource, Test-TargetResource;
