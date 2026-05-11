Param(
    [String]$Name,
    [String]$InstallerUri,
    [String]$InstallerFolder,
    [String]$InstallerPath,
    [String]$DesiredVersion,
    [UInt32]$PrepareTimeoutMinutes = 10
);

Function Get-MsiProductVersion {
    Param(
        [Parameter(Mandatory = $True)]
        [String]$Path
    );

    Try {
        $WindowsInstaller = New-Object -ComObject WindowsInstaller.Installer;
        $Database = $WindowsInstaller.OpenDatabase($Path, 0);
        $View = $Database.OpenView("SELECT Value FROM Property WHERE Property = 'ProductVersion'");
        $View.Execute();
        $Record = $View.Fetch();

        If ($Record) {
            Return $Record.StringData(1);
        };

        Return $Null;
    }
    Catch {
        Return $Null;
    };
};

$BootstrapperPath = Join-Path $InstallerFolder 'FortiClientVPNInstaller.exe';
$DesiredVersionPath = Join-Path $InstallerFolder 'FortiClientVPN.desiredversion';
$ExtractLogPath = Join-Path $InstallerFolder 'FortiClientVPN-msi-extract.log';

If (!(Test-Path $InstallerFolder)) {
    New-Item -Path $InstallerFolder -ItemType Directory -Force | Out-Null;
};

If (!$InstallerPath) {
    $InstallerPath = Join-Path $InstallerFolder "FortiClientVPN-$DesiredVersion.msi";
};

If (Test-Path $InstallerPath) {
    $ExistingVersion = Get-MsiProductVersion -Path $InstallerPath;

    If ($ExistingVersion -eq $DesiredVersion) {
        "[$(Get-Date -Format o)] Existing staged MSI already matches desired version: $ExistingVersion" |
            Out-File -FilePath $ExtractLogPath -Append -Encoding utf8;

        $ExistingVersion | Out-File -FilePath $DesiredVersionPath -Encoding ascii -Force;

        Return;
    };

    "[$(Get-Date -Format o)] Existing staged MSI does not match desired version. ExistingVersion=[$ExistingVersion], DesiredVersion=[$DesiredVersion]. Will stage to versioned path without deleting locked files." |
        Out-File -FilePath $ExtractLogPath -Append -Encoding utf8;

    $InstallerPath = Join-Path $InstallerFolder "FortiClientVPN-$DesiredVersion.msi";
};

"[$(Get-Date -Format o)] Downloading bootstrapper: $InstallerUri" |
    Out-File -FilePath $ExtractLogPath -Append -Encoding utf8;

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

Invoke-WebRequest `
    -Uri $InstallerUri `
    -OutFile $BootstrapperPath `
    -UseBasicParsing;

"[$(Get-Date -Format o)] Starting bootstrapper to stage MSI." |
    Out-File -FilePath $ExtractLogPath -Append -Encoding utf8;

$Process = Start-Process -FilePath $BootstrapperPath -PassThru;

Try {
    $Deadline = (Get-Date).AddMinutes($PrepareTimeoutMinutes);
    $FoundMsi = $Null;

    While ((Get-Date) -lt $Deadline -and !$FoundMsi) {
        Start-Sleep -Seconds 5;

        $FoundMsi = Get-ChildItem `
            -Path 'C:\ProgramData\Applications\Cache', $env:LOCALAPPDATA\Temp `
            -Recurse `
            -Filter 'FortiClientVPN.msi' `
            -ErrorAction SilentlyContinue |
                ForEach-Object {
                    $MsiVersion = Get-MsiProductVersion -Path $_.FullName;

                    [PSCustomObject]@{
                        FullName = $_.FullName;
                        Version = $MsiVersion;
                        LastWriteTime = $_.LastWriteTime;
                    };
                } |
                Where-Object {
                    $_.Version -eq $DesiredVersion
                } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1;
    };

    If (!$FoundMsi) {
        Throw "FortiClientVPN.msi version [$DesiredVersion] was not found after launching the Fortinet bootstrapper.";
    };

    "[$(Get-Date -Format o)] Found MSI: $($FoundMsi.FullName)" |
        Out-File -FilePath $ExtractLogPath -Append -Encoding utf8;

    "[$(Get-Date -Format o)] Found MSI version: $($FoundMsi.Version)" |
        Out-File -FilePath $ExtractLogPath -Append -Encoding utf8;

    If ((Test-Path $InstallerPath) -and ((Get-MsiProductVersion -Path $InstallerPath) -eq $DesiredVersion)) {
        "[$(Get-Date -Format o)] Versioned destination MSI already exists and matches desired version: $InstallerPath" |
            Out-File -FilePath $ExtractLogPath -Append -Encoding utf8;
    }
    Else {
        Copy-Item `
            -Path $FoundMsi.FullName `
            -Destination $InstallerPath `
            -Force;

        "[$(Get-Date -Format o)] Copied MSI to: $InstallerPath" |
            Out-File -FilePath $ExtractLogPath -Append -Encoding utf8;
    };

    $MsiVersion = Get-MsiProductVersion -Path $InstallerPath;

    If ($MsiVersion) {
        $MsiVersion | Out-File -FilePath $DesiredVersionPath -Encoding ascii -Force;

        "[$(Get-Date -Format o)] Staged MSI product version: $MsiVersion" |
            Out-File -FilePath $ExtractLogPath -Append -Encoding utf8;
    };

    If ($MsiVersion -ne $DesiredVersion) {
        Throw "Staged MSI version [$MsiVersion] does not match desired version [$DesiredVersion].";
    };
}
Finally {
    If ($Process -and !$Process.HasExited) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue;
    };

    Get-Process `
        -Name 'FortiClientVPNInstaller', 'FortiClientVPNOnlineInstaller' `
        -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue;
};