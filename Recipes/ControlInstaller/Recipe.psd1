@{
    Name        = 'ControlInstaller'
    Version     = '1'
    Description = 'Installs the ConnectWise Control (ScreenConnect) access agent for one client: builds the installer URL with the client and device-type custom properties, downloads the MSI over HTTPS, refuses to run it unless its Authenticode signature is valid and from the expected signer, installs silently, and keeps a transcript.'
    Template    = 'Template.ps1.template'

    Parameters  = @(
        # The instance's access-agent MSI link, including its own query (e.g. ?e=Access&y=Guest).
        @{ Name = 'BaseInstallerUri';      Type = 'String'; Required = $true;  Pattern = '^https://[^\s''"]+\.msi(\?[^\s''"]*)?$' }
        # Custom property 1 (client) and 5 (device type). 'ScriptDefault' leaves the property empty.
        @{ Name = 'ClientCode';            Type = 'String'; Required = $true;  Pattern = '^[^\r\n''"]{1,100}$' }
        @{ Name = 'DeviceType';            Type = 'String'; Required = $false; Default = 'ScriptDefault'; Pattern = '^[^\r\n''"]{1,100}$' }
        @{ Name = 'ExpectedSignerPattern'; Type = 'String'; Required = $false; Default = 'ConnectWise' }
        @{ Name = 'DownloadDirectory';     Type = 'String'; Required = $false; Default = 'C:\ProgramData\NSP\Installers' }
        @{ Name = 'TranscriptDirectory';   Type = 'String'; Required = $false; Default = 'C:\ProgramData\NSP\Logs' }
        @{ Name = 'Company';               Type = 'Text';   Required = $false; Default = '(not set)' }
        @{ Name = 'GeneratedBy';           Type = 'Text';   Required = $false; Default = 'New-NSPClientScript' }
    )
}
