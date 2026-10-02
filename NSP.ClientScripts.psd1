@{
    RootModule        = 'NSP.ClientScripts.psm1'
    ModuleVersion     = '0.1.1'
    GUID              = '6c5a13bd-c8c8-482d-9135-ba8ca67d9ed3'
    Author            = 'Network Systems Plus'
    CompanyName       = 'Network Systems Plus'
    Copyright         = '(c) Network Systems Plus. All rights reserved.'
    Description       = 'Generates standalone, client-specific PowerShell scripts (tool shims, installers) from reviewed recipes: a template plus a typed parameter schema, syntax-checked before it is written. Windows PowerShell 5.1 compatible.'

    # 5.1 is the floor for every NSP toolkit, and the module must import on a bare 5.1 host. It
    # needs no other NSP module; the tool modules that call it load it themselves.
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Get-NSPClientScriptRecipe'
        'ConvertTo-NSPClientScript'
        'New-NSPClientScript'
        'New-NSPToolShim'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('NSP', 'Generator', 'Script', 'Shim', 'Deployment')
            ProjectUri   = 'https://github.com/ITGuyFromIA2/NSP-ClientScripts'
            LicenseUri   = 'https://github.com/ITGuyFromIA2/NSP-ClientScripts/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/ITGuyFromIA2/NSP-ClientScripts/blob/main/CHANGELOG.md'
        }
    }
}