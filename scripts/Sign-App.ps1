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
if (![String]::IsNullOrEmpty($ENV:AZSTORAGETENANTID) -and ![String]::IsNullOrEmpty($ENV:AZSTORAGECLIENTID) -and ![String]::IsNullOrEmpty($ENV:AZSTORAGECLIENTSECRET)) {
    $unsecurepfxFile = Get-BlobFromPrivateAzureStorageOauth2 -blobUri $unsecurepfxFile `
                                                             -az_storage_tenantId $ENV:AZ_STORAGE_TENANTID `
                                                             -az_storage_clientId $ENV:AZ_STORAGE_CLIENTID `
                                                             -az_storage_clientSecret $ENV:AZ_STORAGE_CLIENTSECRET
}

$appFolders.Split(',') | ForEach-Object {
    Write-Host "Signing $_"
    Get-ChildItem -Path (Join-Path $buildArtifactFolder $_) -Filter "*.app" | ForEach-Object {
        Sign-BCContainerApp -containerName $containerName -appFile $_.FullName -pfxFile $unsecurePfxFile -pfxPassword $codeSignPfxPassword
    }
}