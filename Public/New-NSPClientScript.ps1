function New-NSPClientScript {
    <#
    .SYNOPSIS
        Renders a recipe and writes the script to -Path (UTF-8 with BOM, CRLF). The script is
        never run here.

    .DESCRIPTION
        See ConvertTo-NSPClientScript for how parameters render. The BOM matters: Windows
        PowerShell 5.1 reads a BOM-less file as ANSI, which would mangle any non-ASCII answer.
        Refuses to overwrite an existing file unless -Force is given. Supports -WhatIf.

    .PARAMETER Recipe
        Recipe name or object.

    .PARAMETER Parameters
        Hashtable of parameter values.

    .PARAMETER Path
        Where to write the script.

    .PARAMETER RecipePath
        Folder of custom recipes.

    .PARAMETER Force
        Overwrite an existing file.

    .EXAMPLE
        New-NSPClientScript -Recipe ToolShim -Path C:\Temp\AD-Manager.ps1 -Parameters @{
            ToolName = 'AD Manager'; ModuleName = 'NSP.ActiveDirectory'; ModuleMinimumVersion = '0.1.0'
            EntryFunction = 'Start-NSPADManager'; Modules = @(@{ Name = 'NSP.ActiveDirectory'; MinimumVersion = '0.1.0' })
        }
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([IO.FileInfo])]
    param(
        [Parameter(Mandatory)][object]$Recipe,
        [hashtable]$Parameters = @{},
        [Parameter(Mandatory)][string]$Path,
        [string]$RecipePath,
        [switch]$Force
    )

    $convert = @{ Recipe = $Recipe; Parameters = $Parameters }
    if ($RecipePath) { $convert['RecipePath'] = $RecipePath }
    $text = ConvertTo-NSPClientScript @convert

    $destination = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
    if ((Test-Path -LiteralPath $destination) -and -not $Force) {
        throw "$destination already exists. Use -Force to replace it."
    }
    $recipeName = if ($Recipe -is [string]) { $Recipe } else { $Recipe.Name }
    if ($PSCmdlet.ShouldProcess($destination, "Write $recipeName script")) {
        $parent = Split-Path -Parent $destination
        if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        [IO.File]::WriteAllText($destination, $text, (New-Object Text.UTF8Encoding($true)))
        Get-Item -LiteralPath $destination
    }
}
