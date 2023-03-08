Param(
    [ValidateSet('AzureDevOps', 'Local', 'AzureVM')]
    [Parameter(Mandatory = $false)]
    [string] $buildEnv = "AzureDevOps",

    [Parameter(Mandatory = $false)]
    [string] $containerName = $ENV:CONTAINERNAME,

    [Parameter(Mandatory = $false)]
    [string] $buildProjectFolder = $ENV:BUILD_REPOSITORY_LOCALPATH,

    [Parameter(Mandatory = $false)]
    [string] $buildArtifactFolder = $ENV:BUILD_ARTIFACTSTAGINGDIRECTORY,

    [Parameter(Mandatory = $true)]
    [string] $appFolders,

    [Parameter(Mandatory = $false)]
    $licenseFile = $null,

    [switch] $skipVerification
)

if (-not ($licenseFile)) {
    $licenseFile = try { $ENV:LICENSEFILE | ConvertTo-SecureString } catch { ConvertTo-SecureString -String $ENV:LICENSEFILE -AsPlainText -Force }
}

if ($licenseFile) {    
    $unsecureLicenseFile = try { ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($licenseFile))) } catch { $licenseFile }
    Import-BcContainerLicense -containerName $containerName -licenseFile $unsecureLicenseFile 
}

$artifactstagingdirectory = $buildArtifactFolder
$systemdefinitionId = $Env:SYSTEM_DEFINITIONID

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$authInfo = $ENV:DEVOPSUSERNAME + ":" + $ENV:DEVOPSPAT
$encodedAuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($authInfo))

$headers.Add("Authorization", "Basic " + $encodedAuthInfo)

# Get pipeline last run
$apiUrl = "$Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$($ENV:SYSTEM_TEAMPROJECT)/_apis/pipelines/$($Env:SYSTEM_DEFINITIONID)/runs?api-version=7.1-preview.1"
Write-Host "Finding last pipeline run: $($apiURL)"
$response = Invoke-RestMethod $apiUrl -Method "GET" -Headers $headers
$lastRun = $response.value | Sort-Object id -Descending | Where-Object result -ne "failed" | Select-Object -First 1 id, name, result

# Get Artifact Name
$apiUrl = "$Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$($ENV:SYSTEM_TEAMPROJECT)/_apis/build/builds/$($lastRun.id)/artifacts?api-version=4.1"
Write-Host "Setting Artifact Name: $($apiURL)"
$response = Invoke-RestMethod $apiURL -Method "GET" -Headers $headers
$artifactName = $response.value.name

# Download artifact ZIP
$zipFileDestinationDirectory = "$($artifactstagingdirectory)\$(New-Guid)"

if (-not (Test-Path $zipFileDestinationDirectory)) {
    New-Item -ItemType Directory -Path $zipFileDestinationDirectory | Out-Null
}

$zipFile = "$($zipFileDestinationDirectory)\artifact$($response.value.name).zip"
$apiUrl = "$Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$($ENV:SYSTEM_TEAMPROJECT)/_apis/build/builds/$($lastRun.id)/artifacts?artifactName=$($artifactName)&api-version=4.1&%24format=zip"
Write-Host "Downloading Artifact Archive to $($zipFile): $($apiURL)"
$webClient = New-Object System.Net.WebClient
$webClient.Headers.Add("Authorization", "Basic " + $encodedAuthInfo)
$webClient.DownloadFile($apiUrl, $zipFile)

Write-Host "Expanding Artifact Archice $($zipFile) to $($zipFileDestinationDirectory)"
Expand-Archive -Path $zipFile -DestinationPath $zipFileDestinationDirectory -Force

$appFolders.Split(',') | ForEach-Object {
    $appsFolder = Join-Path "$($zipFileDestinationDirectory)\$($artifactName)" $_

    Write-Host "Searching for App Files in $($appsFolder)"

    Get-ChildItem -Path $appsFolder -Filter "*.app" | ForEach-Object {
        $appFile = "$($appsFolder)\$($_)"
        Write-Host "Publishing Artifact: Publish-BCContainerApp -containerName $containerName -appFile $appFile -skipVerification:$skipVerification -sync -install"
        Publish-BCContainerApp -containerName $containerName -appFile $appFile -skipVerification:$skipVerification -sync -install
    }
}

Write-Host "Publish previous build artifact successed."