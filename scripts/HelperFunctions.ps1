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

    $tokenUrl = "https://login.microsoftonline.com/$az_storage_tenantId/oauth2/token"

    $tokenParams = @{
        grant_type    = "client_credentials"
        client_id     = $az_storage_clientId
        client_secret = $az_storage_clientSecret
        resource      = "https://storage.azure.com"
    }

    $tokenResponse = Invoke-RestMethod -Method POST -Uri $tokenUrl -ContentType "application/x-www-form-urlencoded" -Body $tokenParams
    $accessToken = $tokenResponse.access_token

    if (-not [string]::IsNullOrEmpty($accessToken)) {
        $headers = @{
            Authorization  = "Bearer $accessToken"
            "x-ms-version" = "2017-11-09"
        }
        try {
            $TempFile = New-TemporaryFile
            $response = Invoke-RestMethod -Method Get -Uri $blobUri -Headers $headers -Encoding UTF8
            $response | Out-File -FilePath $TempFile.FullName -Encoding utf8

            Write-Host "Successfully downloaded $($blobUri) from Azure Storage Container to $($TempFile)"

            return($TempFile.FullName)
        }
        catch {
            Write-Error "An error occurred while downloading $($blobUri): $($_.Exception.Message)"
        }
    }
    else {
        Write-Error "Failed to retrieve access token from $tokenUrl."
    }
}
