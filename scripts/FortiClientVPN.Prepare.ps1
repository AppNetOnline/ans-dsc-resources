Param(
    [String]$Name,
    [String]$InstallerUri,
    [String]$InstallerFolder,
    [String]$InstallerPath,
    [UInt32]$PrepareTimeoutMinutes = 10
);

$BootstrapperPath = Join-Path $InstallerFolder 'FortiClientVPNInstaller.exe';
$DesiredVersionPath = Join-Path $InstallerFolder 'FortiClientVPN.desiredversion';
$ExtractLogPath = Join-Path $InstallerFolder 'FortiClientVPN-msi-extract.log';

If (!(Test-Path $InstallerFolder)) {
    New-Item -Path $InstallerFolder -ItemType Directory -Force | Out-Null;
};

If (Test-Path $InstallerPath) {
    Return;
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
            -Path $env:LOCALAPPDATA\Temp `
            -Recurse `
            -Filter 'FortiClientVPN.msi' `
            -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1;

        If (!$FoundMsi) {
            $FoundMsi = Get-ChildItem `
                -Path 'C:\ProgramData\Applications\Cache', 'C:\ProgramData' `
                -Recurse `
                -Filter 'FortiClientVPN.msi' `
                -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1;
        };
    };

    If (!$FoundMsi) {
        Throw 'FortiClientVPN.msi was not found after launching the Fortinet bootstrapper.';
    };

    "[$(Get-Date -Format o)] Found MSI: $($FoundMsi.FullName)" |
        Out-File -FilePath $ExtractLogPath -Append -Encoding utf8;

    Copy-Item -Path $FoundMsi.FullName -Destination $InstallerPath -Force;

    "[$(Get-Date -Format o)] Copied MSI to: $InstallerPath" |
        Out-File -FilePath $ExtractLogPath -Append -Encoding utf8;

    $MsiVersion = (Get-Item $InstallerPath).VersionInfo.ProductVersion;

    If ($MsiVersion) {
        $MsiVersion | Out-File -FilePath $DesiredVersionPath -Encoding ascii -Force;

        "[$(Get-Date -Format o)] MSI product version: $MsiVersion" |
            Out-File -FilePath $ExtractLogPath -Append -Encoding utf8;
    };
}
Finally {
    If ($Process -and !$Process.HasExited) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue;
    };

    Get-Process `
        -Name 'FortiClientVPNInstaller', 'FortiClientVPNOnlineInstaller', 'FortiClientVPN' `
        -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue;
};
