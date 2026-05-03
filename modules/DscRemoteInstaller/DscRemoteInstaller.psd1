@{
    RootModule           = 'DscRemoteInstaller.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'd13d16f7-cd95-4e7f-a78d-a66f3dc07286'
    Author               = 'Jarod Roberts'
    CompanyName          = 'Appalachian Network Services'
    Copyright            = '(c) Appalachian Network Services. All rights reserved.'
    Description          = 'Generic DSC resource for installing remote MSI or EXE installers with optional prepare scripts.'
    PowerShellVersion    = '5.1'
    DscResourcesToExport = @('RemoteInstaller')
    FunctionsToExport    = @()
    CmdletsToExport      = @()
    VariablesToExport    = '*'
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags       = @('DSC', 'Installer', 'MSI', 'EXE')
            ProjectUri = 'https://github.com/AppNetOnline/ans-dsc-scripts'
        }
    }
}
