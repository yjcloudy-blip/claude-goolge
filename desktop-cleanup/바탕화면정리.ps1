# 바탕화면 정리 스크립트 (Windows PowerShell 5.1 / PowerShell 7)
#
# 사용법: 파일을 마우스 오른쪽 버튼으로 클릭 → "PowerShell에서 실행"
#   1. 어떤 파일이 어느 폴더로 갈지 먼저 보여줍니다 (아직 아무것도 옮기지 않음)
#   2. Y 를 입력하면 실제로 옮깁니다
#
# 건드리지 않는 것: 폴더, 바로가기(.lnk/.url), 숨김·시스템 파일, 이 스크립트 자신
# 같은 이름의 파일이 이미 있으면 덮어쓰지 않고 "이름 (2).확장자" 로 옮깁니다.

$ErrorActionPreference = 'Stop'

# 분류 기준: 폴더 이름 → 확장자 목록
$categories = [ordered]@{
    '이미지'   = 'jpg','jpeg','png','gif','bmp','webp','heic','heif','tif','tiff','svg','ico','raw','psd','ai'
    '문서'     = 'pdf','doc','docx','hwp','hwpx','xls','xlsx','csv','ppt','pptx','txt','rtf','md','odt','ods','odp'
    '압축파일' = 'zip','rar','7z','alz','egg','tar','gz','bz2','xz','iso'
    '설치파일' = 'exe','msi','msix','appx','bat','cmd'
    '영상'     = 'mp4','mov','avi','mkv','wmv','flv','webm','m4v'
    '음악'     = 'mp3','wav','flac','aac','m4a','ogg','wma'
}
$otherFolder = '기타'
$skipExtensions = 'lnk','url','ini'

# OneDrive로 옮겨진 바탕화면도 올바르게 찾습니다
$desktop = [Environment]::GetFolderPath('Desktop')
$self = $MyInvocation.MyCommand.Path

$extToFolder = @{}
foreach ($folder in $categories.Keys) {
    foreach ($ext in $categories[$folder]) { $extToFolder[$ext] = $folder }
}

function Get-UniquePath([string]$dir, [string]$name) {
    $target = Join-Path $dir $name
    if (-not (Test-Path -LiteralPath $target)) { return $target }
    $base = [IO.Path]::GetFileNameWithoutExtension($name)
    $ext = [IO.Path]::GetExtension($name)
    $i = 2
    do {
        $target = Join-Path $dir ("{0} ({1}){2}" -f $base, $i, $ext)
        $i++
    } while (Test-Path -LiteralPath $target)
    return $target
}

$files = Get-ChildItem -LiteralPath $desktop -File -Force | Where-Object {
    $ext = $_.Extension.TrimStart('.').ToLower()
    -not ($_.Attributes -band [IO.FileAttributes]::Hidden) -and
    -not ($_.Attributes -band [IO.FileAttributes]::System) -and
    ($skipExtensions -notcontains $ext) -and
    ($_.FullName -ne $self)
}

Write-Host ""
Write-Host "바탕화면: $desktop" -ForegroundColor Cyan

if (-not $files) {
    Write-Host "정리할 파일이 없습니다. 이미 깔끔하네요!" -ForegroundColor Green
    Read-Host "`n엔터를 누르면 종료합니다"
    return
}

$plan = foreach ($f in $files) {
    $ext = $f.Extension.TrimStart('.').ToLower()
    $folder = if ($extToFolder.ContainsKey($ext)) { $extToFolder[$ext] } else { $otherFolder }
    [pscustomobject]@{ File = $f; Folder = $folder }
}

Write-Host "`n[미리보기] 아래처럼 옮길 예정입니다. 아직 아무것도 옮기지 않았습니다.`n" -ForegroundColor Yellow
foreach ($group in $plan | Group-Object Folder | Sort-Object Name) {
    Write-Host ("  {0} ({1}개)" -f $group.Name, $group.Count) -ForegroundColor Green
    foreach ($item in $group.Group) { Write-Host ("      " + $item.File.Name) }
}
Write-Host ("`n총 {0}개 파일" -f $plan.Count)

$answer = Read-Host "`n진행할까요? (Y/N)"
if ($answer -notmatch '^[Yy]') {
    Write-Host "취소했습니다. 아무 파일도 옮기지 않았습니다."
    Read-Host "`n엔터를 누르면 종료합니다"
    return
}

$moved = 0
$failed = 0
foreach ($item in $plan) {
    $dir = Join-Path $desktop $item.Folder
    try {
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        $dest = Get-UniquePath $dir $item.File.Name
        Move-Item -LiteralPath $item.File.FullName -Destination $dest
        $moved++
    } catch {
        # 다른 프로그램에서 열려 있는 파일 등은 건너뜁니다
        Write-Host ("  건너뜀: {0} ({1})" -f $item.File.Name, $_.Exception.Message) -ForegroundColor Red
        $failed++
    }
}

Write-Host ("`n완료! {0}개 옮김" -f $moved) -ForegroundColor Green
if ($failed) { Write-Host ("{0}개는 사용 중이라 옮기지 못했습니다. 해당 프로그램을 닫고 다시 실행해 보세요." -f $failed) -ForegroundColor Yellow }
Read-Host "`n엔터를 누르면 종료합니다"
