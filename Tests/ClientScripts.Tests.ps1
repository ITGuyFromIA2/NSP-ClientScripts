<#
    Pester 5. The recipe engine, and the ToolShim recipe end to end: a generated shim is run in a
    child PowerShell (same edition as the test) against a throwaway fake tool module loaded via
    -ModuleRoot, with -NoElevate - nothing is installed and nothing is elevated.
#>

BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'NSP.ClientScripts.psd1') -Force -ErrorAction Stop

    $script:ShimBase = @{
        ToolName             = 'Fake Tool'
        ModuleName           = 'NSP.FakeTool'
        ModuleMinimumVersion = '0.1.0'
        EntryFunction        = 'Start-NSPFakeTool'
        Modules              = @(@{ Name = 'NSP.FakeTool'; MinimumVersion = '0.1.0' })
    }

    function New-FakeToolRoot([string]$Root) {
        $dir = Join-Path $Root 'NSP.FakeTool'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dir 'NSP.FakeTool.psd1') -Value "@{ RootModule = 'NSP.FakeTool.psm1'; ModuleVersion = '0.1.0'; GUID = '$([guid]::NewGuid())'; FunctionsToExport = @('Start-NSPFakeTool') }"
        Set-Content -LiteralPath (Join-Path $dir 'NSP.FakeTool.psm1') -Value @'
function Start-NSPFakeTool {
    param([string]$SeedAnswersJson, [switch]$SeedOnly)
    $entry = [ordered]@{ SeedOnly = [bool]$SeedOnly; Seed = $SeedAnswersJson }
    Add-Content -LiteralPath $env:NSP_FAKE_TOOL_LOG -Value (ConvertTo-Json -InputObject $entry -Compress) -Encoding UTF8
}
'@
        return $Root
    }

    function Invoke-Shim([string]$Path, [string[]]$ShimArgs) {
        $exe = (Get-Process -Id $PID).Path
        $env:NSP_SHIM_NONINTERACTIVE = '1'
        try {
            $out = & $exe -NoProfile -ExecutionPolicy Bypass -File $Path @ShimArgs 2>&1
            return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($out | Out-String) }
        } finally { Remove-Item Env:\NSP_SHIM_NONINTERACTIVE -ErrorAction SilentlyContinue }
    }

    function Read-FakeLog {
        if (-not (Test-Path -LiteralPath $env:NSP_FAKE_TOOL_LOG)) { return @() }
        return @(Get-Content -LiteralPath $env:NSP_FAKE_TOOL_LOG -Encoding UTF8 | ForEach-Object { ConvertFrom-Json $_ })
    }
}

AfterAll {
    Remove-Module NSP.ClientScripts -Force -ErrorAction SilentlyContinue
}

Describe 'Get-NSPClientScriptRecipe' {
    It 'lists the built-in ToolShim recipe with its typed parameters' {
        $r = Get-NSPClientScriptRecipe -Name ToolShim
        $r.Name | Should -Be 'ToolShim'
        ($r.Parameters | Where-Object Name -eq 'SeedAnswers').Type | Should -Be 'Json'
        ($r.Parameters | Where-Object Name -eq 'ModuleName').Required | Should -BeTrue
        Test-Path -LiteralPath $r.TemplatePath | Should -BeTrue
    }

    It 'reads custom recipes from -RecipePath' {
        $dir = Join-Path $TestDrive 'Recipes\Hello'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content (Join-Path $dir 'Recipe.psd1') "@{ Name = 'Hello'; Version = '2'; Description = 'x'; Template = 't.template'; Parameters = @(@{ Name = 'Who'; Type = 'String'; Required = `$true }) }"
        Set-Content (Join-Path $dir 't.template') "Write-Output ('Hello ' + {{Who}})"
        (Get-NSPClientScriptRecipe -RecipePath (Join-Path $TestDrive 'Recipes')).Name | Should -Be 'Hello'
        $text = ConvertTo-NSPClientScript -Recipe Hello -RecipePath (Join-Path $TestDrive 'Recipes') -Parameters @{ Who = "O'Brien" }
        $text | Should -Be "Write-Output ('Hello ' + 'O''Brien')`r`n"
    }

    It 'escapes smart single quotes in String literals' {
        $who = 'it' + [char]0x2019 + 's; Remove-Item x'
        $text = ConvertTo-NSPClientScript -Recipe Hello -RecipePath (Join-Path $TestDrive 'Recipes') -Parameters @{ Who = $who }
        $sb = [scriptblock]::Create($text.Replace('Write-Output', ''))
        (& $sb) | Should -Be ('Hello ' + $who)
    }

    It 'refuses a parameter of unknown type' {
        $dir = Join-Path $TestDrive 'BadRecipes\Bad'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content (Join-Path $dir 'Recipe.psd1') "@{ Name = 'Bad'; Version = '1'; Description = 'x'; Template = 't.template'; Parameters = @(@{ Name = 'X'; Type = 'Blob' }) }"
        Set-Content (Join-Path $dir 't.template') 'x'
        { Get-NSPClientScriptRecipe -RecipePath (Join-Path $TestDrive 'BadRecipes') } | Should -Throw '*unknown type*'
    }
}

