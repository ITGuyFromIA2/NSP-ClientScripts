function New-NSPToolShim {
    <#
    .SYNOPSIS
        Writes a launcher script (the ToolShim recipe) for a module-hosted NSP tool, optionally with
        seed answers embedded. This is the engine behind New-NSPADShim, New-NSPNpsShim and the rest.

    .DESCRIPTION
        The shim elevates, installs NSP.Bootstrap and then -Modules from the PowerShell Gallery (or
        loads them from its own -ModuleRoot parameter), hands -SeedAnswers to the tool once via
        "<EntryFunction> -SeedAnswersJson <json> -SeedOnly", blanks them from its own file, then
        runs "<EntryFunction>". With no -SeedAnswers it just launches the tool, which asks its
        normal first-run questions.

        -Modules defaults to just the tool module. List sibling NSP modules too when the tool
        loads them, so the shim installs them up front.

    .PARAMETER ToolName
        Display name, e.g. 'AD Manager'.

    .PARAMETER ModuleName
        Module hosting the tool, e.g. NSP.ActiveDirectory.

    .PARAMETER ModuleMinimumVersion
        Oldest version of ModuleName the shim accepts.

    .PARAMETER EntryFunction
        Function that starts the tool; must accept -SeedAnswersJson and -SeedOnly.

    .PARAMETER Modules
        Modules to install, as hashtables/objects with Name and MinimumVersion.

    .PARAMETER SeedAnswers
        Answers to embed: an object/hashtable (converted to JSON) or a JSON string.

    .PARAMETER Company
        Shown in the shim's header comment.

    .PARAMETER GeneratedBy
        Shown in the shim's header comment, e.g. 'Orchestrator 4.1.0'.

    .PARAMETER StartInShimFolder
        Start the tool in the shim's own folder. Without it, an elevated shim starts in System32,
        as v1 shims did. For tools that work on files shipped next to the shim.

    .PARAMETER PauseOnExit
        Wait for Enter after the tool returns (or fails), so a one-shot tool's results stay on
        screen in the elevated window.

    .PARAMETER WithCmd
        Also write <name>.cmd next to the shim, which runs it with a double-click (a double-clicked
        .ps1 opens in Notepad). The shim's file name must then be plain: letters, digits, space and
        . _ ( ) -.

    .PARAMETER Path
        Where to write the shim.

    .PARAMETER Force
        Overwrite an existing file.

    .EXAMPLE
        New-NSPToolShim -ToolName 'AD Manager' -ModuleName NSP.ActiveDirectory -ModuleMinimumVersion 0.1.0 `
            -EntryFunction Start-NSPADManager -Path C:\Temp\AD-Manager.ps1

    .EXAMPLE
        New-NSPToolShim -ToolName 'Certificate Install' -ModuleName NSP.SSLCertificates -ModuleMinimumVersion 0.2.0 `
            -EntryFunction Install-NSPSslCertificate -StartInShimFolder -PauseOnExit -WithCmd -Path .\Install-Certificate.ps1
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([IO.FileInfo])]
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)][string]$ModuleName,
        [Parameter(Mandatory)][version]$ModuleMinimumVersion,
        [Parameter(Mandatory)][string]$EntryFunction,
        [object[]]$Modules,
        [object]$SeedAnswers,
        [string]$Company,
        [string]$GeneratedBy,
        [switch]$StartInShimFolder,
        [switch]$PauseOnExit,
        [switch]$WithCmd,
        [Parameter(Mandatory)][string]$Path,
        [switch]$Force
    )

    $cmdPath = $null
    if ($WithCmd) {
        # The name goes into the .cmd unquoted by anything but "...", so cmd's specials (% ^ & ! ...) are kept out.
        $leaf = Split-Path -Leaf $Path
        if ($leaf -notmatch '^[A-Za-z0-9 ._()-]+\.ps1$') { throw "With -WithCmd the shim's file name must be letters, digits, space and . _ ( ) - ending in .ps1: '$leaf'." }
        $cmdPath = [IO.Path]::ChangeExtension($Path, '.cmd')
        if ((Test-Path -LiteralPath $cmdPath) -and -not $Force) { throw "$cmdPath already exists. Use -Force to overwrite." }
    }

    if (-not $Modules) { $Modules = @(@{ Name = $ModuleName; MinimumVersion = [string]$ModuleMinimumVersion }) }
    $moduleList = @(foreach ($m in $Modules) {
        $n = if ($m -is [hashtable]) { $m['Name'] } else { $m.Name }
        $v = if ($m -is [hashtable]) { $m['MinimumVersion'] } else { $m.MinimumVersion }
        if (-not $n) { throw 'Each -Modules entry needs a Name.' }
        [ordered]@{ Name = [string]$n; MinimumVersion = [string]$v }
    })
    if (-not ($moduleList | Where-Object { $_.Name -eq $ModuleName })) {
        $moduleList += [ordered]@{ Name = $ModuleName; MinimumVersion = [string]$ModuleMinimumVersion }
    }

    $values = @{
        ToolName             = $ToolName
        ModuleName           = $ModuleName
        ModuleMinimumVersion = [string]$ModuleMinimumVersion
        EntryFunction        = $EntryFunction
        Modules              = $moduleList
    }
    if ($null -ne $SeedAnswers) { $values['SeedAnswers'] = $SeedAnswers }
    if ($Company) { $values['Company'] = $Company }
    if ($GeneratedBy) { $values['GeneratedBy'] = $GeneratedBy }
    if ($StartInShimFolder) { $values['StartInShimFolder'] = $true }
    if ($PauseOnExit) { $values['PauseOnExit'] = $true }

    if ($PSCmdlet.ShouldProcess($Path, "Write $ToolName shim")) {
        New-NSPClientScript -Recipe ToolShim -Parameters $values -Path $Path -Force:$Force -Confirm:$false
        if ($cmdPath) {
            $version = $MyInvocation.MyCommand.Module.Version
            $cmd = @(
                '@echo off'
                "rem $ToolName - generated by NSP.ClientScripts $version. Double-click to run $leaf beside it."
                ('"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0' + $leaf + '" %*')
            ) -join "`r`n"
            [IO.File]::WriteAllText($PSCmdlet.GetUnresolvedProviderPathFromPSPath($cmdPath),$cmd + "`r`n", (New-Object Text.ASCIIEncoding))
            Get-Item -LiteralPath $cmdPath
        }
    }
}
