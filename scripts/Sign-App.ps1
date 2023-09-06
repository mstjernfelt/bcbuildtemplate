Param(
    [ValidateSet('AzureDevOps','Local','AzureVM')]
    [Parameter(Mandatory=$false)]
    [string] $buildEnv = "AzureDevOps",

    [Parameter(Mandatory=$false)]
    [string] $containerName = $ENV:CONTAINERNAME,

    [Parameter(Mandatory=$false)]
    [string] $buildArtifactFolder = $ENV:BUILD_ARTIFACTSTAGINGDIRECTORY,

    [Parameter(Mandatory=$true)]
    [string] $appFolders,

    [Parameter(Mandatory=$false)]
    [securestring] $codeSignPfxFile = $null,

    [Parameter(Mandatory=$false)]
    [securestring] $codeSignPfxPassword = $null
)

if (-not ($CodeSignPfxFile)) {
    $CodeSignPfxFile = try { $ENV:CODESIGNPFXFILE | ConvertTo-SecureString } catch { ConvertTo-SecureString -String $ENV:CODESIGNPFXFILE -AsPlainText -Force }
}

if (-not ($CodeSignPfxPassword)) {
    $CodeSignPfxPassword = try { $ENV:CODESIGNPFXPASSWORD | ConvertTo-SecureString } catch { ConvertTo-SecureString -String $ENV:CODESIGNPFXPASSWORD -AsPlainText -Force }
}

$unsecurepfxFile = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($codeSignPfxFile)))

# If licenseFile is provided and required Azure storage credentials are available
# Fetch the license file from private Azure storage using provided credentials
if ($ENV:DOWNLOADFROMPRIVATEAZURESTORAGE) {
    $unsecurepfxFile = Get-BlobFromPrivateAzureStorageOauth2 -blobUri $unsecurepfxFile
}

$appFolders.Split(',') | ForEach-Object {
    Write-Host "Signing $_"
    Get-ChildItem -Path (Join-Path $buildArtifactFolder $_) -Filter "*.app" | ForEach-Object {
        Sign-BCContainerApp -containerName $containerName -appFile $_.FullName -pfxFile $unsecurePfxFile -pfxPassword $codeSignPfxPassword
    }
}