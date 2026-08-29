param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("quick", "deep")]
    [string]$Mode = "quick",

    [Parameter(Mandatory=$false)]
    [string]$TargetSkill = ""
)

$ErrorActionPreference = "Stop"
$SkillsRoot = "C:\Users\离众\.config\opencode\skills"
$LogDir = Join-Path -Path $SkillsRoot -ChildPath "skill-evolver\logs"
$AuditLog = Join-Path -Path $LogDir -ChildPath "audit-report-latest.md"

if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Get-AllSkills {
    $skills = @()
    Get-ChildItem -LiteralPath $SkillsRoot -Directory | ForEach-Object {
        $skillDir = $_.FullName
        $skillName = $_.Name
        $skillFile = Join-Path -Path $skillDir -Path "SKILL.md"
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
    $content = Get-Content -LiteralPath $FilePath -Raw
    if ($content -notmatch '^---\s*\n(.*?)\n---') {
        return $false, "YAML frontmatter 缺失或格式错误"
    }
    $yamlBlock = $matches[1]
    if ($yamlBlock -notmatch '(?m)^name:\s*\S') {
        return $false, "name 字段缺失或为空"
    }
    if ($yamlBlock -notmatch '(?m)^description:\s*\S') {
        return $false, "description 字段缺失或为空"
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
    $content = Get-Content -LiteralPath $FilePath -Raw
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
                Desc = "引用文件不存在: $($m.Value)"
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
            $issues += @{ Type = "Error"; Desc = "脚本文件不存在: $($m.Value)" }
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
            return @(@{ Type = "Warning"; Desc = "references/ 目录为空" })
        }
    }
    return @()
}

function Write-AuditReport {
    param([array]$AllIssues, [int]$SkillCount)
    $reportLines = @()
    $reportLines += "# 技能库审计报告"
    $reportLines += ""
    $reportLines += "**扫描时间**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $reportLines += "**扫描模式**: $Mode"
    $reportLines += "**覆盖 Skill 数**: $SkillCount"
    $reportLines += "**发现问题数**: $($AllIssues.Count)"
    $reportLines += ""

    $blockers = $AllIssues | Where-Object { $_.Severity -eq "Blocker" }
    $errors = $AllIssues | Where-Object { $_.Severity -eq "Error" }
    $warnings = $AllIssues | Where-Object { $_.Severity -eq "Warning" }

    if ($blockers.Count -gt 0) {
        $reportLines += "## 严重问题 (Blocker)"
        foreach ($issue in $blockers) {
            $reportLines += "- [$($issue.Skill)] $($issue.Desc)"
        }
        $reportLines += ""
    }
    if ($errors.Count -gt 0) {
        $reportLines += "## 错误 (Error)"
        foreach ($issue in $errors) {
            $reportLines += "- [$($issue.Skill)] $($issue.Desc)"
        }
        $reportLines += ""
    }
    if ($warnings.Count -gt 0) {
        $reportLines += "## 警告 (Warning)"
        foreach ($issue in $warnings) {
            $reportLines += "- [$($issue.Skill)] $($issue.Desc)"
        }
        $reportLines += ""
    }

    $reportContent = $reportLines -join "`n"
    Set-Content -LiteralPath $AuditLog -Value $reportContent -Encoding UTF8
    Write-Host "审计报告已保存至: $AuditLog"
    Write-Host $reportContent
}

# Main
$skills = Get-AllSkills
if ($TargetSkill -ne "") {
    $skills = $skills | Where-Object { $_.Name -eq $TargetSkill }
    if ($skills.Count -eq 0) {
        Write-Error "未找到名为 $TargetSkill 的 Skill"
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
        $allIssues += @{ Skill = $skillName; Severity = "Blocker"; Desc = "SKILL.md 文件不存在" }
        continue
    }

    # Check YAML frontmatter
    $yamlOk, $yamlErr = Check-YamlFrontmatter -FilePath $skillFile
    if (-not $yamlOk) {
        $allIssues += @{ Skill = $skillName; Severity = "Error"; Desc = $yamlErr }
    }

    # Check code blocks
    if (-not (Check-CodeBlocks -FilePath $skillFile)) {
        $allIssues += @{ Skill = $skillName; Severity = "Error"; Desc = "代码块未正确闭合" }
    }

    if ($Mode -eq "deep") {
        if (-not (Check-LineCount -FilePath $skillFile)) {
            $allIssues += @{ Skill = $skillName; Severity = "Warning"; Desc = "正文少于 50 行，内容薄弱" }
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