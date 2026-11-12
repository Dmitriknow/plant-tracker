# Кладёт ключ в project\.env так, чтобы его не увидел никто: ни агент, ни экран, ни история команд.
# Запускает человек сам, в отдельном окне PowerShell; агент даёт команду с полным путём:
#   powershell -ExecutionPolicy Bypass -File "C:\путь\к\папке набора\checks\put-key.ps1" OPENAI_API_KEY
# Файл сохранён в UTF-8 с BOM: без него Windows PowerShell 5.1 читает кириллицу как ANSI и не запускает скрипт.
# Ввод скрыт. Строка с этим именем в project\.env заменяется (или добавляется). Печатает только имя и длину.
param([string]$Name)
if ($Name -notmatch '^[A-Za-z0-9_]+$') {
  Write-Output "Укажи имя ключа латиницей, например: powershell -ExecutionPolicy Bypass -File checks\put-key.ps1 OPENAI_API_KEY"
  exit 1
}
# только руками человека: из окна агента вызов повис бы на скрытом вводе
if ([Console]::IsInputRedirected -or -not [Environment]::UserInteractive) {
  Write-Output "Запусти эту команду сам, в окне PowerShell, и вставь ключ туда."
  exit 1
}
Set-Location (Join-Path $PSScriptRoot '..')
New-Item -ItemType Directory -Force -Path project | Out-Null

$secure = Read-Host -AsSecureString "Вставь $Name и нажми Enter (на экране ничего не появится)"
$val = [System.Net.NetworkCredential]::new('', $secure).Password
$val = $val.Trim().Trim('"').Trim("'")
if (-not $val) { Write-Output "Пусто – ничего не записал. Скопируй ключ ещё раз и повтори."; exit 1 }

$envFile = 'project\.env'
$lines = @()
$full = Join-Path (Get-Location) $envFile
if (Test-Path $envFile) { $lines = @([System.IO.File]::ReadAllLines($full) | Where-Object { $_ -notmatch "^$Name=" }) }
$lines += "$Name=$val"
[System.IO.File]::WriteAllLines($full, $lines)

$gi = Join-Path (Get-Location) 'project\.gitignore'
$linked = [bool](Get-Item 'project').LinkType
if ($linked) {
  git -C project check-ignore -q .env 2>$null
  if ($LASTEXITCODE -ne 0) { Write-Host 'В .gitignore твоего проекта нет .env – скажи агенту, добавлять или нет.' }
} elseif ((Test-Path $gi) -and -not (Select-String -Path $gi -Pattern '^\.env$' -Quiet)) {
  $text = [System.IO.File]::ReadAllText($gi)
  if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) { $text += "`n" }
  [System.IO.File]::WriteAllText($gi, $text + ".env`n")
}
Write-Output "$Name записан в project\.env, длина – $($val.Length). Скажи агенту: «положил ключ»."
