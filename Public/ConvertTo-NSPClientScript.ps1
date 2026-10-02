function ConvertTo-NSPClientScript {
    <#
    .SYNOPSIS
        Renders a recipe with the given parameter values and returns the script text (nothing is
        written). Throws if a value is invalid or the result does not parse.

    .DESCRIPTION
        Template tokens are {{ParameterName}}, rendered by the parameter's type:
          String   a single-quoted PowerShell literal ('O''Brien'), for code;
          Version  the same, after checking it is a valid [version];
          Bool     $true / $false;
          Json     raw JSON text for a single-quoted here-string - an object is converted with
                   ConvertTo-Json -Depth 20, a string is checked to parse; empty is allowed when
                   the parameter is optional;
          Text     the raw value, one line, for comments (line breaks and comment-block
                   delimiters are refused).
        {{Name:Text}} renders any parameter as Text. Built-in tokens: {{GENERATED_UTC}},
        {{ENGINE_VERSION}}, {{RECIPE_NAME}}, {{RECIPE_VERSION}}.

        The result uses CRLF line endings and is parsed before it is returned.

    .PARAMETER Recipe
        Recipe name (see Get-NSPClientScriptRecipe), or a recipe object from it.

    .PARAMETER Parameters
        Hashtable of parameter values. Unknown keys are refused, so a typo can't silently fall back
        to a default.

    .PARAMETER RecipePath
        Folder of custom recipes to look the name up in, instead of the built-in ones.

    .EXAMPLE
        ConvertTo-NSPClientScript -Recipe ToolShim -Parameters @{
            ToolName = 'AD Manager'; ModuleName = 'NSP.ActiveDirectory'; ModuleMinimumVersion = '0.1.0'
            EntryFunction = 'Start-NSPADManager'; Modules = @(@{ Name = 'NSP.ActiveDirectory'; MinimumVersion = '0.1.0' })
        }
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][object]$Recipe,
        [hashtable]$Parameters = @{},
        [string]$RecipePath
    )

    if ($Recipe -is [string]) {
        $lookup = @{ Name = $Recipe }
        if ($RecipePath) { $lookup['RecipePath'] = $RecipePath }
        $found = @(Get-NSPClientScriptRecipe @lookup | Where-Object { $_.Name -eq $Recipe })
        if ($found.Count -ne 1) { throw "No recipe named '$Recipe'." }
        $Recipe = $found[0]
    }

    $known = @($Recipe.Parameters | ForEach-Object { $_.Name })
    foreach ($key in $Parameters.Keys) {
        if ($known -notcontains $key) { throw "Recipe '$($Recipe.Name)' has no parameter '$key'. Parameters: $($known -join ', ')." }
    }

    # Resolve every parameter to its (validated) raw value first.
    $values = @{}
    foreach ($p in $Recipe.Parameters) {
        # Assigned in branches, not via an if-expression, which would unroll a one-element array.
        if ($Parameters.ContainsKey($p.Name)) { $value = $Parameters[$p.Name] } else { $value = $p.Default }
        $isEmpty = ($null -eq $value) -or (($value -is [string]) -and [string]::IsNullOrWhiteSpace($value))
        if ($isEmpty -and $p.Required) { throw "Recipe '$($Recipe.Name)' needs a value for '$($p.Name)'." }
        $values[$p.Name] = ConvertTo-NSPRecipeValue -Parameter $p -Value $value -IsEmpty:$isEmpty
    }

    $engineVersion = (Get-Module NSP.ClientScripts | Sort-Object Version -Descending | Select-Object -First 1).Version
    $builtIns = @{
        GENERATED_UTC  = [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss') + ' UTC'
        ENGINE_VERSION = [string]$engineVersion
        RECIPE_NAME    = $Recipe.Name
        RECIPE_VERSION = $Recipe.Version
    }

    $template = [IO.File]::ReadAllText($Recipe.TemplatePath)
    $rendered = [regex]::Replace($template, '\{\{([A-Za-z_][A-Za-z0-9_]*)(?::(Text))?\}\}', {
        param($m)
        $tokenName = $m.Groups[1].Value
        $asText = $m.Groups[2].Success
        if ($builtIns.ContainsKey($tokenName)) { return $builtIns[$tokenName] }
        if (-not $values.ContainsKey($tokenName)) { throw "Template token {{$tokenName}} is not a parameter of recipe '$($Recipe.Name)'." }
        $v = $values[$tokenName]
        if ($asText) { return (ConvertTo-NSPRecipeText $v.Raw) }
        return $v.Rendered
    })

    $rendered = ($rendered -replace "`r`n", "`n") -replace "`n", "`r`n"

    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseInput($rendered, [ref]$null, [ref]$parseErrors) | Out-Null
    if ($parseErrors) { throw "Recipe '$($Recipe.Name)' rendered a script that does not parse: $($parseErrors[0].Message) (line $($parseErrors[0].Extent.StartLineNumber))" }

    return $rendered
}
