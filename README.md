# NSP.ClientScripts

Generates standalone, client-specific PowerShell scripts from reviewed **recipes**: a template
plus a typed parameter schema. Every value is validated and quoted by type, and the rendered
script is parsed before it is written. Nothing is ever executed. Windows PowerShell **5.1**
compatible (and 7+); imports on a bare host.

## What's in it

| Function | Purpose |
|---|---|
| `Get-NSPClientScriptRecipe` | List the built-in recipes (or your own, with `-RecipePath`) and their parameters. |
| `ConvertTo-NSPClientScript` | Render a recipe to text. Throws on an unknown/missing/invalid value or a result that doesn't parse. |
| `New-NSPClientScript` | Render and write (UTF-8 with BOM, CRLF). Refuses to overwrite without `-Force`; supports `-WhatIf`. |
| `New-NSPToolShim` | Write a launcher for a module-hosted NSP tool (the `ToolShim` recipe) with optional seed answers. Tool modules wrap this (`New-NSPADShim`, ...). |

## The ToolShim recipe

A generated shim, run on a server:

1. relaunches itself elevated if needed;
2. installs NSP.Bootstrap, then the tool's modules, from the PowerShell Gallery (`-ModuleRoot
   <folder>` loads them from a folder instead - unreleased builds, or no Gallery access);
3. if answers are embedded, calls `<EntryFunction> -SeedAnswersJson <json> -SeedOnly` once and
   then blanks the answers from its own file;
4. calls `<EntryFunction>`.

That two-call contract is all a shim knows about a tool, so an old shim keeps working with newer
modules.

```powershell
New-NSPToolShim -ToolName 'AD Manager' -ModuleName NSP.ActiveDirectory -ModuleMinimumVersion 0.1.0 `
    -EntryFunction Start-NSPADManager -SeedAnswers @{ CompanyName = 'Example Co' } -Path C:\Temp\AD-Manager.ps1
```

## Recipes

A recipe is a folder with `Recipe.psd1` and a template:

```powershell
@{
    Name = 'Hello'; Version = '1'; Description = '...'; Template = 'Template.ps1.template'
    Parameters = @(
        @{ Name = 'Who'; Type = 'String'; Required = $true; Pattern = '^[A-Za-z ]+$' }
    )
}
```

Template tokens are `{{Name}}`. Types: `String` and `Version` (single-quoted literal), `Bool`
(`$true`/`$false`), `Json` (raw JSON for a single-quoted here-string), `Text` (raw single line, for
comments). `{{Name:Text}}` renders any parameter as Text. Built-ins: `{{GENERATED_UTC}}`,
`{{ENGINE_VERSION}}`, `{{RECIPE_NAME}}`, `{{RECIPE_VERSION}}`.

## Tests

```powershell
.\tools\Test-Repo.ps1      # PSScriptAnalyzer + Pester 5 under Windows PowerShell 5.1 and pwsh
```
