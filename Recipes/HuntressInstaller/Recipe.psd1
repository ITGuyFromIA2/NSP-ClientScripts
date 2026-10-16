@{
    Name        = 'HuntressInstaller'
    Version     = '4'
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
        # A UNC folder whose Status\ and Transcripts\ subfolders the computers can write to (blank =
        # no reports) - with Import-NSPADGpoRecipe, the share folder the script itself is served from.
        @{ Name = 'ReportDirectory';       Type = 'String'; Required = $false; Default = ''; Pattern = '^\\\\[^\\''"\r\n]+\\[^''"\r\n]+$' }
        # The folder a GPO copies this script into (e.g. C:\ProgramData\NSP\Huntress). Each run limits it
        # to SYSTEM and Administrators - the copy carries the account key. Blank = leave folders alone.
        @{ Name = 'LocalDirectory';        Type = 'String'; Required = $false; Default = ''; Pattern = '^[A-Za-z]:\\[^''"\r\n]+$' }
        # Days between re-registration attempts on one computer (orphaned or foreign agent).
        @{ Name = 'RetryDays';             Type = 'String'; Required = $false; Default = '7'; Pattern = '^[1-9][0-9]?$' }
        @{ Name = 'Company';               Type = 'Text';   Required = $false; Default = '(not set)' }
        @{ Name = 'GeneratedBy';           Type = 'Text';   Required = $false; Default = 'New-NSPClientScript' }
    )
}
