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

    Write-Host "Getting new Auth Context"
    $context = New-BcAuthContext -tenantID $az_storage_tenantId -clientID $az_storage_clientId -clientSecret $az_storage_clientSecret -scopes "https://storage.azure.com/.default"
    Write-Host "Access token retieved"

    $headers = @{ 
        "Authorization" = "Bearer $($context.accessToken)"
        "x-ms-version"  = "2017-11-09"
    }

    $TempFile = New-TemporaryFile

    Write-Host "Downloading $($parameters.licenseFile) to $($TempFile)"

    Download-File -sourceUrl $blobUri -destinationFile $TempFile -headers $headers

    $parameters.licenseFile = $TempFile

    Write-Host "License file to use is $($TempFile)"

    return($TempFile)
}