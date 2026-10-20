# Pages publication replaces the base URL; Windows PowerShell 5.1 or newer.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$baseUrl = 'https://rknnai.github.io/rknn-center'
$architecture = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITEW6432')
if ([string]::IsNullOrEmpty($architecture)) {
    $architecture = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE')
}
$target = switch ($architecture) {
    'AMD64' { 'x86_64-pc-windows-gnullvm' }
    'ARM64' { 'aarch64-pc-windows-gnullvm' }
    default { throw "Unsupported Windows architecture: $architecture" }
}
$metadata = Invoke-RestMethod -Uri "$baseUrl/packages/latest.json"
if ($metadata.schema_version -ne 1) {
    throw 'Unsupported publication metadata schema'
}
$entry = $metadata.targets.PSObject.Properties[$target]
if ($null -eq $entry) {
    throw "No installer published for $target in version $($metadata.version)"
}
$package = $entry.Value
if ($package.file -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\.exe$' -or
    $package.path -cne "packages/$target/$($package.file)" -or
    $package.sha256 -notmatch '^[a-fA-F0-9]{64}$') {
    throw 'Invalid Windows package metadata'
}
$downloadDirectory = Join-Path ([IO.Path]::GetTempPath()) ('rknn3-install-' + [Guid]::NewGuid())
try {
    New-Item -ItemType Directory -Path $downloadDirectory | Out-Null
    $installer = Join-Path $downloadDirectory $package.file
    Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/$($package.path)" -OutFile $installer
    $actualHash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash
    if ($actualHash -ine $package.sha256) {
        throw 'Installer SHA-256 mismatch; installation refused'
    }
    Write-Host "Installing RKNN Center $($metadata.version) for $target"
    $process = Start-Process -FilePath $installer -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Installer failed with exit code $($process.ExitCode)"
    }
} finally {
    if (Test-Path -LiteralPath $downloadDirectory) {
        Remove-Item -LiteralPath $downloadDirectory -Recurse -Force
    }
}
