#1. Get current pipeline runs
    #build.buildId = 372   Pipeline Id

$organisation = "mstjernfelt"
$systemteamProject = "Lab"
$artifactstagingdirectory = "C:\temp\pipeline"
$systemdefinitionId = "43"
$appFolders = "App"
$containerName = "myContainer"
$ENVDevOpsUsername = ""
$ENVDevOpsPAT = "rqszjubez5ltaiafk3uxfigpjhjdcwntwntn2wtai2pkzcb4g2rq"
$systemteamFoundationCollectionUri = "https://dev.azure.com/mstjernfelt/"
$systemteamProject = "Lab"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"

$authInfo = $ENVDevOpsUsername + ":" + $ENVDevOpsPAT
$encodedAuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($authInfo))

$headers.Add("Authorization", "Basic " + $encodedAuthInfo)

# Get pipeline last run
# Get pipeline last run
$apiUrl = "$systemteamFoundationCollectionUri$($systemteamProject)/_apis/pipelines/$($systemdefinitionId)/runs?api-version=7.1-preview.1"
Write-Host "Finding last pipeline run: $($apiURL)"
$response = Invoke-RestMethod $apiUrl -Method "GET" -Headers $headers
$lastRun = $response.value | Sort-Object id -Descending | Where-Object result -eq "succeeded" | Select-Object -First 1 id, name, result
$lastRun

# Get Artifact Name
$response = Invoke-RestMethod "$systemteamFoundationCollectionUri$($systemteamProject)/_apis/build/builds/$($lastRun.id)/artifacts?api-version=4.1" -Method "GET" -Headers $headers
$artifactName = $response.value.name

# Download artifact ZIP
$destinationDirectory = "$($artifactstagingdirectory)\$(New-Guid)"

if (-not (Test-Path $destinationDirectory)) {
    New-Item -ItemType Directory -Path $destinationDirectory | Out-Null
}

$zipFile = "$($destinationDirectory)\artifact$($response.value.name).zip"
$response = Invoke-RestMethod "$systemteamFoundationCollectionUri$($systemteamProject)/_apis/build/builds/$($lastRun.id)/artifacts?artifactName=$($artifactName)&api-version=4.1&%24format=zip" -Method "GET" -Headers $headers

$url = "$systemteamFoundationCollectionUri$($systemteamProject)/_apis/build/builds/$($lastRun.id)/artifacts?artifactName=$($artifactName)&api-version=4.1&%24format=zip"

$webClient = New-Object System.Net.WebClient
$webClient.Headers.Add("Authorization", "Basic " + $encodedAuthInfo)
$webClient.DownloadFile($url, $zipFile)

Expand-Archive -Path $zipFile -DestinationPath $destinationDirectory -Force

$appFolders.Split(',') | ForEach-Object {
    $appsFolder = Join-Path "$($destinationDirectory)\$($artifactName)" $_

    Get-ChildItem -Path $appsFolder -Filter "*.app" | ForEach-Object {
        $appFile = "$($appsFolder)\$($_)"
        Write-Host "Publish-BCContainerApp -containerName $containerName -appFile ""$appFile"" -skipVerification:$skipVerification -sync -install"
    }
}

$appName = Invoke-ScriptInBcContainer -containerName des21 -scriptblock {
    param($appFile)
    return (Get-NAVAppInfo -Path $appFile).Name
} -argumentList $containerPath