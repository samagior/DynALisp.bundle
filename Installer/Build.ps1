# Build.ps1 - build the DynALisp setup: Releases\DynALisp-Setup-<version>.exe
# Copyright (C) 2023  Samuel Martineau, GNU General Public License v3
#
#   powershell -ExecutionPolicy Bypass -File Installer\Build.ps1 [-Iscc <path of ISCC.exe>]
#
# The version is the AppVersion of PackageContents.xml, and CHANGELOG.md must have
# its "## <version>" section (its notes are written to Releases\build\notes.md, the
# notes of the GitHub release). The setup holds the files git knows (committed or new,
# never the ignored ones: User, MyTools...), without the dev files (Installer,
# .github, .vscode, CLAUDE.md, CONVENTIONS.md) and without the Docs (User Guide) and
# DevDocs (Developer docs) folders of each module: the docs open on the website (Resources\DocsPages.txt, the list of its pages,
# is installed), and a git clone has them to edit: Installer\Docs\BuildDocs.py --check
# must find that list up to date. Needs git, Python 3 and Inno Setup 6.
# Works in Windows PowerShell 5.1 and PowerShell 7 (the release workflow runs it).

param([string]$Iscc)

$ErrorActionPreference = 'Stop'
$repo  = Split-Path $PSScriptRoot -Parent
$out   = Join-Path $repo 'Releases'
$build = Join-Path $out 'build'
$stage = Join-Path $build 'bundle'

# Version, and its notes in CHANGELOG.md:
[xml]$pkg = Get-Content -Raw -LiteralPath (Join-Path $repo 'PackageContents.xml')
$version = $pkg.ApplicationPackage.AppVersion
if (-not $version) { throw 'No AppVersion in PackageContents.xml.' }
$notes = @()
$in = $false
foreach ($line in Get-Content -LiteralPath (Join-Path $repo 'CHANGELOG.md') -Encoding UTF8) {
    if ($line -match '^##\s+v?(\S+)') {
        $in = ($Matches[1] -eq $version)
    } elseif ($in) {
        $notes += $line
    }
}
if (-not ($notes -match '\S')) { throw "CHANGELOG.md has no notes for version $version (a '## $version' section)." }

# The list of the pages of the docs website, installed in place of the Docs folders, must
# have every page (BuildDocs.py run and committed), or their Open Docs buttons are greyed out:
$python = @('python', 'py', 'python3') | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Select-Object -First 1
if (-not $python) { throw 'Python 3 not found: it checks the list of the docs pages (Installer\Docs\BuildDocs.py --check).' }
& $python (Join-Path $PSScriptRoot 'Docs\BuildDocs.py') --check
if ($LASTEXITCODE -ne 0) { throw 'The docs are not up to date: run python Installer\Docs\BuildDocs.py, then commit what it changed.' }

# ISCC.exe of Inno Setup 6:
if (-not $Iscc) {
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    $Iscc = @(
        $(if ($cmd) { $cmd.Source })
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe')
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}
if (-not $Iscc) { throw 'Inno Setup 6 not found (https://jrsoftware.org/isinfo.php, or winget install JRSoftware.InnoSetup).' }

# Stage the files:
if (Test-Path -LiteralPath $build) { Remove-Item -LiteralPath $build -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$devOnly = '^(\.github|\.vscode|Installer|Releases)/|^Contents/Modules/[^/]+/(Docs|DevDocs)/|^(\.gitignore|\.gitattributes|CLAUDE\.md|CONVENTIONS\.md)$'
$files = git -C $repo -c core.quotepath=false ls-files --cached --others --exclude-standard
if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed.' }
$count = 0
foreach ($f in ($files | Where-Object { $_ -notmatch $devOnly } | Sort-Object -Unique)) {
    $src = Join-Path $repo $f
    if (Test-Path -LiteralPath $src -PathType Leaf) {
        $dst = Join-Path $stage $f
        New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst
        $count++
    }
}

# The modules shipped: removed by an update before the new files are copied, and told
# from the user's own modules (MyTools...), saved by the uninstall:
$shipped = @(Get-ChildItem -LiteralPath (Join-Path $stage 'Contents\Modules') -Directory | ForEach-Object { $_.Name })
$modules = $shipped | ForEach-Object { 'Type: filesandordirs; Name: "{app}\Contents\Modules\' + $_ + '"' }
Set-Content -LiteralPath (Join-Path $build 'Modules.iss') -Value $modules -Encoding ASCII
Set-Content -LiteralPath (Join-Path $build 'notes.md') -Value ($notes -join "`n").Trim() -Encoding UTF8

Write-Host "DynALisp $version : $count files staged, building the setup..."
& $Iscc /Q "/DAppVersion=$version" "/DStageDir=$stage" "/DBuildDir=$build" "/DShippedModules=$($shipped -join ';')" "/DOutDir=$out" (Join-Path $PSScriptRoot 'DynALisp.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)." }
Write-Host "Built: $(Join-Path $out "DynALisp-Setup-$version.exe")"
