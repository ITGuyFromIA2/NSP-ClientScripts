function Get-NSPClientScriptRecipe {
    <#
    .SYNOPSIS
        Lists the script recipes this module can render (or the ones in -RecipePath).

    .DESCRIPTION
        A recipe is a folder holding Recipe.psd1 (name, version, description, template file name and
        a typed parameter schema) and the template itself. Built-in recipes ship in the module's
        Recipes\ folder; -RecipePath points at a folder of your own recipes, laid out the same way.

    .PARAMETER Name
        Return only this recipe (wildcards allowed).

    .PARAMETER RecipePath
        A folder of recipe folders to search instead of the built-in ones.

    .EXAMPLE
        Get-NSPClientScriptRecipe

    .EXAMPLE
        (Get-NSPClientScriptRecipe -Name ToolShim).Parameters | Format-Table Name, Type, Required
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Name = '*',
        [string]$RecipePath = (Join-Path $script:ModuleRoot 'Recipes')
    )

    foreach ($dir in @(Get-ChildItem -LiteralPath $RecipePath -Directory -ErrorAction Stop)) {
        $manifestPath = Join-Path $dir.FullName 'Recipe.psd1'
        if (-not (Test-Path -LiteralPath $manifestPath)) { continue }
        $data = Import-PowerShellDataFile -LiteralPath $manifestPath
        if ($data.Name -notlike $Name) { continue }

        $templatePath = Join-Path $dir.FullName $data.Template
        if (-not (Test-Path -LiteralPath $templatePath)) { throw "Recipe '$($data.Name)' names a template that does not exist: $templatePath" }

        $parameters = foreach ($p in @($data.Parameters)) {
            if ($p.Type -notin $script:RecipeParameterTypes) {
                throw "Recipe '$($data.Name)' parameter '$($p.Name)' has unknown type '$($p.Type)'. Use one of: $($script:RecipeParameterTypes -join ', ')."
            }
            [pscustomobject]@{
                Name     = $p.Name
                Type     = $p.Type
                Required = [bool]$p.Required
                Default  = $p.Default
                Pattern  = $p.Pattern
            }
        }

        [pscustomobject]@{
            PSTypeName   = 'NSP.ClientScriptRecipe'
            Name         = $data.Name
            Version      = [string]$data.Version
            Description  = $data.Description
            Parameters   = @($parameters)
            TemplatePath = $templatePath
            Path         = $dir.FullName
        }
    }
}
