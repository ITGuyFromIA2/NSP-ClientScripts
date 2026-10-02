@{
    Name        = 'ToolShim'
    Version     = '1'
    Description = 'Small launcher for an NSP module-hosted tool: elevates, installs the modules it needs from the PowerShell Gallery (or loads them from -ModuleRoot), hands embedded seed answers to the tool once and blanks them from the file, then starts the tool.'
    Template    = 'Template.ps1.template'

    # The shim contract, deliberately tiny so an old shim keeps working with newer modules:
    #   make sure <ModuleName> >= <ModuleMinimumVersion> (plus <Modules>) is present, then
    #   <EntryFunction> -SeedAnswersJson <json> -SeedOnly   (only when answers are embedded)
    #   <EntryFunction>
    Parameters  = @(
        @{ Name = 'ToolName';                Type = 'String';  Required = $true;  Pattern = '^[A-Za-z0-9][A-Za-z0-9 ._()-]{0,60}$' }
        @{ Name = 'ModuleName';              Type = 'String';  Required = $true;  Pattern = '^[A-Za-z][A-Za-z0-9._-]{0,100}$' }
        @{ Name = 'ModuleMinimumVersion';    Type = 'Version'; Required = $true }
        @{ Name = 'EntryFunction';           Type = 'String';  Required = $true;  Pattern = '^[A-Za-z]+-[A-Za-z0-9]+$' }
        @{ Name = 'Modules';                 Type = 'Json';    Required = $true }
        @{ Name = 'SeedAnswers';             Type = 'Json';    Required = $false; Default = '' }
        @{ Name = 'Company';                 Type = 'Text';    Required = $false; Default = '(not set)' }
        @{ Name = 'GeneratedBy';             Type = 'Text';    Required = $false; Default = 'New-NSPToolShim' }
        @{ Name = 'BootstrapMinimumVersion'; Type = 'Version'; Required = $false; Default = '0.1.3' }
    )
}
