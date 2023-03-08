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
$headers.Add("Cookie", "VstsSession=%7B%22PersistentSessionId%22%3A%220bea08cd-0e83-4afd-bc1f-6778bff9b093%22%2C%22PendingAuthenticationSessionId%22%3A%2200000000-0000-0000-0000-000000000000%22%2C%22CurrentAuthenticationSessionId%22%3A%2200000000-0000-0000-0000-000000000000%22%2C%22SignInState%22%3A%7B%7D%7D")

# Get pipeline last run
$response = Invoke-RestMethod "$Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$($ENV:SYSTEM_TEAMPROJECT)/_apis/pipelines/$($Env:SYSTEM_DEFINITIONID)/runs?api-version=7.1-preview.1" -Method "GET" -Headers $headers
$lastRun = $response.value | Sort-Object id -Descending | Where-Object result -ne "failed" | Select-Object -First 1 id, name, result

# Get Artifact Name
$response = Invoke-RestMethod "$Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$($ENV:SYSTEM_TEAMPROJECT)/_apis/build/builds/$($lastRun.id)/artifacts?api-version=4.1" -Method "GET" -Headers $headers
$artifactName = $response.value.name

# Download artifact ZIP
$destinationDirectory = "$($artifactstagingdirectory)\$(New-Guid)"

if (-not (Test-Path $destinationDirectory)) {
    New-Item -ItemType Directory -Path $destinationDirectory | Out-Null
}

$zipFile = "$($destinationDirectory)\artifact$($response.value.name).zip"
$response = Invoke-RestMethod "$Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$($ENV:SYSTEM_TEAMPROJECT)/_apis/build/builds/$($lastRun.id)/artifacts?artifactName=$($artifactName)&api-version=4.1&%24format=zip" -Method "GET" -Headers $headers

$url = "$Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$($ENV:SYSTEM_TEAMPROJECT)/_apis/build/builds/$($lastRun.id)/artifacts?artifactName=$($artifactName)&api-version=4.1&%24format=zip"

$webClient = New-Object System.Net.WebClient
$webClient.Headers.Add("Authorization", "Basic " + $encodedAuthInfo)
$webClient.DownloadFile($url, $zipFile)

Expand-Archive -Path $zipFile -DestinationPath $destinationDirectory -Force

$appFolders.Split(',') | ForEach-Object {
    $appsFolder = Join-Path "$($destinationDirectory)\$($artifactName)" $_

    Get-ChildItem -Path $appsFolder -Filter "*.app" | ForEach-Object {
        $appFile = "$($appsFolder)\$($_)"
        Publish-BCContainerApp -containerName $containerName -appFile $appFile -skipVerification:$skipVerification -sync -install
    }
}