# Gets License from Private Azure Storage Conatiner and saves it temporarily 
Function Get-BlobFromPrivateAzureStorageOauth2 {
    param(
        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $true)]
        [String]$blobUri,
        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $true)]
        [String]$az_storage_tenantId,
        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $true)]
        [String]$az_storage_clientId,
        [Parameter(ValueFromPipelineByPropertyName, Mandatory = $true)]
        [String]$az_storage_clientSecret
    )

    $encodedSecret = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($az_storage_clientId))
    Write-Host "Encoded Secret: $encodedSecret"

    Write-Host "Getting new Auth Context"
    $context = New-BcAuthContext -tenantID $ENV:AZSTORAGETENANTID -clientID $ENV:AZSTORAGECLIENTID -clientSecret $ENV:AZSTORAGECLIENTSECRET -scopes "https://storage.azure.com/.default"
    Write-Host "Access token retieved"

    $date = Get-Date
    $formattedDateTime = $date.ToUniversalTime().ToString("R")

    $headers = @{ 
        "Authorization" = "Bearer $($context.accessToken)"
        "x-ms-version"  = "2017-11-09"
        "Content-Type" = "application/json"
        "x-ms-date" = "$formattedDateTime"
    }

    $TempFile = New-TemporaryFile

    Write-Host "Downloading $blobUri to $TempFile"

    $hdr = $headers | ConvertTo-Json

    Write-Host "Headers: $hdr"

    Download-File -sourceUrl $blobUri -destinationFile $TempFile -headers $headers

    Write-Host "License file to use is $($TempFile)"

    return($TempFile)
}



