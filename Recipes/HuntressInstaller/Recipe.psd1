@{
    Name        = 'HuntressInstaller'
    Version     = '1'
    Description = 'Installs the Huntress agent: downloads the official installer for the account over HTTPS, refuses to run it unless its Authenticode signature is valid and from the expected signer, installs silently with the account and organization keys, checks the agent service is running, and keeps a transcript. The generated file contains the account key - treat it as a secret.'
    Template    = 'Template.ps1.template'

    Parameters  = @(
        # The Huntress account key (32 hex characters). Pass it from the secret store, e.g.
        # (Get-NSPSecret -Name Huntress.AccountKey -AsPlainText), rather than typing it into a script.
        @{ Name = 'AccountKey';            Type = 'String'; Required = $true;  Pattern = '^[A-Fa-f0-9]{32}$' }
        # The organization the agent joins (usually the client's short name).
        @{ Name = 'OrganizationKey';       Type = 'String'; Required = $true;  Pattern = '^[^\r\n''"]{1,100}$' }
        @{ Name = 'ExpectedSignerPattern'; Type = 'String'; Required = $false; Default = 'Huntress Labs' }
        @{ Name = 'DownloadDirectory';     Type = 'String'; Required = $false; Default = 'C:\ProgramData\NSP\Installers' }
        @{ Name = 'TranscriptDirectory';   Type = 'String'; Required = $false; Default = 'C:\ProgramData\NSP\Logs' }
        @{ Name = 'Company';               Type = 'Text';   Required = $false; Default = '(not set)' }
        @{ Name = 'GeneratedBy';           Type = 'Text';   Required = $false; Default = 'New-NSPClientScript' }
    )
}
