param(
    [Parameter(Mandatory=$true)]
    [string]$SkillPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SkillPath)) {
    Write-Error "path not found: $SkillPath"
    exit 1
}

if ((Get-Item -LiteralPath $SkillPath).PSIsContainer) {
    $SkillFile = Join-Path -Path $SkillPath -ChildPath "SKILL.md"
    $SkillDir = $SkillPath
} else {
    $SkillFile = $SkillPath
    $SkillDir = (Get-Item -LiteralPath $SkillPath).DirectoryName
}

if (-not (Test-Path -LiteralPath $SkillFile)) {
    Write-Error "SKILL.md not found: $SkillFile"
    exit 1
}

$errors = @()
$warnings = @()

# 1. YAML frontmatter
$content = Get-Content -LiteralPath $SkillFile -Raw -Encoding UTF8
if ($content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') {
    $errors += "YAML frontmatter missing or malformed"
} else {
    $yamlBlock = $matches[1]
    if ($yamlBlock -notmatch '(?m)^name:\s*\S') {
        $errors += "name field missing or empty"
    }
    if ($yamlBlock -notmatch '(?m)^description:\s*\S') {
        $errors += "description field missing or empty"
    }
}

# 2. Markdown code blocks
$fenceCount = [regex]::Matches($content, '```').Count
if ($fenceCount % 2 -ne 0) {
    $errors += "code block not closed (odd fence count: $fenceCount)"
}

# 3. Check for duplicate content within the file
$lines = Get-Content -LiteralPath $SkillFile
$paragraphs = @()
$currentPara = ""
foreach ($line in $lines) {
    if ($line.Trim() -eq "") {
        if ($currentPara.Trim() -ne "") {
            $paragraphs += $currentPara.Trim()
            $currentPara = ""
        }
    } else {
        $currentPara += " " + $line.Trim()
    }
}
if ($currentPara.Trim() -ne "") {
    $paragraphs += $currentPara.Trim()
}

$seenParas = @{}
$duplicates = @()
foreach ($para in $paragraphs) {
    if ($para.Length -gt 30) {
        $key = $para.Substring(0, [Math]::Min(60, $para.Length))
        if ($seenParas.ContainsKey($key)) {
            $duplicates += $key.Substring(0, [Math]::Min(40, $key.Length)) + "..."
        } else {
            $seenParas[$key] = $true
        }
    }
}
if ($duplicates.Count -gt 0) {
    $warnings += "duplicate paragraphs found: $($duplicates.Count)"
}

# 4. Check heading levels
$headings = [regex]::Matches($content, '^(#{1,6})\s', [System.Text.RegularExpressions.RegexOptions]::Multiline)
$lastLevel = 0
$skipLevels = $false
foreach ($h in $headings) {
    $level = $h.Groups[1].Value.Length
    if ($lastLevel -gt 0 -and $level -gt ($lastLevel + 1)) {
        $skipLevels = $true
    }
    $lastLevel = $level
}
if ($skipLevels) {
    $warnings += "heading level skipped (e.g. ## then ####)"
}

# 5. Check table formatting
$tableRows = [regex]::Matches($content, '^\|.+\|$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
if ($tableRows.Count -gt 0) {
    $hasSeparator = $false
    foreach ($row in $tableRows) {
        if ($row.Value -match '^\|[\s\-:]+\|') {
            $hasSeparator = $true
            break
        }
    }
    if (-not $hasSeparator) {
        $warnings += "table separator row missing"
    }
}

# 6. Check references (if references/ directory exists)
$refDir = Join-Path -Path $SkillDir -ChildPath "references"
if (Test-Path -LiteralPath $refDir) {
    $refMatches = [regex]::Matches($content, 'references/[\w.-]+\.\w+')
    foreach ($m in $refMatches) {
        $refPath = Join-Path -Path $SkillDir -ChildPath $m.Value
        if (-not (Test-Path -LiteralPath $refPath)) {
            $errors += "referenced file not found: $($m.Value)"
        }
    }
}

# 7. Check scripts
$scriptMatches = [regex]::Matches($content, 'scripts/[\w.-]+\.\w+')
foreach ($m in $scriptMatches) {
    $scriptPath = Join-Path -Path $SkillDir -ChildPath $m.Value
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        $warnings += "script file not found: $($m.Value)"
    }
}

# Output
$valid = ($errors.Count -eq 0)

Write-Host "## Validation result: $($SkillFile)"
Write-Host "**Status**: $(if ($valid) { 'pass' } else { 'fail' })"
Write-Host "**Errors**: $($errors.Count) | **Warnings**: $($warnings.Count)"
Write-Host ""

if ($errors.Count -gt 0) {
    Write-Host "### Errors"
    foreach ($e in $errors) {
        Write-Host "- [ERROR] $e"
    }
    Write-Host ""
}
if ($warnings.Count -gt 0) {
    Write-Host "### Warnings"
    foreach ($w in $warnings) {
        Write-Host "- [WARNING] $w"
    }
    Write-Host ""
}

if ($valid) { exit 0 } else { exit 1 }