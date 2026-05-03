@{
    RootModule        = 'RemoteInstaller.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '73dc820d-3991-4b1c-9d5c-b46b606690cb'
    Author            = 'Jarod Roberts'
    CompanyName       = 'Appalachian Network Services'
    Copyright         = '(c) Appalachian Network Services. All rights reserved.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-TargetResource',
        'Set-TargetResource',
        'Test-TargetResource'
    )
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = @()
}