Describe 'ConvertTo-NSPClientScript (ToolShim)' {
    It 'renders a script that parses, with CRLF endings and every token replaced' {
        $text = ConvertTo-NSPClientScript -Recipe ToolShim -Parameters $ShimBase
        $text | Should -Not -Match '\{\{'
        $text | Should -Not -Match "[^\r]`n"
        $text | Should -Match "\`$ModuleName\s+= 'NSP.FakeTool'"
    }

    It 'keeps a one-element Modules list a JSON array' {
        $text = ConvertTo-NSPClientScript -Recipe ToolShim -Parameters $ShimBase
        $text | Should -Match "(?s)\`$RequiredModulesJson = @'\r\n\[\s*\r\n"
    }

    It 'refuses unknown parameters, missing required ones, and pattern mismatches' {
        { ConvertTo-NSPClientScript -Recipe ToolShim -Parameters ($ShimBase + @{ Nope = 1 }) } | Should -Throw "*no parameter 'Nope'*"
        $missing = $ShimBase.Clone(); $missing.Remove('EntryFunction')
        { ConvertTo-NSPClientScript -Recipe ToolShim -Parameters $missing } | Should -Throw "*needs a value for 'EntryFunction'*"
        $bad = $ShimBase.Clone(); $bad.EntryFunction = 'Start-X; Remove-Item C:\'
        { ConvertTo-NSPClientScript -Recipe ToolShim -Parameters $bad } | Should -Throw '*does not match*'
        $badVer = $ShimBase.Clone(); $badVer.ModuleMinimumVersion = 'latest'
        { ConvertTo-NSPClientScript -Recipe ToolShim -Parameters $badVer } | Should -Throw '*not a version*'
    }

    It 'refuses Text that could break out of the header comment' {
        { ConvertTo-NSPClientScript -Recipe ToolShim -Parameters ($ShimBase + @{ Company = 'Evil #> Remove-Item' }) } | Should -Throw "*'#>'*"
        { ConvertTo-NSPClientScript -Recipe ToolShim -Parameters ($ShimBase + @{ Company = "two`nlines" }) } | Should -Throw '*single line*'
    }

    It 'refuses JSON that is invalid or would end the here-string early' {
        { ConvertTo-NSPClientScript -Recipe ToolShim -Parameters ($ShimBase + @{ SeedAnswers = '{ not json' }) } | Should -Throw '*not valid JSON*'
        { ConvertTo-NSPClientScript -Recipe ToolShim -Parameters ($ShimBase + @{ SeedAnswers = "[`n'@`n]" }) } | Should -Throw
    }

    It 'embeds awkward answers so they survive the round trip' {
        $seed = [ordered]@{ Company = "O'Brien & Sons"; Note = "line1`nline2 '@ `"q`""; Name = 'Zo' + [char]0x00EB; Secret = '$(Remove-Item C:\)' }
        $text = ConvertTo-NSPClientScript -Recipe ToolShim -Parameters ($ShimBase + @{ SeedAnswers = $seed })
        $m = [regex]::Match($text, "(?s)\`$SeedAnswersJson = @'\r\n(.*?)\r\n'@")
        $back = ConvertFrom-Json $m.Groups[1].Value
        $back.Company | Should -Be "O'Brien & Sons"
        $back.Note | Should -Be "line1`nline2 '@ `"q`""
        $back.Name | Should -Be ('Zo' + [char]0x00EB)
        $back.Secret | Should -Be '$(Remove-Item C:\)'
    }
}

Describe 'New-NSPClientScript' {
    It 'writes UTF-8 with a BOM and refuses to overwrite without -Force' {
        $p = Join-Path $TestDrive 'out\shim.ps1'
        New-NSPClientScript -Recipe ToolShim -Parameters $ShimBase -Path $p | Should -BeOfType [IO.FileInfo]
        $bytes = [IO.File]::ReadAllBytes($p)
        ($bytes[0], $bytes[1], $bytes[2]) -join ',' | Should -Be '239,187,191'
        { New-NSPClientScript -Recipe ToolShim -Parameters $ShimBase -Path $p } | Should -Throw '*already exists*'
        { New-NSPClientScript -Recipe ToolShim -Parameters $ShimBase -Path $p -Force } | Should -Not -Throw
    }

    It 'writes nothing under -WhatIf' {
        $p = Join-Path $TestDrive 'whatif.ps1'
        New-NSPClientScript -Recipe ToolShim -Parameters $ShimBase -Path $p -WhatIf
        Test-Path -LiteralPath $p | Should -BeFalse
    }
}

Describe 'Generated ToolShim, run for real against a fake tool' {
    BeforeEach {
        $script:Root = New-FakeToolRoot (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        $env:NSP_FAKE_TOOL_LOG = Join-Path $script:Root 'calls.log'
    }
    AfterEach {
        Remove-Item Env:\NSP_FAKE_TOOL_LOG -ErrorAction SilentlyContinue
    }

    It 'hands the seed over once, blanks it from the file, and starts the tool' {
        $seed = [ordered]@{ Company = "O'Brien"; Name = 'Zo' + [char]0x00EB }
        $shim = Join-Path $script:Root 'Fake-Tool.ps1'
        New-NSPToolShim @ShimBase -SeedAnswers $seed -Company 'Example Co' -Path $shim | Out-Null

        $run = Invoke-Shim $shim @('-ModuleRoot', $script:Root, '-NoElevate')
        $run.ExitCode | Should -Be 0 -Because $run.Output

        $calls = @(Read-FakeLog)
        $calls.Count | Should -Be 2
        $calls[0].SeedOnly | Should -BeTrue
        (ConvertFrom-Json $calls[0].Seed).Name | Should -Be ('Zo' + [char]0x00EB)
        $calls[1].SeedOnly | Should -BeFalse
        $calls[1].Seed | Should -BeNullOrEmpty

        $after = [IO.File]::ReadAllText($shim)
        $after | Should -Match "(?s)\`$SeedAnswersJson = @'\r\n\r\n'@"
        $after | Should -Not -Match 'O''Brien'
        $parseErrors = $null
        [Management.Automation.Language.Parser]::ParseInput($after, [ref]$null, [ref]$parseErrors) | Out-Null
        $parseErrors | Should -BeNullOrEmpty
        ([IO.File]::ReadAllBytes($shim))[0] | Should -Be 239

        # Second run: nothing to hand over, so only the launch call.
        Remove-Item -LiteralPath $env:NSP_FAKE_TOOL_LOG
        (Invoke-Shim $shim @('-ModuleRoot', $script:Root, '-NoElevate')).ExitCode | Should -Be 0
        $calls = @(Read-FakeLog)
        $calls.Count | Should -Be 1
        $calls[0].SeedOnly | Should -BeFalse
    }

    It 'just launches the tool when generated without answers' {
        $shim = Join-Path $script:Root 'NoSeed.ps1'
        New-NSPToolShim @ShimBase -Path $shim | Out-Null
        (Invoke-Shim $shim @('-ModuleRoot', $script:Root, '-NoElevate')).ExitCode | Should -Be 0
        $calls = @(Read-FakeLog)
        $calls.Count | Should -Be 1
        $calls[0].SeedOnly | Should -BeFalse
    }

    It 'exits 1 with a clear message when -ModuleRoot does not exist' {
        $shim = Join-Path $script:Root 'BadRoot.ps1'
        New-NSPToolShim @ShimBase -Path $shim | Out-Null
        $run = Invoke-Shim $shim @('-ModuleRoot', (Join-Path $TestDrive 'nope'), '-NoElevate')
        $run.ExitCode | Should -Be 1
        $run.Output | Should -Match 'ModuleRoot not found'
    }

    It 'exits 1 when the tool module is below the minimum version' {
        $shim = Join-Path $script:Root 'TooOld.ps1'
        New-NSPToolShim @ShimBase -Path $shim -Force | Out-Null
        (Get-Content $shim -Raw).Replace("`$ModuleMinimumVersion    = '0.1.0'", "`$ModuleMinimumVersion    = '9.0.0'") | Set-Content $shim -Encoding UTF8
        $run = Invoke-Shim $shim @('-ModuleRoot', $script:Root, '-NoElevate')
        $run.ExitCode | Should -Be 1
        $run.Output | Should -Match 'Could not load NSP.FakeTool 9.0.0'
    }
}

Describe 'Installer recipes (ControlInstaller, HuntressInstaller)' {
    BeforeAll {
        $script:ControlBase = @{ BaseInstallerUri = 'https://contoso.screenconnect.com/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest'; ClientCode = 'Contoso Ltd'; DeviceType = 'Workstation'; Company = 'Contoso' }
        $script:HuntressBase = @{ AccountKey = ('0123456789abcdef' * 2); OrganizationKey = 'Contoso'; Company = 'Contoso' }

        function Get-ControlUriProbe([hashtable]$Parameters) {
            # The rendered script up to its first side effect, then print the URL - no download.
            $text = ConvertTo-NSPClientScript -Recipe ControlInstaller -Parameters $Parameters
            $probe = Join-Path $TestDrive ('ControlProbe_' + [guid]::NewGuid().ToString('N') + '.ps1')
            $head = $text.Substring(0, $text.IndexOf('New-Item -ItemType Directory')) + "`r`n`$installerUri`r`n"
            [IO.File]::WriteAllText($probe, $head, (New-Object Text.UTF8Encoding($true)))
            return $probe
        }
    }

    It 'are listed alongside ToolShim' {
        $names = @(Get-NSPClientScriptRecipe).Name
        $names | Should -Contain 'ControlInstaller'
        $names | Should -Contain 'HuntressInstaller'
    }

    It '<Recipe> renders a script that parses, and checks the signature before it installs' -TestCases @(
        @{ Recipe = 'ControlInstaller'; Install = 'msiexec.exe' }
        @{ Recipe = 'HuntressInstaller'; Install = 'Start-Process -FilePath $installerPath' }
    ) {
        $params = if ($Recipe -eq 'ControlInstaller') { $ControlBase } else { $HuntressBase }
        $text = ConvertTo-NSPClientScript -Recipe $Recipe -Parameters $params
        $text | Should -Not -Match '\{\{'
        $parseErrors = $null
        [Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$parseErrors) | Out-Null
        @($parseErrors).Count | Should -Be 0
        $sig = $text.IndexOf('Get-AuthenticodeSignature')
        $sig | Should -BeGreaterThan 0
        $text.IndexOf("-ne 'Valid'") | Should -BeGreaterThan $sig
        $text.IndexOf($Install) | Should -BeGreaterThan $text.IndexOf("-ne 'Valid'")
    }

    It 'ControlInstaller refuses a non-HTTPS or non-MSI installer URL, and quotes in the client code' {
        $http = $ControlBase.Clone(); $http.BaseInstallerUri = 'http://contoso.screenconnect.com/Bin/x.msi'
        { ConvertTo-NSPClientScript -Recipe ControlInstaller -Parameters $http } | Should -Throw '*does not match*'
        $exe = $ControlBase.Clone(); $exe.BaseInstallerUri = 'https://contoso.example/x.exe'
        { ConvertTo-NSPClientScript -Recipe ControlInstaller -Parameters $exe } | Should -Throw '*does not match*'
        $bad = $ControlBase.Clone(); $bad.ClientCode = "Contoso'; Stop-Computer"
        { ConvertTo-NSPClientScript -Recipe ControlInstaller -Parameters $bad } | Should -Throw '*does not match*'
    }

    It 'ControlInstaller builds the positional custom-property query' {
        & (Get-ControlUriProbe $ControlBase) -SessionName 'PC 01' |
            Should -Be 'https://contoso.screenconnect.com/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest&t=PC%2001&c=Contoso%20Ltd&c=&c=&c=Workstation&c=&c=&c=&c='
        $default = $ControlBase.Clone(); $default.Remove('DeviceType')
        & (Get-ControlUriProbe $default) |
            Should -Be 'https://contoso.screenconnect.com/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest&c=Contoso%20Ltd&c=&c=&c=&c=&c=&c=&c='
    }

    It 'HuntressInstaller refuses an account key that is not 32 hex characters' {
        $bad = $HuntressBase.Clone(); $bad.AccountKey = 'not-a-key'
        { ConvertTo-NSPClientScript -Recipe HuntressInstaller -Parameters $bad } | Should -Throw '*does not match*'
    }

    It 'HuntressInstaller refuses a run-time organization key with a quote before touching the machine' {
        $script = Join-Path $TestDrive 'Huntress.ps1'
        $params = $HuntressBase + @{ DownloadDirectory = (Join-Path $TestDrive 'dl'); TranscriptDirectory = (Join-Path $TestDrive 'logs') }
        New-NSPClientScript -Recipe HuntressInstaller -Parameters $params -Path $script -Force | Out-Null
        # In process: 'exit' in a script run with & ends only that script. (A child process would
        # mangle the embedded quote on its way through the 5.1 command line.)
        $out = & $script -OrganizationKey 'Con"toso' | Out-String
        $LASTEXITCODE | Should -Be 1
        $out | Should -Match 'may not contain quotes'
        Test-Path -LiteralPath (Join-Path $TestDrive 'dl') | Should -BeFalse
    }
}
