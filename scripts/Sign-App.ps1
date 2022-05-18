Param(
    [ValidateSet('AzureDevOps', 'Local', 'AzureVM')]
    [Parameter(Mandatory = $false)]
    [string] $buildEnv = "AzureDevOps",

    [Parameter(Mandatory = $false)]
    [string] $containerName = $ENV:CONTAINERNAME,

    [Parameter(Mandatory = $false)]
    [string] $buildArtifactFolder = $ENV:BUILD_ARTIFACTSTAGINGDIRECTORY,

    [Parameter(Mandatory = $true)]
    [string] $appFolders,

    [Parameter(Mandatory = $false)]
    [securestring] $codeSignPfxFile = $null,

    [Parameter(Mandatory = $false)]
    [securestring] $codeSignPfxPassword = $null
)

if (-not $env:USEAZURESIGNTOOL) {
    if (-not ($CodeSignPfxFile)) {
        $CodeSignPfxFile = try { $ENV:CODESIGNPFXFILE | ConvertTo-SecureString } catch { ConvertTo-SecureString -String $ENV:CODESIGNPFXFILE -AsPlainText -Force }
    }
    
    if (-not ($CodeSignPfxPassword)) {
        $CodeSignPfxPassword = try { $ENV:CODESIGNPFXPASSWORD | ConvertTo-SecureString } catch { ConvertTo-SecureString -String $ENV:CODESIGNPFXPASSWORD -AsPlainText -Force }
    }
    
    $unsecurepfxFile = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($codeSignPfxFile)))
    $appFolders.Split(',') | ForEach-Object {
        Write-Host "Signing $_ with bccontainerhelper"
        Get-ChildItem -Path (Join-Path $buildArtifactFolder $_) -Filter "*.app" | ForEach-Object {
            Sign-BCContainerApp -containerName $containerName -appFile $_.FullName -pfxFile $unsecurePfxFile -pfxPassword $codeSignPfxPassword
        }
    }
}
else {
    Write-Host "Variables:"
    Write-Host "-azure-key-vault-tenant-id $($env:azurekeyvaulttenantid)"
    Write-Host "-kvu $($env:azurekeyvaulturl)"
    Write-Host "-kvi $($env:azurekeyvaultclientid)"
    Write-Host "-kvs $($env:azurekeyvaultclientsecret)"
    Write-Host "-kvc $($env:azurekeyvaultcertificate)"
    Write-Host "-tr $($env:timestamp)"

    $appFolders.Split(',') | ForEach-Object {
        Write-Host "Signing $_ with AzureSignTool"
        Get-ChildItem -Path (Join-Path $buildArtifactFolder $_) -Filter "*.app" | ForEach-Object {
            AzureSignTool sign --azure-key-vault-tenant-id $($env:azurekeyvaulttenantid) `
                -kvu $($env:azurekeyvaulturl) `
                -kvi $($env:azurekeyvaultclientid) `
                -kvs $($env:azurekeyvaultclientsecret) `
                -kvc $($env:azurekeyvaultcertificate) `
                -tr $($env:timestamp) `
                -td sha256 $_.FullName
        }
    }
}