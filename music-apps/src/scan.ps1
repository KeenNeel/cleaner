# 音楽生成アプリ・関連ソフトを探し、デスクトップに「音楽アプリ一覧.html」を作る。
# ファイルやレジストリを読むだけで、何も変更・削除しない。Windows PowerShell 5.1 以降で動く。
#
# このファイルは build.py が catalog.json と report.html を埋め込んで .bat にまとめる。

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$CatalogJson = @'
__CATALOG_JSON__
'@

$Template = @'
__HTML_TEMPLATE__
'@

$Catalog = $CatalogJson | ConvertFrom-Json
$RxOpt = [Text.RegularExpressions.RegexOptions]::IgnoreCase
foreach ($e in $Catalog.entries) {
    $rx = @($e.match | ForEach-Object { New-Object Text.RegularExpressions.Regex($_, $RxOpt) })
    $e | Add-Member -NotePropertyName rx -NotePropertyValue $rx
}
$GenericRx = @($Catalog.generic | ForEach-Object { New-Object Text.RegularExpressions.Regex($_, $RxOpt) })
$GenericExRx = @($Catalog.genericExclude | ForEach-Object { New-Object Text.RegularExpressions.Regex($_, $RxOpt) })
$OtherCategory = $Catalog.categories[$Catalog.categories.Count - 1]
$PluginCategory = '音源・プラグイン・管理ツール'
# フォルダ名から音楽関連ツールを推定するための語
$FolderKeywordRx = @()
foreach ($p in $Catalog.folderKeywords.PSObject.Properties) {
    $FolderKeywordRx += [pscustomobject]@{ rx = (New-Object Text.RegularExpressions.Regex($p.Name, $RxOpt)); purpose = [string]$p.Value }
}

# 起動ファイルとして選ばないもの
$ExeSkip = New-Object Text.RegularExpressions.Regex(
    '(unins|uninstall|setup|install|update|crash|report|helper|service|vc_?redist|dotnet|python|pythonw|conhost|elevate|register|activation|repair|diag|bugsplat|cefsharp|squirrel|7z|ffmpeg|ffprobe)', $RxOpt)
# 一覧に載せないショートカット
$ShortcutSkip = New-Object Text.RegularExpressions.Regex(
    '(unins|uninstall|アンインストール|削除|readme|manual|マニュアル|help|ヘルプ|website|web site|homepage|license|ライセンス|changelog|release notes|documentation|ドキュメント)', $RxOpt)
$SkipDirs = @('windows', '$recycle.bin', 'system volume information', 'recovery', 'perflogs', 'msocache',
    '$windows.~bt', '$windows.~ws', '$winreagent', 'config.msi', 'programdata', 'users', 'program files',
    'program files (x86)', 'node_modules', '.git', '__pycache__', 'site-packages', 'appdata', '.cleaner_quarantine')
# フォルダ探索で中に入らないもの (Python の仮想環境・モデル置き場など)
$FolderSkipDirs = @('venv', 'env', 'lib', 'libs', 'models', 'checkpoints', 'output', 'outputs', 'cache', 'dist',
    'build', 'temp', 'tmp', 'node_modules', 'site-packages', 'scripts', 'include', 'share')
# アプリのフォルダらしいと判断する目印
$AppMarkers = @('requirements.txt', 'pyproject.toml', 'package.json', 'app.py', 'main.py', 'webui.py', 'launch.py',
    'docker-compose.yml', 'docker-compose.yaml', 'setup.py', 'environment.yml', 'pinokio.js')
$LaunchSkipDirs = @('models', 'venv', 'env', 'runtime', 'python_embeded', 'lib', 'libs')
$LaunchExts = @('.exe', '.bat', '.cmd', '.py')
$PluginExts = @{ '.vst3' = 'VST3'; '.dll' = 'VST2'; '.clap' = 'CLAP'; '.aaxplugin' = 'AAX' }

# ---------------------------------------------------------------------------
# 共通

function Write-Step([string]$msg) { Write-Host $msg }

function Get-Normalized([string]$s) {
    if (-not $s) { return '' }
    $s = [regex]::Replace($s.Trim(), '\.(lnk|url|exe|bat)$', '', 'IgnoreCase')
    return ($s -replace '_+', ' ').ToLowerInvariant()
}

function Find-CatalogEntry([string[]]$Names) {
    $texts = @($Names | Where-Object { $_ } | ForEach-Object { Get-Normalized $_ })
    foreach ($e in $Catalog.entries) {
        foreach ($t in $texts) {
            foreach ($r in $e.rx) {
                if ($r.IsMatch($t)) { return $e }
            }
        }
    }
    return $null
}

function Test-Musical([string]$Name) {
    $t = Get-Normalized $Name
    foreach ($r in $GenericExRx) { if ($r.IsMatch($t)) { return $false } }
    foreach ($r in $GenericRx) { if ($r.IsMatch($t)) { return $true } }
    return $false
}

function Test-Reparse($Attributes) { return (([int]$Attributes) -band 0x400) -ne 0 }

function Expand-PathText([string]$p) {
    if (-not $p) { return $null }
    $p = [Environment]::ExpandEnvironmentVariables($p.Trim().Trim('"'))
    if (-not $p) { return $null }
    return $p
}

function Test-Exists([string]$p, [switch]$Folder) {
    if (-not $p) { return $false }
    try {
        if ($Folder) { return [IO.Directory]::Exists($p) }
        return [IO.File]::Exists($p) -or [IO.Directory]::Exists($p)
    } catch { return $false }
}

function Get-Parent([string]$p) {
    try { return [IO.Path]::GetDirectoryName($p) } catch { return $null }
}

