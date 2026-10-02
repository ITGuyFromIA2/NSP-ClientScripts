$script:RecipeParameterTypes = @('String', 'Version', 'Bool', 'Json', 'Text')

function ConvertTo-NSPPSLiteral {
    # Single-quoted PowerShell string literal. Doubling ' is the only escape a single-quoted
    # string has; the "smart" single quotes PowerShell also treats as delimiters are doubled too.
    param([AllowEmptyString()][string]$Value)
    # Built with [char] codes, not literal characters, so this file stays ASCII.
    $quoteClass = '[' + [char]0x27 + [char]0x2018 + [char]0x2019 + [char]0x201A + [char]0x201B + ']'
    $escaped = [regex]::Replace($Value, $quoteClass, { param($m) $m.Value + $m.Value })
    return "'" + $escaped + "'"
}

function ConvertTo-NSPRecipeText {
    # Raw single-line text for a comment.
    param([AllowEmptyString()][string]$Value)
    if ($Value -match "[\r\n]") { throw "A Text value must be a single line: '$Value'." }
    if ($Value -match '#>|<#') { throw "A Text value may not contain '<#' or '#>': '$Value'." }
    return $Value
}

function ConvertTo-NSPRecipeValue {
    # Validates one recipe parameter value and returns @{ Raw; Rendered }.
    param(
        [Parameter(Mandatory)][object]$Parameter,
        [AllowNull()][object]$Value,
        [switch]$IsEmpty
    )

    $name = $Parameter.Name
    switch ($Parameter.Type) {
        'String' {
            $s = if ($IsEmpty) { '' } else { [string]$Value }
            if ($s -match "[\r\n]") { throw "Parameter '$name' must be a single line." }
            if ($Parameter.Pattern -and -not $IsEmpty -and $s -notmatch $Parameter.Pattern) {
                throw "Parameter '$name' value '$s' does not match $($Parameter.Pattern)."
            }
            return @{ Raw = $s; Rendered = (ConvertTo-NSPPSLiteral $s) }
        }
        'Version' {
            $s = if ($IsEmpty) { '' } else { [string]$Value }
            $parsed = $null
            if (-not $IsEmpty -and -not [version]::TryParse($s, [ref]$parsed)) { throw "Parameter '$name' value '$s' is not a version." }
            return @{ Raw = $s; Rendered = (ConvertTo-NSPPSLiteral $s) }
        }
        'Bool' {
            $b = if ($IsEmpty) { $false } elseif ($Value -is [string]) { $Value -match '^(?i)(true|1|yes|y)$' } else { [bool]$Value }
            return @{ Raw = [string]$b; Rendered = $(if ($b) { '$true' } else { '$false' }) }
        }
        'Json' {
            if ($IsEmpty) { return @{ Raw = ''; Rendered = '' } }
            if ($Value -is [string]) {
                try { $null = ConvertFrom-Json -InputObject $Value -ErrorAction Stop }
                catch { throw "Parameter '$name' is not valid JSON: $($_.Exception.Message)" }
                $json = $Value.Trim()
            } else {
                # -InputObject keeps a single-element array an array (piping would unroll it).
                $json = ConvertTo-Json -InputObject $Value -Depth 20
            }
            $json = ($json -replace "`r`n", "`n") -replace "`n", "`r`n"
            # A line starting with '@ would end the here-string early. ConvertTo-Json never emits
            # one (newlines inside strings are escaped), but a hand-written string could.
            if ($json -match "(?m)^'@") { throw "Parameter '$name' JSON has a line starting with '@, which would end the here-string it is embedded in." }
            return @{ Raw = $json; Rendered = $json }
        }
        'Text' {
            $s = if ($IsEmpty) { '' } else { [string]$Value }
            return @{ Raw = $s; Rendered = (ConvertTo-NSPRecipeText $s) }
        }
    }
}
