param(
  [string]$Apk = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path 'build\app\outputs\flutter-apk\app-release.apk')
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$versionLine = Select-String -LiteralPath (Join-Path $project 'pubspec.yaml') -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if (!$versionLine) { throw 'Version du projet introuvable dans pubspec.yaml.' }
$versions = $versionLine.Matches[0].Groups[1].Value.Split('+')
if ($versions.Count -ne 2) { throw 'Version du projet invalide dans pubspec.yaml.' }
$sdk = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } elseif ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$outils = Join-Path $sdk 'build-tools\36.0.0'
$aapt = Join-Path $outils 'aapt.exe'
$apksigner = Join-Path $outils 'apksigner.bat'
if (!(Test-Path -LiteralPath $Apk) -or !(Test-Path -LiteralPath $aapt) -or !(Test-Path -LiteralPath $apksigner)) {
  throw 'APK release ou outils Android SDK 36 introuvables.'
}

$badging = & $aapt dump badging $Apk
if ($LASTEXITCODE -ne 0) { throw 'Lecture des métadonnées APK échouée.' }
$texte = $badging -join "`n"
$lignes = $badging | Where-Object { $_ -match "^(package:|sdkVersion:|targetSdkVersion:|uses-permission:)" }
$lignes | Write-Output
if ($texte -notmatch "versionName='$([regex]::Escape($versions[0]))'") { throw 'Version Android inattendue.' }
if ($texte -notmatch "versionCode='$([regex]::Escape($versions[1]))'") { throw 'Code de version Android inattendu.' }
if ($texte -notmatch "sdkVersion:'24'") { throw 'minSdk Android inattendu.' }
if ($texte -notmatch "targetSdkVersion:'36'") { throw 'targetSdk Android inattendu.' }
if ($texte -match 'android\.permission\.INTERNET|AD_ID') {
  throw 'Permission réseau ou publicité interdite dans le paquet release.'
}
$manifest = (& $aapt dump xmltree $Apk AndroidManifest.xml) -join "`n"
if ($LASTEXITCODE -ne 0 -or $manifest -notmatch 'ca\.lesieur\.jeux_enfants\.MainActivity') {
  throw 'Activité principale Android absente du manifeste APK.'
}

& $apksigner verify $Apk
if ($LASTEXITCODE -ne 0) { throw 'Signature APK invalide.' }
Write-Output 'APK release valide : version, SDK, permissions et signature vérifiés.'