function Get-Leaf([string]$p) {
    try { return [IO.Path]::GetFileName($p.TrimEnd('\')) } catch { return $p }
}

function Get-Ext([string]$p) {
    try { return [IO.Path]::GetExtension($p).ToLowerInvariant() } catch { return '' }
}

function Get-Stem([string]$p) {
    try { return [IO.Path]::GetFileNameWithoutExtension($p) } catch { return $p }
}

function Get-UniquePaths($Paths) {
    $seen = @{}
    $out = New-Object System.Collections.ArrayList
    foreach ($p in $Paths) {
        if (-not $p) { continue }
        $k = $p.TrimEnd('\').ToLowerInvariant()
        if ($seen.ContainsKey($k)) { continue }
        $seen[$k] = $true
        if (Test-Exists $p -Folder) { [void]$out.Add($p) }
    }
    return , $out.ToArray()
}

function New-Source($Kind, $Name) {
    return [pscustomobject]@{
        kind = $Kind; name = $Name; location = $null; target = $null; shortcut = $null; url = $null
        size = $null; publisher = ''; version = ''; purpose = $null
    }
}

# JSON に変換する。Windows PowerShell 5.1 の ConvertTo-Json は配列を {"value":[...],"Count":n} に
# してしまうことや、深さ・長さの制限で失敗することがあるため使わない。
function ConvertTo-JsonText($Value) {
    $sb = New-Object Text.StringBuilder
    Add-JsonValue $sb $Value
    return $sb.ToString()
}

function Add-JsonString([Text.StringBuilder]$Sb, [string]$Text) {
    $e = $Text.Replace('\', '\\').Replace('"', '\"')
    # 制御文字と < > & は \uXXXX にする (HTML の <script> 内に安全に埋め込むため)
    $e = [regex]::Replace($e, '[\x00-\x1f<>&\u2028\u2029]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
    [void]$Sb.Append('"').Append($e).Append('"')
}

function Add-JsonValue([Text.StringBuilder]$Sb, $Value) {
    if ($null -eq $Value) { [void]$Sb.Append('null'); return }
    $base = $Value
    if ($Value -is [Management.Automation.PSObject]) { $base = $Value.PSObject.BaseObject }
    if ($base -is [string] -or $base -is [char]) { Add-JsonString $Sb ([string]$base); return }
    if ($base -is [bool]) { if ($base) { [void]$Sb.Append('true') } else { [void]$Sb.Append('false') }; return }
    if ($base -is [int] -or $base -is [long] -or $base -is [double] -or $base -is [decimal] -or $base -is [single] -or
        $base -is [int16] -or $base -is [byte] -or $base -is [uint32] -or $base -is [uint64]) {
        $n = [Convert]::ToString($base, [Globalization.CultureInfo]::InvariantCulture)
        if ($n -match '^(NaN|-?Infinity|∞|-∞)$') { $n = 'null' }
        [void]$Sb.Append($n)
        return
    }
    if ($base -is [Management.Automation.PSCustomObject]) {
        [void]$Sb.Append('{')
        $first = $true
        foreach ($prop in $Value.PSObject.Properties) {
            if (-not $first) { [void]$Sb.Append(',') }
            $first = $false
            Add-JsonString $Sb $prop.Name
            [void]$Sb.Append(':')
            Add-JsonValue $Sb $prop.Value
        }
        [void]$Sb.Append('}')
        return
    }
    if ($base -is [Collections.IDictionary]) {
        [void]$Sb.Append('{')
        $first = $true
        foreach ($k in $base.Keys) {
            if (-not $first) { [void]$Sb.Append(',') }
            $first = $false
            Add-JsonString $Sb ([string]$k)
            [void]$Sb.Append(':')
            Add-JsonValue $Sb $base[$k]
        }
        [void]$Sb.Append('}')
        return
    }
    if ($base -is [Collections.IEnumerable]) {
        [void]$Sb.Append('[')
        $first = $true
        foreach ($item in $base) {
            if (-not $first) { [void]$Sb.Append(',') }
            $first = $false
            Add-JsonValue $Sb $item
        }
        [void]$Sb.Append(']')
        return
    }
    Add-JsonString $Sb ([string]$base)
}

# ---------------------------------------------------------------------------
# 調べる場所

$Desktops = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:USERPROFILE 'Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory'))
foreach ($v in @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial)) {
    if ($v) { $Desktops += @((Join-Path $v 'Desktop'), (Join-Path $v 'デスクトップ')) }
}
$Desktops = Get-UniquePaths $Desktops
$StartMenus = Get-UniquePaths @([Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('CommonPrograms'))
$ProgramFiles = Get-UniquePaths @($env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)})
$ProgramDirs = Get-UniquePaths (@($ProgramFiles) + @((Join-Path $env:LOCALAPPDATA 'Programs')))
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive + '\' } else { 'C:\' }
$ShallowDirs = Get-UniquePaths @($SystemDrive, $env:USERPROFILE, [Environment]::GetFolderPath('MyDocuments'),
    (Join-Path $env:USERPROFILE 'Downloads'))
$PluginDirs = @()
foreach ($b in $ProgramFiles) {
    $PluginDirs += @("$b\Common Files\VST3", "$b\Common Files\VST2", "$b\Common Files\CLAP",
        "$b\Common Files\Avid\Audio\Plug-Ins", "$b\VSTPlugins", "$b\Steinberg\VSTPlugins", "$b\Vstplugins",
        "$b\Image-Line\Shared\Plugins")
}
$PluginDirs += @("$env:LOCALAPPDATA\Programs\Common\VST3", "$env:LOCALAPPDATA\Programs\Common\CLAP")
$PluginDirs = Get-UniquePaths $PluginDirs

# インストール先として扱わない場所 (ドライブ直下やデスクトップそのもの)
$NotLocation = @{}
foreach ($p in @($Desktops) + @($StartMenus) + @($ProgramDirs) + @($ShallowDirs)) {
    $NotLocation[$p.TrimEnd('\').ToLowerInvariant()] = $true
}

$Sources = New-Object System.Collections.ArrayList
$LinkFiles = New-Object System.Collections.ArrayList
$Errors = New-Object System.Collections.ArrayList

# ---------------------------------------------------------------------------
# 1. アンインストール情報 (レジストリ)

Write-Step 'インストール情報 (レジストリ) を確認しています…'
$seenReg = @{}
foreach ($rp in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
    foreach ($item in @(Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue)) {
        $name = [string]$item.DisplayName
        if (-not $name.Trim() -or $item.SystemComponent -eq 1 -or $item.ParentKeyName) { continue }
        $key = $name.ToLowerInvariant() + '|' + [string]$item.DisplayVersion
        if ($seenReg.ContainsKey($key)) { continue }
        $seenReg[$key] = $true
        $s = New-Source 'registry' $name.Trim()
        $s.location = Expand-PathText ([string]$item.InstallLocation)
        $icon = Expand-PathText (([string]$item.DisplayIcon).Split(',')[0])
        if ($icon -and $icon.ToLowerInvariant().EndsWith('.exe')) { $s.target = $icon }
        if ($item.EstimatedSize -and [int64]$item.EstimatedSize -gt 0) { $s.size = [int64]$item.EstimatedSize * 1024 }
        $s.publisher = [string]$item.Publisher
        $s.version = [string]$item.DisplayVersion
        $u = [string]$item.URLInfoAbout
        if (-not $u) { $u = [string]$item.HelpLink }
        if ($u) { $s.url = $u }
        [void]$Sources.Add($s)
    }
}

# ---------------------------------------------------------------------------
# 2. ショートカット (デスクトップ・スタートメニュー)

Write-Step 'デスクトップとスタートメニューのショートカットを確認しています…'
$Shell = $null
try { $Shell = New-Object -ComObject WScript.Shell } catch { [void]$Errors.Add("ショートカットを読めませんでした: $_") }

function Add-Shortcuts([string]$Dir, [switch]$Recurse) {
    $files = @(Get-ChildItem -LiteralPath $Dir -File -Force -Recurse:$Recurse -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
        $ext = $f.Extension.ToLowerInvariant()
        if ($ext -eq '.lnk' -and $Shell) {
            $s = New-Source 'shortcut' $f.BaseName
            $s.shortcut = $f.FullName
            $lnkArgs = ''
            try {
                $lnk = $Shell.CreateShortcut($f.FullName)
                $s.target = Expand-PathText $lnk.TargetPath
                $s.location = Expand-PathText $lnk.WorkingDirectory
                $lnkArgs = [string]$lnk.Arguments
            } catch { }
            $m = [regex]::Match($lnkArgs, 'https?://[^\s"'']+')
            if ($m.Success -and $s.target -and (Get-Leaf $s.target) -match '(?i)(chrome|msedge|firefox|brave|opera|vivaldi|chrome_proxy|msedge_proxy)\.exe$') {
                [void]$LinkFiles.Add([pscustomobject]@{ path = $f.FullName; url = $m.Value; name = $f.BaseName; from = 'app' })
                continue
            }
            [void]$Sources.Add($s)
        } elseif ($ext -eq '.url') {
            $url = $null
            try {
                $m = [regex]::Match([IO.File]::ReadAllText($f.FullName), '(?im)^\s*URL\s*=\s*(\S+)')
                if ($m.Success) { $url = $m.Groups[1].Value }
            } catch { }
            if (-not $url) { continue }
            if (-not $url.ToLowerInvariant().StartsWith('file:')) { continue }  # Web のリンクは 5. で調べる
            $s = New-Source 'shortcut' $f.BaseName
            try { $s.target = ([Uri]$url).LocalPath } catch { }
            $s.shortcut = $f.FullName
            [void]$Sources.Add($s)
        } elseif ($ext -eq '.exe' -or $ext -eq '.bat' -or $ext -eq '.cmd') {
            $s = New-Source 'shortcut' $f.BaseName
            $s.target = $f.FullName
            $s.shortcut = $f.FullName
            $s.location = $f.DirectoryName
            [void]$Sources.Add($s)
        }
    }
}
foreach ($d in $Desktops) { Add-Shortcuts $d }
foreach ($d in $StartMenus) { Add-Shortcuts $d -Recurse }

# ---------------------------------------------------------------------------
# 3. フォルダ (Program Files・C:\ 直下・ユーザーフォルダ・デスクトップ)

Write-Step 'Program Files と C ドライブのフォルダを確認しています…'
function Test-AppFolder([IO.DirectoryInfo]$Dir) {
    $files = @()
    try { $files = $Dir.GetFiles() } catch { return $false }
    foreach ($f in $files) {
        $low = $f.Name.ToLowerInvariant()
        if ($AppMarkers -contains $low) { return $true }
        $ext = $f.Extension.ToLowerInvariant()
        if ($ext -eq '.bat' -or $ext -eq '.cmd' -or ($ext -eq '.exe' -and -not $ExeSkip.IsMatch($low))) { return $true }
    }
    return $false
}

function Get-FolderPurpose([string]$Name) {
    $t = Get-Normalized $Name
    foreach ($r in $GenericExRx) { if ($r.IsMatch($t)) { return $null } }
    foreach ($k in $FolderKeywordRx) { if ($k.rx.IsMatch($t)) { return $k.purpose } }
    return $null
}

function Add-Folders([string]$Dir, [int]$Level, [int]$Depth, [bool]$Generic) {
    $children = @()
    try { $children = (New-Object IO.DirectoryInfo $Dir).GetDirectories() } catch { return }
    foreach ($c in $children) {
        $low = $c.Name.ToLowerInvariant()
        if ($SkipDirs -contains $low -or $FolderSkipDirs -contains $low -or $low.StartsWith('.') -or $low.StartsWith('$')) { continue }
        if (Test-Reparse $c.Attributes) { continue }
        $purpose = $null
        if (Find-CatalogEntry @($c.Name)) {
            $s = New-Source 'folder' $c.Name
            $s.location = $c.FullName
            [void]$Sources.Add($s)
        } elseif ($Generic -and ($purpose = Get-FolderPurpose $c.Name) -and (Test-AppFolder $c)) {
            $s = New-Source 'folder' $c.Name
            $s.location = $c.FullName
            $s.purpose = $purpose
            [void]$Sources.Add($s)
        } elseif ($Level -lt $Depth) {
            Add-Folders $c.FullName ($Level + 1) $Depth $Generic
        }
    }
}
foreach ($d in $ProgramDirs) { Add-Folders $d 1 2 $false }
foreach ($d in @($ShallowDirs) + @($Desktops)) { Add-Folders $d 1 3 $true }

# ---------------------------------------------------------------------------
# 容量・起動ファイル

$SizeCache = @{}
function Get-Size([string]$Path) {
    $k = $Path.TrimEnd('\').ToLowerInvariant()
    if ($SizeCache.ContainsKey($k)) { return $SizeCache[$k] }
    $total = [int64]0
    if ([IO.File]::Exists($Path)) {
        try { $total = (New-Object IO.FileInfo $Path).Length } catch { }
    } else {
        $stack = New-Object System.Collections.Stack
        $stack.Push($Path)
        while ($stack.Count -gt 0) {
            $d = $stack.Pop()
            $items = @()
            try { $items = (New-Object IO.DirectoryInfo $d).GetFileSystemInfos() } catch { continue }
            foreach ($i in $items) {
                if (Test-Reparse $i.Attributes) { continue }
                if ($i -is [IO.DirectoryInfo]) { $stack.Push($i.FullName) } else { $total += $i.Length }
            }
        }
    }
    $SizeCache[$k] = $total
    return $total
}

function Find-LaunchFile([string]$Folder, $Exes) {
    $script:LfWanted = @{}
    $n = 0
    foreach ($x in @($Exes)) {
        if ($x -and -not $script:LfWanted.ContainsKey($x)) { $script:LfWanted[$x] = $n }
        $n++
    }
    $script:LfBest = $null
    $script:LfFallback = New-Object System.Collections.ArrayList
    Find-LaunchWalk $Folder 1
    if ($script:LfBest) { return $script:LfBest.path }
    if ($script:LfFallback.Count -gt 0) {
        $f = $script:LfFallback | Sort-Object -Property @{ Expression = 'level'; Ascending = $true },
            @{ Expression = 'size'; Descending = $true } | Select-Object -First 1
        return $f.path
    }
    return $null
}

function Find-LaunchWalk([string]$Dir, [int]$Level) {
    $items = @()
    try { $items = (New-Object IO.DirectoryInfo $Dir).GetFileSystemInfos() } catch { return }
    foreach ($i in $items) {
        $low = $i.Name.ToLowerInvariant()
        if ($i -is [IO.DirectoryInfo]) {
            if (Test-Reparse $i.Attributes) { continue }
            if ($Level -lt 3 -and -not ($SkipDirs -contains $low) -and -not ($LaunchSkipDirs -contains $low) -and
                -not $low.StartsWith('.') -and -not $low.StartsWith('_')) {
                Find-LaunchWalk $i.FullName ($Level + 1)
            }
            continue
        }
        if ($script:LfWanted.ContainsKey($low)) {
            $rank = $script:LfWanted[$low]
            $b = $script:LfBest
            if (-not $b -or $rank -lt $b.rank -or ($rank -eq $b.rank -and $Level -lt $b.level)) {
                $script:LfBest = [pscustomobject]@{ rank = $rank; level = $Level; path = $i.FullName }
            }
        } elseif ($low.EndsWith('.exe') -and -not $ExeSkip.IsMatch($low) -and $Level -le 2) {
            [void]$script:LfFallback.Add([pscustomobject]@{ level = $Level; size = $i.Length; path = $i.FullName })
        }
    }
}

function Test-UsableTarget([string]$p) {
    if (-not (Test-Exists $p)) { return $false }
    if ($p.ToLowerInvariant().Contains('\windows\installer')) { return $false }
    return -not $ExeSkip.IsMatch((Get-Leaf $p))
}

function Test-DesktopLike([string]$p) {
    return @('desktop', 'デスクトップ', 'downloads', 'ダウンロード') -contains (Get-Leaf $p).ToLowerInvariant()
}


# ---------------------------------------------------------------------------
# 実行環境・フォルダ移動の可否

function Read-TextSafe([string]$Path, [int]$MaxBytes = 262144) {
    try {
        $fi = New-Object IO.FileInfo $Path
        if (-not $fi.Exists -or $fi.Length -gt $MaxBytes) { return '' }
        $bytes = [IO.File]::ReadAllBytes($Path)
        $utf8 = New-Object Text.UTF8Encoding($false, $true)
        try { return $utf8.GetString($bytes) } catch { return [Text.Encoding]::Default.GetString($bytes) }
    } catch { return '' }
}

function Get-GitRemote([string]$Dir) {
    $text = Read-TextSafe (Join-Path $Dir '.git\config')
    $m = [regex]::Match($text, '(?m)^\s*url\s*=\s*(\S+)')
    if (-not $m.Success) { return '' }
    $u = $m.Groups[1].Value
    if ($u -match '^git@([^:]+):(.+)$') { $u = 'https://' + $Matches[1] + '/' + $Matches[2] }
    if ($u -notmatch '^https?://') { return '' }
    return ($u -replace '\.git$', '')
}

function Get-ReadmeSummary([string]$Dir) {
    foreach ($n in @('README_ja.md', 'README.ja.md', 'README-ja.md', 'README.md', 'readme.md', 'README.txt', 'readme.txt')) {
        $text = Read-TextSafe (Join-Path $Dir $n)
        if (-not $text) { continue }
        $inCode = $false
        foreach ($line in ($text -split "`r?`n")) {
            $t = $line.Trim()
            if ($t.StartsWith('```')) { $inCode = -not $inCode; continue }
            if ($inCode -or -not $t -or $t.StartsWith('#') -or $t.StartsWith('<') -or $t.StartsWith('![') -or
                $t.StartsWith('[!') -or $t.StartsWith('|') -or $t.StartsWith('---') -or $t.StartsWith('[![')) { continue }
            $t = [regex]::Replace($t, '!\[[^\]]*\]\([^)]*\)', '')
            $t = [regex]::Replace($t, '\[([^\]]*)\]\([^)]*\)', '$1')
            $t = $t.Replace('**', '').Replace('`', '').Trim()
            if ($t.Length -lt 8) { continue }
            if ($t.Length -gt 180) { $t = $t.Substring(0, 180) + '…' }
            return $t
        }
    }
    return ''
}


function Clean-MarkdownLine([string]$t) {
    $t = [regex]::Replace($t, '!\[[^\]]*\]\([^)]*\)', '')
    $t = [regex]::Replace($t, '\[([^\]]*)\]\([^)]*\)', '$1')
    $t = [regex]::Replace($t, '<[^>]+>', '')
    $t = $t.Replace('**', '').Replace('__', '').Replace('`', '').Trim()
    if ($t.Length -gt 200) { $t = $t.Substring(0, 200) + '…' }
    return $t
}

# フォルダ内の README・package.json・pyproject.toml・起動スクリプトから、概要・機能・使い方を読み取る
function Get-LocalProjectInfo([string]$Dir) {
    $info = [pscustomobject]@{ overview = ''; features = @(); usage = @(); urls = @(); packageName = '' }
    $readme = ''
    foreach ($n in @('README_ja.md', 'README.ja.md', 'README-ja.md', 'README.md', 'readme.md', 'Readme.md', 'README.txt', 'readme.txt', 'README')) {
        $readme = Read-TextSafe (Join-Path $Dir $n) 1048576
        if ($readme) { break }
    }
    $features = New-Object System.Collections.ArrayList
    $usage = New-Object System.Collections.ArrayList
    if ($readme) {
        $info.overview = Get-ReadmeSummary $Dir
        $section = ''
        $inCode = $false
        foreach ($line in ($readme -split "`r?`n")) {
            $t = $line.Trim()
            if ($t.StartsWith('```')) { $inCode = -not $inCode; continue }
            if (-not $inCode -and $t -match '^#{1,6}\s*(.+)$') {
                $h = $Matches[1].ToLowerInvariant()
                if ($h -match '(feature|機能|特徴|what it does|highlight|できること|overview|概要)') { $section = 'f' }
                elseif ($h -match '(usage|使い方|使用方法|getting started|quick ?start|how to|run|起動|実行|install|インストール|setup|セットアップ|導入|docker)') { $section = 'u' }
                else { $section = '' }
                continue
            }
            if (-not $section -or -not $t) { continue }
            if ($inCode) {
                if ($section -eq 'u' -and $usage.Count -lt 12 -and -not $t.StartsWith('#')) { [void]$usage.Add('コマンド: ' + $t) }
                continue
            }
            $m = [regex]::Match($t, '^([-*+]|\d+[.)])\s+(.+)$')
            if (-not $m.Success) { continue }
            $item = Clean-MarkdownLine $m.Groups[2].Value
            if ($item.Length -lt 2) { continue }
            if ($section -eq 'f' -and $features.Count -lt 12) { [void]$features.Add($item) }
            elseif ($section -eq 'u' -and $usage.Count -lt 12) { [void]$usage.Add($item) }
        }
    }
    # package.json (Node.js)
    $pkgText = Read-TextSafe (Join-Path $Dir 'package.json')
    if ($pkgText) {
        try {
            $pkg = $pkgText | ConvertFrom-Json
            if ($pkg.name) { $info.packageName = [string]$pkg.name }
            if ($pkg.description -and -not $info.overview) { $info.overview = [string]$pkg.description }
            if ($pkg.scripts) {
                foreach ($k in @('dev', 'start', 'serve', 'server', 'build')) {
                    $v = $pkg.scripts.$k
                    if ($v -and $usage.Count -lt 14) { [void]$usage.Add("npm run $k  (実行される内容: $v)") }
                }
                if ($usage.Count -gt 0 -and -not (Test-Exists (Join-Path $Dir 'node_modules') -Folder)) {
                    [void]$usage.Insert(0, '初回のみ: このフォルダで npm install を実行して必要なパッケージを入れる')
                }
            }
        } catch { }
    }
    # pyproject.toml / setup.py (Python)
    $pyText = Read-TextSafe (Join-Path $Dir 'pyproject.toml')
    if ($pyText -and -not $info.overview) {
        $m = [regex]::Match($pyText, '(?m)^\s*description\s*=\s*"([^"]+)"')
        if ($m.Success) { $info.overview = $m.Groups[1].Value }
    }
    if ((Test-Exists (Join-Path $Dir 'requirements.txt')) -and $usage.Count -eq 0) {
        [void]$usage.Add('初回のみ: pip install -r requirements.txt で必要なライブラリを入れる')
    }
    foreach ($py in @('app.py', 'main.py', 'server.py', 'webui.py', 'launch.py', 'run.py')) {
        if ((Test-Exists (Join-Path $Dir $py)) -and $usage.Count -lt 14) { [void]$usage.Add("python $py で起動 (このフォルダで実行)"); break }
    }
    # 待ち受けるポート (ブラウザで開くアドレス)
    $ports = New-Object System.Collections.ArrayList
    $texts = @($pkgText)
    foreach ($f in @(Get-ChildItem -LiteralPath $Dir -File -ErrorAction SilentlyContinue | Where-Object {
                @('.py', '.js', '.ts', '.bat', '.cmd', '.env', '.json', '.yml', '.yaml', '.toml', '.ini') -contains $_.Extension.ToLowerInvariant() -or $_.Name -eq '.env' } |
            Select-Object -First 40)) {
        $texts += Read-TextSafe $f.FullName 131072
    }
    foreach ($t in $texts) {
        if (-not $t) { continue }
        foreach ($m in [regex]::Matches($t, '(?i)(?:--port[= ]+|\bport\s*[=:]\s*["'']?|localhost:|127\.0\.0\.1:|0\.0\.0\.0:)(\d{2,5})\b')) {
            $pn = [int]$m.Groups[1].Value
            if ($pn -ge 80 -and $pn -le 65535 -and -not $ports.Contains($pn)) { [void]$ports.Add($pn) }
        }
    }
    $info.urls = @($ports | Select-Object -First 3 | ForEach-Object { "http://localhost:$_" })
    $info.features = @($features.ToArray())
    $info.usage = @($usage.ToArray())
    return $info
}

function Get-PEArch([string]$Path) {
    try {
        $fs = [IO.File]::OpenRead($Path)
        try { $buf = New-Object byte[] 4096; $n = $fs.Read($buf, 0, 4096) } finally { $fs.Dispose() }
        if ($n -lt 64 -or $buf[0] -ne 0x4D -or $buf[1] -ne 0x5A) { return '' }
        $off = [BitConverter]::ToInt32($buf, 0x3C)
        if ($off -lt 0 -or $off + 6 -gt $n -or $buf[$off] -ne 0x50 -or $buf[$off + 1] -ne 0x45) { return '' }
        $mach = [BitConverter]::ToUInt16($buf, $off + 4)
        if ($mach -eq 0x8664) { return '64bit' }
        if ($mach -eq 0x14C) { return '32bit' }
        if ($mach -eq 0xAA64) { return 'ARM64' }
    } catch { }
    return ''
}

# フォルダ内を浅く調べて、実行環境の目印を集める
function Find-RuntimeMarkers([string]$Dir, [int]$Level, $M) {
    $items = @()
    try { $items = (New-Object IO.DirectoryInfo $Dir).GetFileSystemInfos() } catch { return }
    foreach ($i in $items) {
        $low = $i.Name.ToLowerInvariant()
        if ($i -is [IO.DirectoryInfo]) {
            if (Test-Reparse $i.Attributes) { continue }
            if ($low -eq 'conda-meta') { [void]$M.conda.Add($Dir); continue }
            if ($low -eq 'node_modules') { $M.nodeModules = $true; continue }
            if (@('.git', '__pycache__', 'site-packages', 'models', 'checkpoints', 'output', 'outputs', 'cache') -contains $low) { continue }
            if ($Level -lt 3) { Find-RuntimeMarkers $i.FullName ($Level + 1) $M }
            continue
        }
        switch ($low) {
            'pyvenv.cfg' { [void]$M.venv.Add($Dir) }
            'python.exe' { if ((Get-Leaf $Dir).ToLowerInvariant() -ne 'scripts') { [void]$M.embedded.Add($Dir) } }
            'app.asar' { $M.electron = $true }
            'package.json' { if ($Level -le 2) { $M.node = $true } }
            'dockerfile' { if ($Level -le 2) { $M.docker = $true } }
            'docker-compose.yml' { if ($Level -le 2) { $M.docker = $true } }
            'docker-compose.yaml' { if ($Level -le 2) { $M.docker = $true } }
            'requirements.txt' { if ($Level -le 2) { $M.pyproject = $true } }
            'pyproject.toml' { if ($Level -le 2) { $M.pyproject = $true } }
            'environment.yml' { if ($Level -le 2) { $M.pyproject = $true } }
            default {
                if ($low.EndsWith('.jar') -and $Level -le 2) { $M.java = $true }
                if ($low.EndsWith('.py') -and $Level -eq 1) { $M.pyproject = $true }
                if ($Level -le 2 -and @('.bat', '.cmd', '.ps1') -contains $i.Extension.ToLowerInvariant()) { [void]$M.scripts.Add($i.FullName) }
                if ($Level -le 2 -and @('.json', '.yaml', '.yml', '.ini', '.cfg', '.toml', '.env') -contains $i.Extension.ToLowerInvariant() -and
                    $low -ne 'package.json' -and $low -ne 'package-lock.json' -and $low -ne 'pyvenv.cfg') { [void]$M.configs.Add($i.FullName) }
            }
        }
    }
}

function Get-PythonVersion([string]$EnvDir, [bool]$IsVenv) {
    if ($IsVenv) {
        $cfg = Read-TextSafe (Join-Path $EnvDir 'pyvenv.cfg')
        $m = [regex]::Match($cfg, '(?im)^\s*version(_info)?\s*=\s*(\d+\.\d+(\.\d+)?)')
        if ($m.Success) { return $m.Groups[2].Value }
    }
    try {
        foreach ($f in [IO.Directory]::GetFiles($EnvDir, 'python3*.dll')) {
            $m = [regex]::Match([IO.Path]::GetFileName($f), '^python3(\d+)\.dll$', 'IgnoreCase')
            if ($m.Success) { return '3.' + $m.Groups[1].Value }
        }
    } catch { }
    return ''
}

function Get-GpuInfo($EnvDirs) {
    $notes = @()
    foreach ($d in $EnvDirs) {
        foreach ($sp in @((Join-Path $d 'Lib\site-packages'), (Join-Path (Get-Parent $d) 'Lib\site-packages'))) {
            if (-not (Test-Exists $sp -Folder)) { continue }
            $torchLib = Join-Path $sp 'torch\lib'
            if (Test-Exists $torchLib -Folder) {
                $cuda = @()
                try { $cuda = [IO.Directory]::GetFiles($torchLib, 'torch_cuda*.dll') + [IO.Directory]::GetFiles($torchLib, 'cudnn*.dll') } catch { }
                if ($cuda.Count -gt 0) { $notes += 'NVIDIA GPU (CUDA) を使用' } else { $notes += 'PyTorch CPU 版 (GPU は使わない設定)' }
            }
            if (Test-Exists (Join-Path $sp 'torch_directml') -Folder) { $notes += 'DirectML (AMD / Intel の GPU も可)' }
            if (Test-Exists (Join-Path $sp 'onnxruntime\capi\onnxruntime_providers_cuda.dll')) { $notes += 'ONNX Runtime (CUDA)' }
        }
    }
    return (@($notes | Select-Object -Unique) -join '、')
}

function Get-RuntimeInfo($App, [string]$Location, [string]$Launch, $Kinds, $Shortcuts) {
    $r = [pscustomobject]@{ runtime = ''; gpu = ''; portable = '？'; portableReason = '' }
    $kindsArr = @($Kinds)
    if (@($kindsArr | Where-Object { $_ -ne 'url' }).Count -eq 0) {
        $r.runtime = 'Web ブラウザ (インターネット接続が必要)'
        $r.portable = '－'
        $r.portableReason = 'Web サービスのため、PC 内のフォルダの場所は関係ありません。'
        return $r
    }
    if (-not $Location) {
        if ($Launch -and (Get-Ext $Launch) -eq '.exe') {
            $arch = Get-PEArch $Launch
            $r.runtime = ('Windows アプリ ' + $arch).Trim()
        } elseif ($App.category -eq 'オーディオ設定・ドライバ') {
            $r.runtime = 'Windows ドライバ / 常駐ソフト'
        } else {
            $r.runtime = '不明'
        }
        if ($kindsArr -contains 'registry') {
            $r.portable = '×'
            $r.portableReason = 'インストーラーで導入されたソフトです。場所を変えると起動できなくなるため、移動したい場合はアンインストールしてから入れ直してください。'
        } else {
            $r.portableReason = 'インストール先が分からないため判定できません。'
        }
        return $r
    }

    $M = [pscustomobject]@{
        venv = (New-Object System.Collections.ArrayList); conda = (New-Object System.Collections.ArrayList)
        embedded = (New-Object System.Collections.ArrayList); scripts = (New-Object System.Collections.ArrayList)
        configs = (New-Object System.Collections.ArrayList)
        electron = $false; node = $false; nodeModules = $false; docker = $false; java = $false; pyproject = $false
    }
    Find-RuntimeMarkers $Location 1 $M

    # 実行環境
    $parts = @()
    $envDirs = @()
    foreach ($d in $M.venv) {
        $ver = Get-PythonVersion $d $true
        $rel = $d.Substring([Math]::Min($Location.Length, $d.Length)).TrimStart('\')
        if (-not $rel) { $rel = '(フォルダ自体)' }
        $parts += ('Python ' + $ver + ' (仮想環境 venv: ' + $rel + ')').Replace('Python  ', 'Python ')
        $envDirs += $d
    }
    foreach ($d in $M.conda) { $parts += 'Python (conda 環境)'; $envDirs += $d }
    $emb = @($M.embedded | Where-Object { $M.venv -notcontains $_ -and $M.conda -notcontains $_ })
    if ($emb.Count -gt 0) {
        $ver = Get-PythonVersion $emb[0] $false
        $parts += ('Python ' + $ver + ' (同梱版。PC に Python を入れなくても動く)').Replace('Python  ', 'Python ')
        $envDirs += $emb
    }
    if ($M.pyproject -and $envDirs.Count -eq 0) { $parts += 'Python (PC にインストールした Python を使用)' }
    if ($M.electron) { $parts += 'Electron デスクトップアプリ (実行環境は同梱)' }
    elseif ($M.node) {
        if ($M.nodeModules) { $parts += 'Node.js (PC に Node.js が必要)' } else { $parts += 'Node.js (PC に Node.js が必要・npm install 未実行の可能性)' }
    }
    if ($M.java) { $parts += 'Java (PC に Java が必要)' }
    if ($parts.Count -eq 0) {
        $exe = $Launch
        if (-not $exe -or (Get-Ext $exe) -ne '.exe') { $exe = $null }
        $arch = if ($exe) { Get-PEArch $exe } else { '' }
        if ($exe) { $parts += ('Windows ネイティブアプリ ' + $arch).Trim() }
        elseif ($App.category -eq $PluginCategory) { $parts += 'DAW 用プラグイン / 管理ツール' }
        else { $parts += '不明' }
    }
    if ($M.docker) { $parts += 'Docker でも起動可' }
    $r.runtime = $parts -join ' + '
    $r.gpu = Get-GpuInfo $envDirs

    # フォルダ移動の可否 (○ 移動しても動く / △ 条件付き / × 動かなくなる)
    $level = 0
    $reasons = New-Object System.Collections.ArrayList
    $lowLoc = $Location.ToLowerInvariant()
    if ($kindsArr -contains 'registry') {
        $level = 2
        [void]$reasons.Add('インストーラーで導入されたソフトです (場所がレジストリやスタートメニューに登録されています)。移動したい場合はアンインストールしてから、インストール先を指定して入れ直してください。')
    }
    if ($App.category -eq $PluginCategory -and $level -lt 2) {
        $level = 2
        [void]$reasons.Add('DAW は決まったフォルダからプラグインを読み込むため、移動すると認識されなくなります。')
    }
    if ($lowLoc.Contains('\pinokio\api\')) {
        $level = 2
        [void]$reasons.Add('Pinokio が管理するアプリです。Pinokio の画面から起動する前提のため、移動すると Pinokio から使えなくなります。')
    }
    if ($lowLoc.Contains('\stabilitymatrix\') -or $lowLoc.Contains('\data\packages\')) {
        $level = 2
        [void]$reasons.Add('Stability Matrix が管理するアプリです。移動する場合は Stability Matrix の設定から行ってください。')
    }
    if ($M.venv.Count -gt 0) {
        $level = 2
        [void]$reasons.Add('Python の仮想環境 (venv) は作った時の場所を記録しているため、移動すると起動用の命令 (activate・pip など) が動かなくなります。移動後に venv を作り直せば動きます (例: python -m venv venv → pip install -r requirements.txt)。')
    }
    if ($M.conda.Count -gt 0) {
        $level = 2
        [void]$reasons.Add('conda 環境は場所が固定されています。移動後は環境を作り直してください。')
    }
    $scripts = @($M.scripts)
    if ($Launch -and @('.bat', '.cmd', '.ps1') -contains (Get-Ext $Launch) -and $scripts -notcontains $Launch) { $scripts += $Launch }
    foreach ($f in $scripts) {
        $text = Read-TextSafe $f
        if (-not $text) { continue }
        $name = Get-Leaf $f
        if ($text.ToLowerInvariant().Contains($lowLoc) -or $text.ToLowerInvariant().Contains($lowLoc.Replace('\', '/'))) {
            $level = 2
            [void]$reasons.Add("起動ファイル「$name」に今のフォルダの場所 ($Location) が直接書かれています。移動後はこの部分を書き換える必要があります。")
        } else {
            $m = [regex]::Match($text, '(?i)(?<![\w%])[a-z]:[\\/][^\r\n"''<>|*?]{1,80}')
            if ($m.Success -and $m.Value -notmatch '(?i)^[a-z]:[\\/]windows') {
                if ($level -lt 1) { $level = 1 }
                [void]$reasons.Add("起動ファイル「$name」が別の場所 ($($m.Value.Trim())) を使っています。その場所がそのまま残っていれば、移動しても動きます。")
            }
        }
    }
    foreach ($f in @($M.configs)) {
        $text = Read-TextSafe $f
        if (-not $text) { continue }
        $low = $text.ToLowerInvariant()
        if ($low.Contains($lowLoc) -or $low.Contains($lowLoc.Replace('\', '\\')) -or $low.Contains($lowLoc.Replace('\', '/'))) {
            if ($level -lt 1) { $level = 1 }
            [void]$reasons.Add("設定ファイル「$(Get-Leaf $f)」に今のフォルダの場所が書かれています。移動後はその部分を新しい場所に書き換えてください。")
        }
    }
    if ($level -eq 0) {
        if ($emb.Count -gt 0) { [void]$reasons.Add('Python ごとフォルダ内に入っているため、フォルダごと移動しても動きます。') }
        elseif ($M.pyproject) { [void]$reasons.Add('フォルダごと移動しても動きます (PC にインストールした Python とライブラリを使います)。') }
        elseif ($M.node -or $M.electron) { [void]$reasons.Add('必要なファイルがフォルダ内にそろっているため、フォルダごと移動しても動きます。') }
        else { [void]$reasons.Add('場所に依存する設定は見つかりませんでした。フォルダごと移動しても動く見込みです。') }
    }
    if ($level -lt 2 -and @($Shortcuts).Count -gt 0) { [void]$reasons.Add('デスクトップなどのショートカットは移動後に作り直してください。') }
    $r.portable = @('○', '△', '×')[$level]
    $r.portableReason = ($reasons | Select-Object -Unique) -join ' '
    return $r
}

# ---------------------------------------------------------------------------
# 4. まとめる

$Apps = [ordered]@{}
foreach ($s in $Sources) {
    $names = @($s.name)
    if ($s.target) { $names += Get-Stem $s.target }
    if ($s.location) { $names += Get-Leaf $s.location }
    $entry = Find-CatalogEntry $names
    if (-not $entry -and $s.kind -eq 'url') { continue }
    if ($entry) {
        $key = $entry.id
        if (-not $Apps.Contains($key)) {
            $Apps[$key] = [pscustomobject]@{
                key = $key; name = $entry.name; category = $entry.category; purpose = $entry.purpose
                url = $entry.url; howto = $entry.howto; launchNote = $entry.launch_note; exes = @($entry.exes)
                features = @($entry.features); usage = @($entry.usage)
                sources = (New-Object System.Collections.ArrayList)
            }
        }
    } elseif ($s.kind -eq 'registry' -and (Test-Musical $s.name)) {
        $key = 'other:' + $s.name.ToLowerInvariant()
        if (-not $Apps.Contains($key)) {
            $Apps[$key] = [pscustomobject]@{
                key = $key; name = $s.name; category = $OtherCategory
                purpose = 'カタログ未登録のため自動判定。名前から音楽関連ソフトの可能性があります。'
                url = [string]$s.url; howto = '公式ページのマニュアルを参照してください。'; launchNote = ''; exes = @()
                features = @(); usage = @()
                sources = (New-Object System.Collections.ArrayList)
            }
        }
    } elseif ($s.kind -eq 'folder' -and $s.purpose) {
        $key = 'folder:' + $s.location.ToLowerInvariant()
        if (-not $Apps.Contains($key)) {
            $Apps[$key] = [pscustomobject]@{
                key = $key; name = $s.name; category = $OtherCategory; purpose = $s.purpose
                url = ''; howto = 'フォルダ内の README (説明書) を参照してください。'; launchNote = ''; exes = @('start.bat', 'run.bat', 'webui.bat', 'start.cmd', 'run.cmd')
                features = @(); usage = @()
                sources = (New-Object System.Collections.ArrayList)
            }
        }
    } else {
        continue
    }
    [void]$Apps[$key].sources.Add($s)
}

Write-Step ("{0} 件のアプリが見つかりました。容量と起動ファイルを調べています (数分かかることがあります)…" -f $Apps.Count)
$Result = New-Object System.Collections.ArrayList
foreach ($app in $Apps.Values) {
    Write-Step ('  - ' + $app.name)
    $src = @($app.sources)
    $names = New-Object System.Collections.ArrayList
    $kinds = New-Object System.Collections.ArrayList
    $shortcuts = New-Object System.Collections.ArrayList
    $version = ''; $publisher = ''; $webUrl = $null
    foreach ($s in $src) {
        if (-not $names.Contains($s.name)) { [void]$names.Add($s.name) }
        if (-not $kinds.Contains($s.kind)) { [void]$kinds.Add($s.kind) }
        if ($s.version -and -not $version) { $version = $s.version }
        if ($s.publisher -and -not $publisher) { $publisher = $s.publisher }
        if ($s.kind -eq 'url' -and -not $webUrl) { $webUrl = $s.url }
        if ($s.shortcut -and -not $shortcuts.Contains($s.shortcut) -and -not $ShortcutSkip.IsMatch((Get-Stem $s.shortcut))) {
            [void]$shortcuts.Add($s.shortcut)
        }
    }

    # インストール先: レジストリの InstallLocation > レジストリの DisplayIcon の場所 > 一致したフォルダ
    #                 > ショートカットのリンク先の場所
    $regTargets = @($src | Where-Object { $_.kind -eq 'registry' -and $_.target -and (Test-UsableTarget $_.target) } |
        ForEach-Object { $_.target })
    $scTargets = @($src | Where-Object { $_.kind -eq 'shortcut' -and $_.target -and (Test-UsableTarget $_.target) } |
        ForEach-Object { $_.target })
    $locs = @()
    $locs += @($src | Where-Object { $_.kind -eq 'registry' -and $_.location } | ForEach-Object { $_.location })
    $locs += @($regTargets | ForEach-Object { Get-Parent $_ })
    $locs += @($src | Where-Object { $_.kind -eq 'folder' } | ForEach-Object { $_.location })
    $locs += @($scTargets | ForEach-Object { Get-Parent $_ } | Where-Object { $_ -and -not (Test-DesktopLike $_) })
    $location = $null
    foreach ($l in $locs) {
        if (-not $l) { continue }
        $k = $l.TrimEnd('\').ToLowerInvariant()
        if ($NotLocation.ContainsKey($k) -or $k.Length -le 3) { continue }
        if (Test-Exists $l -Folder) { $location = $l.TrimEnd('\'); break }
    }

    # 起動ファイル: カタログの起動ファイル名 > ショートカットのリンク先 > DisplayIcon > フォルダ内の主な exe
    $launch = $null
    if ($location -and @($app.exes).Count -gt 0) { $launch = Find-LaunchFile $location $app.exes }
    if (-not $launch) {
        $launch = @(@($scTargets) + @($regTargets) | Where-Object { $LaunchExts -contains (Get-Ext $_) }) |
            Select-Object -First 1
    }
    if (-not $launch -and $location) { $launch = Find-LaunchFile $location @() }
    if (-not $launch) {
        $launch = @($src | Where-Object { $_.kind -eq 'url' -and $_.shortcut } | ForEach-Object { $_.shortcut }) |
            Select-Object -First 1
    }

    $launch = @($launch | Where-Object { $_ } | ForEach-Object { [string]$_ }) | Select-Object -First 1

    # 容量
    $size = $null; $sizeNote = ''
    if ($location) { $size = [int64](@(Get-Size $location) | Select-Object -Last 1); $sizeNote = 'フォルダ実測' }
    if (-not $size) {
        $reg = @($src | Where-Object { $_.size } | ForEach-Object { $_.size })
        if ($reg.Count -gt 0) {
            $size = [int64](($reg | Measure-Object -Maximum).Maximum)
            $sizeNote = 'インストール情報の推定値'
        } elseif (@($src | Where-Object { $_.kind -ne 'url' }).Count -eq 0) {
            $size = $null
            $sizeNote = 'Web サービスのため PC の容量は使いません'
        }
    }

    $purpose = $app.purpose
    $url = $app.url
    $features = @($app.features)
    $usage = @($app.usage)
    $localUrls = @()
    $packageName = ''
    if ($location -and ($app.key.StartsWith('folder:') -or $features.Count -eq 0)) {
        $pi = Get-LocalProjectInfo $location
        if ($pi.overview) { $purpose = $purpose + ' README より: ' + $pi.overview }
        if ($features.Count -eq 0) { $features = @($pi.features) }
        if ($usage.Count -eq 0) { $usage = @($pi.usage) }
        $localUrls = @($pi.urls)
        $packageName = $pi.packageName
        if ($localUrls.Count -gt 0 -and $app.key.StartsWith('folder:')) { $usage += ('起動したら、ブラウザで ' + ($localUrls -join ' または ') + ' を開く') }
    }
    if ($location -and -not $url) { $url = Get-GitRemote $location }
    $rt = Get-RuntimeInfo $app $location $launch @($kinds.ToArray()) @($shortcuts.ToArray())

    [void]$Result.Add([pscustomobject]@{
        name = $app.name; category = $app.category; purpose = $purpose; url = $url; howto = $app.howto
        launchNote = $app.launchNote; location = $location; size = $size; sizeNote = $sizeNote
        launchFile = $launch; shortcuts = @($shortcuts.ToArray()); version = $version; publisher = $publisher
        features = @($features); usage = @($usage); localUrls = @($localUrls); packageName = $packageName
        names = @($names.ToArray()); kinds = @($kinds.ToArray()); webUrl = $webUrl
        runtime = $rt.runtime; gpu = $rt.gpu; portable = $rt.portable; portableReason = $rt.portableReason
    })
}

# ---------------------------------------------------------------------------
# 5. インターネットショートカット (.url など): リンク先を調べて音楽系かどうかを判定する

Write-Step 'インターネットショートカットを探しています…'
$WebServices = @($Catalog.webServices)
$WebKeywordRx = @($Catalog.webKeywords | ForEach-Object { New-Object Text.RegularExpressions.Regex($_, $RxOpt) })
$HubKind = 'AI モデル・コード公開サイト'

function Find-UrlFiles([string]$Dir, [int]$Level, [int]$Depth, [string]$From = '') {
    $items = @()
    try { $items = (New-Object IO.DirectoryInfo $Dir).GetFileSystemInfos() } catch { return }
    foreach ($i in $items) {
        if ($i -is [IO.DirectoryInfo]) {
            $low = $i.Name.ToLowerInvariant()
            if ($Level -ge $Depth -or $SkipDirs -contains $low -or $FolderSkipDirs -contains $low -or $low.StartsWith('.') -or
                $low.StartsWith('$') -or (Test-Reparse $i.Attributes)) { continue }
            Find-UrlFiles $i.FullName ($Level + 1) $Depth $From
            continue
        }
        if ($i.Extension.ToLowerInvariant() -ne '.url') { continue }
        $k = $i.FullName.ToLowerInvariant()
        if ($script:SeenUrlFiles.ContainsKey($k)) { continue }
        $script:SeenUrlFiles[$k] = $true
        $text = Read-TextSafe $i.FullName 65536
        $m = [regex]::Match($text, '(?im)^\s*URL\s*=\s*(\S+)')
        if (-not $m.Success) { continue }
        $u = $m.Groups[1].Value
        if ($u -notmatch '^(?i)https?://') { continue }
        [void]$LinkFiles.Add([pscustomobject]@{ path = $i.FullName; url = $u; name = [IO.Path]::GetFileNameWithoutExtension($i.Name); from = $From })
    }
}
$script:SeenUrlFiles = @{}
foreach ($d in @($Desktops)) { Find-UrlFiles $d 1 5 }
foreach ($d in @($ShallowDirs)) { Find-UrlFiles $d 1 4 }
foreach ($d in @($StartMenus)) { Find-UrlFiles $d 1 3 }
$fav = [Environment]::GetFolderPath('Favorites')
if ($fav -and (Test-Exists $fav -Folder)) { Find-UrlFiles $fav 1 4 'favorites' }

function Find-WebService([string]$HostName) {
    foreach ($w in $WebServices) {
        foreach ($d in @($w.domains)) {
            if ($HostName -eq $d -or $HostName.EndsWith('.' + $d)) { return $w }
        }
    }
    return $null
}

function Test-WebMusic([string]$Text) {
    if (-not $Text) { return $false }
    foreach ($r in $WebKeywordRx) { if ($r.IsMatch($Text)) { return $true } }
    return $false
}

# 親フォルダの名前 (music_ai など) が音楽系なら、その名前を返す
function Get-MusicFolderContext([string]$Path) {
    $d = Get-Parent $Path
    $n = 0
    while ($d -and $n -lt 6) {
        $leaf = Get-Leaf $d
        if (-not $leaf -or $NotLocation.ContainsKey($d.TrimEnd('\').ToLowerInvariant())) { break }
        if ((Get-FolderPurpose $leaf) -or (Find-CatalogEntry @($leaf))) { return $leaf }
        $d = Get-Parent $d
        $n++
    }
    return ''
}

try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 -bor 12288 } catch {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch { }
}

# リンク先のページを読み、タイトルと説明文を取り出す
function Get-WebPageInfo([string]$Url) {
    $r = [pscustomobject]@{ title = ''; description = ''; error = '' }
    try {
        $req = [Net.HttpWebRequest]::Create($Url)
        $req.Timeout = 8000
        $req.ReadWriteTimeout = 8000
        $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
        $req.Accept = 'text/html,application/xhtml+xml,*/*;q=0.8'
        $req.Headers.Add('Accept-Language', 'ja,en;q=0.8')
        $req.AutomaticDecompression = [Net.DecompressionMethods]::GZip -bor [Net.DecompressionMethods]::Deflate
        $resp = $req.GetResponse()
        try {
            $ct = [string]$resp.ContentType
            $stream = $resp.GetResponseStream()
            $ms = New-Object IO.MemoryStream
            $buf = New-Object byte[] 65536
            while ($ms.Length -lt 786432) {
                $n = $stream.Read($buf, 0, $buf.Length)
                if ($n -le 0) { break }
                $ms.Write($buf, 0, $n)
            }
            $bytes = $ms.ToArray()
        } finally { $resp.Close() }
        $cs = ''
        $m = [regex]::Match($ct, '(?i)charset=([\w-]+)')
        if ($m.Success) { $cs = $m.Groups[1].Value }
        if (-not $cs) {
            $head = [Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min($bytes.Length, 8192))
            $m = [regex]::Match($head, '(?i)<meta[^>]+charset\s*=\s*["'']?([\w-]+)')
            if ($m.Success) { $cs = $m.Groups[1].Value }
        }
        $enc = [Text.Encoding]::UTF8
        if ($cs) { try { $enc = [Text.Encoding]::GetEncoding($cs) } catch { } }
        $html = $enc.GetString($bytes)
        $title = ''
        foreach ($pat in @('(?is)<meta[^>]+property\s*=\s*["'']og:title["''][^>]*content\s*=\s*"([^"]*)"',
                '(?is)<meta[^>]+content\s*=\s*"([^"]*)"[^>]*property\s*=\s*["'']og:title["'']',
                '(?is)<title[^>]*>(.*?)</title>')) {
            $m = [regex]::Match($html, $pat)
            if ($m.Success -and $m.Groups[1].Value.Trim()) { $title = $m.Groups[1].Value; break }
        }
        $desc = ''
        foreach ($pat in @('(?is)<meta[^>]+(?:name|property)\s*=\s*["''](?:og:)?description["''][^>]*content\s*=\s*"([^"]*)"',
                '(?is)<meta[^>]+content\s*=\s*"([^"]*)"[^>]*(?:name|property)\s*=\s*["''](?:og:)?description["'']')) {
            $m = [regex]::Match($html, $pat)
            if ($m.Success -and $m.Groups[1].Value.Trim()) { $desc = $m.Groups[1].Value; break }
        }
        $r.title = ([Net.WebUtility]::HtmlDecode($title) -replace '\s+', ' ').Trim()
        $r.description = ([Net.WebUtility]::HtmlDecode($desc) -replace '\s+', ' ').Trim()
        if ($r.description.Length -gt 300) { $r.description = $r.description.Substring(0, 300) + '…' }
    } catch {
        $msg = $_.Exception.Message
        if ($_.Exception.InnerException) { $msg = $_.Exception.InnerException.Message }
        $r.error = $msg
    }
    return $r
}

$Links = [ordered]@{}
$NonMusicLinks = New-Object System.Collections.ArrayList
$PageCache = @{}
$total = $LinkFiles.Count
Write-Step ("{0} 件のインターネットショートカットが見つかりました。リンク先を確認しています…" -f $total)
$idx = 0
foreach ($lf in $LinkFiles) {
    $idx++
    $uri = $null
    try { $uri = [Uri]$lf.url } catch { continue }
    $hostName = $uri.Host.ToLowerInvariant()
    if ($hostName.StartsWith('www.')) { $hostName = $hostName.Substring(4) }
    $svc = Find-WebService $hostName
    $isHub = ($svc -and $svc.kind -eq $HubKind)
    $isLocal = @('localhost', '127.0.0.1', '0.0.0.0', '::1') -contains $hostName
    $folderCtx = Get-MusicFolderContext $lf.path
    $urlText = [Uri]::UnescapeDataString($uri.AbsolutePath + ' ' + $uri.Query) + ' ' + $hostName
    $entry = Find-CatalogEntry @($lf.name)
    if (-not $entry -and $hostName -eq 'github.com') {
        foreach ($e in $Catalog.entries) {
            if ($e.url -and $e.url.ToLowerInvariant().StartsWith('https://github.com' + $uri.AbsolutePath.ToLowerInvariant().TrimEnd('/'))) {
                if ($uri.AbsolutePath.Trim('/').Split('/').Count -ge 2) { $entry = $e; break }
            }
        }
    }

    # 既知のサービス以外はリンク先を読んでタイトル・説明を得る (GitHub などはリポジトリの説明が分かる)
    $page = $null
    $wantPage = (-not $isLocal -and (-not $svc -or $isHub) -and ($lf.from -ne 'favorites' -or $folderCtx -or $isHub))
    if ($wantPage) {
        $ck = $lf.url.ToLowerInvariant()
        if (-not $PageCache.ContainsKey($ck) -and $PageCache.Count -ge 150) { $wantPage = $false }
    }
    if ($wantPage) {
        $ck = $lf.url.ToLowerInvariant()
        if (-not $PageCache.ContainsKey($ck)) {
            Write-Step ("  [{0}/{1}] {2}" -f $idx, $total, $lf.url)
            $PageCache[$ck] = Get-WebPageInfo $lf.url
        }
        $page = $PageCache[$ck]
    }
    $pageText = if ($page) { $page.title + ' ' + $page.description } else { '' }

    $reason = ''
    if ($entry) { $reason = "既知のアプリ「$($entry.name)」へのリンク" }
    elseif ($svc -and -not $isHub) { $reason = "既知の音楽系サービス「$($svc.name)」" }
    elseif (Test-WebMusic ($lf.name + ' ' + $urlText)) { $reason = 'ショートカット名・URL に音楽関連の語を含む' }
    elseif (Test-WebMusic $pageText) { $reason = 'リンク先ページのタイトル・説明に音楽関連の語を含む' }
    elseif ($folderCtx) { $reason = "音楽系のフォルダ「$folderCtx」に置かれている" }

    if (-not $reason) {
        [void]$NonMusicLinks.Add([pscustomobject]@{ name = $lf.name; url = $lf.url; path = $lf.path
            title = $(if ($page) { $page.title } else { '' }); error = $(if ($page) { $page.error } else { '' }) })
        continue
    }

    # 同じサービス・同じアプリへのリンクはまとめる
    if ($entry) { $gk = 'app:' + $entry.id }
    elseif ($svc -and -not $isHub) { $gk = 'svc:' + $svc.id }
    else { $gk = 'url:' + $lf.url.ToLowerInvariant().TrimEnd('/') }
    if (-not $Links.Contains($gk)) {
        $g = [pscustomobject]@{
            name = $lf.name; kind = ''; overview = ''; features = @(); usage = @(); officialUrl = ''
            reason = $reason; pageTitle = ''; pageDescription = ''; pageError = ''; host = $hostName
            urls = (New-Object System.Collections.ArrayList); shortcuts = (New-Object System.Collections.ArrayList)
            folders = (New-Object System.Collections.ArrayList); isLocal = $isLocal
        }
        if ($entry) {
            $g.name = $entry.name; $g.kind = $entry.category; $g.overview = $entry.purpose
            $g.features = @($entry.features); $g.usage = @($entry.usage); $g.officialUrl = $entry.url
        } elseif ($svc -and -not $isHub) {
            $g.name = $svc.name; $g.kind = $svc.kind; $g.overview = $svc.overview
            $g.features = @($svc.features); $g.usage = @($svc.usage); $g.officialUrl = 'https://' + @($svc.domains)[0] + '/'
        } else {
            if ($svc) { $g.kind = $svc.kind + ' (' + $svc.name + ')' }
            elseif ($isLocal) { $g.kind = 'この PC で動く Web 画面 (ローカルサーバー)' }
            else { $g.kind = 'Web ページ' }
            if ($page -and $page.title) { $g.name = $page.title }
            $parts = @()
            if ($page -and $page.description) { $parts += $page.description }
            if ($svc) { $parts += $svc.overview }
            if ($isLocal) { $parts += ('この PC 上のアプリ (ポート ' + $uri.Port + ') の画面です。そのアプリを起動している間だけ開けます。') }
            $g.overview = ($parts -join ' ')
            if ($svc) { $g.usage = @($svc.usage) }
            $g.officialUrl = $lf.url
        }
        if ($page) { $g.pageTitle = $page.title; $g.pageDescription = $page.description; $g.pageError = $page.error }
        $Links[$gk] = $g
    }
    $g = $Links[$gk]
    if (-not $g.urls.Contains($lf.url)) { [void]$g.urls.Add($lf.url) }
    [void]$g.shortcuts.Add($lf.path)
    $folder = Get-Parent $lf.path
    if ($folder -and -not $g.folders.Contains($folder)) { [void]$g.folders.Add($folder) }
}
$LinkResult = @($Links.Values | ForEach-Object {
        [pscustomobject]@{
            name = $_.name; kind = $_.kind; overview = $_.overview; features = @($_.features); usage = @($_.usage)
            officialUrl = $_.officialUrl; reason = $_.reason; pageTitle = $_.pageTitle; pageDescription = $_.pageDescription
            pageError = $_.pageError; host = $_.host; urls = @($_.urls.ToArray()); shortcuts = @($_.shortcuts.ToArray())
            folders = @($_.folders.ToArray()); isLocal = $_.isLocal
        }
    })

# ---------------------------------------------------------------------------
# 6. プラグイン

Write-Step 'VST / VST3 / CLAP / AAX プラグインを確認しています…'
$Plugins = New-Object System.Collections.ArrayList
$seenPlugin = @{}
function Add-Plugins([string]$Dir, [int]$Depth) {
    $items = @()
    try { $items = (New-Object IO.DirectoryInfo $Dir).GetFileSystemInfos() } catch { return }
    foreach ($i in $items) {
        $ext = $i.Extension.ToLowerInvariant()
        if ($PluginExts.ContainsKey($ext)) {
            $k = $i.FullName.ToLowerInvariant()
            if ($seenPlugin.ContainsKey($k)) { continue }
            $seenPlugin[$k] = $true
            [void]$Plugins.Add([pscustomobject]@{
                name = [IO.Path]::GetFileNameWithoutExtension($i.Name); format = $PluginExts[$ext]
                path = $i.FullName; folder = (Get-Parent $i.FullName); size = (Get-Size $i.FullName)
            })
        } elseif ($Depth -gt 1 -and $i -is [IO.DirectoryInfo] -and -not (Test-Reparse $i.Attributes)) {
            Add-Plugins $i.FullName ($Depth - 1)
        }
    }
}
foreach ($d in $PluginDirs) { Add-Plugins $d 3 }

# ---------------------------------------------------------------------------
# 7. HTML を書き出す

$Data = [pscustomobject]@{
    scannedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    computer = $env:COMPUTERNAME
    categories = @($Catalog.categories)
    apps = @($Result.ToArray())
    plugins = @($Plugins.ToArray())
    links = @($LinkResult)
    nonMusicLinks = @($NonMusicLinks.ToArray())
    roots = [pscustomobject]@{
        desktops = @($Desktops); startMenus = @($StartMenus); programDirs = @($ProgramDirs)
        shallowDirs = @($ShallowDirs); pluginDirs = @($PluginDirs)
    }
    errors = @($Errors.ToArray())
}
try {
    $json = ConvertTo-JsonText $Data
} catch {
    Write-Host "データの変換でエラーが発生しました: $_" -ForegroundColor Red
    $msg = ConvertTo-JsonText ([string]$_)
    $json = '{"apps":[],"plugins":[],"categories":[],"roots":{},"errors":[' + $msg + ']}'
}
$html = $Template.Replace('__DATA_JSON__', $json)

$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $desktop -or -not (Test-Exists $desktop -Folder)) { $desktop = (Get-Location).Path }
$out = Join-Path $desktop '音楽アプリ一覧.html'
[IO.File]::WriteAllText($out, $html, (New-Object Text.UTF8Encoding($false)))

Write-Host ''
if ($Errors.Count -gt 0) {
    Write-Host '一部でエラーがありました (HTML の最後にも載せています):' -ForegroundColor Yellow
    foreach ($e in $Errors) { Write-Host "  $e" -ForegroundColor Yellow }
}
Write-Host ("{0} 件のアプリ、{1} 件の音楽系リンク、{2} 件のプラグインを見つけました。" -f $Result.Count, @($LinkResult).Count, $Plugins.Count)
Write-Host "HTML を作成しました: $out"
try { Start-Process $out } catch { Write-Host 'ブラウザで開けませんでした。上のファイルをダブルクリックしてください。' }
