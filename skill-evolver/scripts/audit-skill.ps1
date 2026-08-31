param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("quick", "deep")]
    [string]$Mode = "quick",

    [Parameter(Mandatory=$false)]
    [string]$TargetSkill = ""
)

$ErrorActionPreference = "Stop"
# locate skills root relative to this script, no hardcoded user paths
$SkillsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$LogDir = Join-Path -Path $SkillsRoot -ChildPath "skill-evolver\logs"
$AuditLog = Join-Path -Path $LogDir -ChildPath "audit-report-latest.md"

if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Get-AllSkills {
    $skills = @()
    foreach ($dir in @(Get-ChildItem -LiteralPath $SkillsRoot -Directory)) {
        $skillDir = $dir.FullName
        $skillName = $dir.Name
        $skillFile = Join-Path -Path $skillDir -ChildPath "SKILL.md"
        if (Test-Path -LiteralPath $skillFile) {
            $skills += @{
                Name = $skillName
                Path = $skillDir
                SkillFile = $skillFile
            }
        }
    }
    return $skills
}

function Check-YamlFrontmatter {
    param([string]$FilePath)
    $content = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
    if ($content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') {
        return $false, "YAML frontmatter missing or malformed"
    }
    $yamlBlock = $matches[1]
    if ($yamlBlock -notmatch '(?m)^name:\s*\S') {
        return $false, "name field missing or empty"
    }
    if ($yamlBlock -notmatch '(?m)^description:\s*\S') {
        return $false, "description field missing or empty"
    }
    return $true, ""
}

function Check-LineCount {
    param([string]$FilePath)
    $lines = Get-Content -LiteralPath $FilePath
    return $lines.Count -ge 50
}

function Check-CodeBlocks {
    param([string]$FilePath)
    $content = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
    $fenceCount = [regex]::Matches($content, '```').Count
    return ($fenceCount % 2) -eq 0
}

function Check-References {
    param([string]$SkillDir, [string]$SkillFile)
    $issues = @()
    $content = Get-Content -LiteralPath $SkillFile -Raw
    $refPattern = 'references/[\w.-]+\.md'
    $matches = [regex]::Matches($content, $refPattern)
    foreach ($m in $matches) {
        $refPath = Join-Path -Path $SkillDir -ChildPath $m.Value
        if (-not (Test-Path -LiteralPath $refPath)) {
            $issues += @{
                Type = "Error"
                Desc = "referenced file not found: $($m.Value)"
            }
        }
    }
    return $issues
}

function Check-Scripts {
    param([string]$SkillDir, [string]$SkillFile)
    $issues = @()
    $content = Get-Content -LiteralPath $SkillFile -Raw
    $scriptPattern = 'scripts/[\w.-]+\.\w+'
    $matches = [regex]::Matches($content, $scriptPattern)
    foreach ($m in $matches) {
        $scriptPath = Join-Path -Path $SkillDir -ChildPath $m.Value
        if (-not (Test-Path -LiteralPath $scriptPath)) {
            $issues += @{ Type = "Error"; Desc = "script file not found: $($m.Value)" }
        }
    }
    return $issues
}

function Check-EmptyRefs {
    param([string]$SkillDir)
    $refDir = Join-Path -Path $SkillDir -ChildPath "references"
    if (Test-Path -LiteralPath $refDir) {
        $items = Get-ChildItem -LiteralPath $refDir
        if ($items.Count -eq 0) {
            return @(@{ Type = "Warning"; Desc = "references/ directory is empty" })
        }
    }
    return @()
}

function Write-AuditReport {
    param([array]$AllIssues, [int]$SkillCount)
    $reportLines = @()
    $reportLines += "# Skills Audit Report"
    $reportLines += ""
    $reportLines += "**Scan time**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $reportLines += "**Scan mode**: $Mode"
    $reportLines += "**Skills covered**: $SkillCount"
    $reportLines += "**Issues found**: $($AllIssues.Count)"
    $reportLines += ""

    $blockers = $AllIssues | Where-Object { $_.Severity -eq "Blocker" }
    $errors = $AllIssues | Where-Object { $_.Severity -eq "Error" }
    $warnings = $AllIssues | Where-Object { $_.Severity -eq "Warning" }

    if ($blockers.Count -gt 0) {
        $reportLines += "## Blockers"
        foreach ($issue in $blockers) {
            $reportLines += "- [$($issue.Skill)] $($issue.Desc)"
        }
        $reportLines += ""
    }
    if ($errors.Count -gt 0) {
        $reportLines += "## Errors"
        foreach ($issue in $errors) {
            $reportLines += "- [$($issue.Skill)] $($issue.Desc)"
        }
        $reportLines += ""
    }
    if ($warnings.Count -gt 0) {
        $reportLines += "## Warnings"
        foreach ($issue in $warnings) {
            $reportLines += "- [$($issue.Skill)] $($issue.Desc)"
        }
        $reportLines += ""
    }

    $reportContent = $reportLines -join "`n"
    Set-Content -LiteralPath $AuditLog -Value $reportContent -Encoding UTF8
    Write-Host "audit report saved to: $AuditLog"
    Write-Host $reportContent
}

# Main
$skills = Get-AllSkills
if ($TargetSkill -ne "") {
    $skills = $skills | Where-Object { $_.Name -eq $TargetSkill }
    if ($skills.Count -eq 0) {
        Write-Error "skill not found: $TargetSkill"
        exit 1
    }
}

$allIssues = @()
foreach ($skill in $skills) {
    $skillName = $skill.Name
    $skillFile = $skill.SkillFile
    $skillDir = $skill.Path

    # Check existence
    if (-not (Test-Path -LiteralPath $skillFile)) {
        $allIssues += @{ Skill = $skillName; Severity = "Blocker"; Desc = "SKILL.md file not found" }
        continue
    }

    # Check YAML frontmatter
    $yamlOk, $yamlErr = Check-YamlFrontmatter -FilePath $skillFile
    if (-not $yamlOk) {
        $allIssues += @{ Skill = $skillName; Severity = "Error"; Desc = $yamlErr }
    }

    # Check code blocks
    if (-not (Check-CodeBlocks -FilePath $skillFile)) {
        $allIssues += @{ Skill = $skillName; Severity = "Error"; Desc = "code block not closed properly" }
    }

    if ($Mode -eq "deep") {
        if (-not (Check-LineCount -FilePath $skillFile)) {
            $allIssues += @{ Skill = $skillName; Severity = "Warning"; Desc = "main body under 50 lines, thin content" }
        }
        $refIssues = Check-References -SkillDir $skillDir -SkillFile $skillFile
        foreach ($ri in $refIssues) {
            $allIssues += @{ Skill = $skillName; Severity = $ri.Type; Desc = $ri.Desc }
        }
        $scriptIssues = Check-Scripts -SkillDir $skillDir -SkillFile $skillFile
        foreach ($si in $scriptIssues) {
            $allIssues += @{ Skill = $skillName; Severity = $si.Type; Desc = $si.Desc }
        }
        $emptyRefs = Check-EmptyRefs -SkillDir $skillDir
        foreach ($er in $emptyRefs) {
            $allIssues += @{ Skill = $skillName; Severity = $er.Type; Desc = $er.Desc }
        }
    }
}

Write-AuditReport -AllIssues $allIssues -SkillCount $skills.Count
exit 0