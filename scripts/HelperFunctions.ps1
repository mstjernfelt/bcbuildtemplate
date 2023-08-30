$useTimeOutWebClient = $false
if ($PSVersionTable.PSVersion -lt "6.0.0" -or $useTimeOutWebClient) {
    $timeoutWebClientCode = @"
	using System.Net;
 
	public class TimeoutWebClient : WebClient
	{
        int theTimeout;

        public TimeoutWebClient(int timeout)
        {
            theTimeout = timeout;
        }

		protected override WebRequest GetWebRequest(System.Uri address)
		{
			WebRequest request = base.GetWebRequest(address);
			if (request != null)
			{
				request.Timeout = theTimeout;
			}
			return request;
		}
 	}
"@;
if (-not ([System.Management.Automation.PSTypeName]"TimeoutWebClient").Type) {
    Add-Type -TypeDefinition $timeoutWebClientCode -Language CSharp -WarningAction SilentlyContinue | Out-Null
    $useTimeOutWebClient = $true
}
}

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

    Download-File2 -sourceUrl $blobUri -destinationFile $TempFile -headers $headers

    $parameters.licenseFile = $TempFile

    Write-Host "License file to use is $($TempFile)"

    return($TempFile)
}

<#
 .Synopsis
  Download File
 .Description
  Download a file to local computer
 .Parameter sourceUrl
  Url from which the file will get downloaded
 .Parameter destinationFile
  Destinatin for the downloaded file
 .Parameter dontOverwrite
  Specify dontOverwrite if you want top skip downloading if the file already exists
 .Parameter timeout
  Timeout in seconds for the download
 .Example
  Download-File -sourceUrl "https://myurl/file.zip" -destinationFile "c:\temp\file.zip" -dontOverwrite
#>
function Download-File2 {
    Param (
        [Parameter(Mandatory = $true)]
        [string] $sourceUrl,
        [Parameter(Mandatory = $true)]
        [string] $destinationFile,
        [hashtable] $headers = @{"UserAgent" = "BcContainerHelper $bcContainerHelperVersion" },
        [switch] $dontOverwrite,
        [int]    $timeout = 100
    )

    function ReplaceCDN {
        Param(
            [string] $sourceUrl
        )

        $cdnStr = '.azureedge.net'
        if ($sourceUrl -like "https://bcartifacts$cdnStr/*" -or $sourceUrl -like "https://bcinsider$cdnStr/*" -or $sourceUrl -like "https://bcprivate$cdnStr/*" -or $sourceUrl -like "https://bcpublicpreview$cdnStr/*") {
            $idx = $sourceUrl.IndexOf("$cdnStr/", [System.StringComparison]::InvariantCultureIgnoreCase)
            $sourceUrl = $sourceUrl.Substring(0, $idx) + '.blob.core.windows.net' + $sourceUrl.Substring($idx + $cdnStr.Length)
        }
        $sourceUrl
    }

    $telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
    try {

        $replaceUrls = @{
            "https://go.microsoft.com/fwlink/?LinkID=844461"                                                                = "https://bcartifacts.azureedge.net/prerequisites/DotNetCore.1.0.4_1.1.1-WindowsHosting.exe"
            "https://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi"          = "https://bcartifacts.azureedge.net/prerequisites/rewrite_2.0_rtw_x64.msi"
            "https://download.microsoft.com/download/5/5/3/553C731E-9333-40FB-ADE3-E02DC9643B31/OpenXMLSDKV25.msi"          = "https://bcartifacts.azureedge.net/prerequisites/OpenXMLSDKv25.msi"
            "https://download.microsoft.com/download/A/1/2/A129F694-233C-4C7C-860F-F73139CF2E01/ENU/x86/ReportViewer.msi"   = "https://bcartifacts.azureedge.net/prerequisites/ReportViewer.msi"
            "https://download.microsoft.com/download/1/3/0/13089488-91FC-4E22-AD68-5BE58BD5C014/ENU/x86/SQLSysClrTypes.msi" = "https://bcartifacts.azureedge.net/prerequisites/SQLSysClrTypes.msi"
            "https://download.microsoft.com/download/3/A/6/3A632674-A016-4E31-A675-94BE390EA739/ENU/x64/sqlncli.msi"        = "https://bcartifacts.azureedge.net/prerequisites/sqlncli.msi"
            "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe"           = "https://bcartifacts.azureedge.net/prerequisites/vcredist_x86.exe"
        }

        if ($replaceUrls.ContainsKey($sourceUrl)) {
            $sourceUrl = $replaceUrls[$sourceUrl]
        }

        # If DropBox URL with dl=0 - replace with dl=1 (direct download = common mistake)
        if ($sourceUrl.StartsWith("https://www.dropbox.com/", "InvariantCultureIgnoreCase") -and $sourceUrl.EndsWith("?dl=0", "InvariantCultureIgnoreCase")) {
            $sourceUrl = "$($sourceUrl.Substring(0, $sourceUrl.Length-1))1"
        }

        if (Test-Path $destinationFile -PathType Leaf) {
            if ($dontOverwrite) { 
                return
            }
            Remove-Item -Path $destinationFile -Force
        }
        $path = [System.IO.Path]::GetDirectoryName($destinationFile)
        if (!(Test-Path $path -PathType Container)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Write-Host "Downloading $destinationFile"
        if ($sourceUrl -like "https://*.sharepoint.com/*download=1*") {
            Invoke-WebRequest -UseBasicParsing -Uri $sourceUrl -OutFile $destinationFile
        }
        else {
            if ($bcContainerHelperConfig.DoNotUseCdnForArtifacts) {
                $sourceUrl = ReplaceCDN -sourceUrl $sourceUrl
            }
            try {
                DownloadFileLow -sourceUrl $sourceUrl -destinationFile $destinationFile -dontOverwrite:$dontOverwrite -timeout $timeout -headers $headers
            }
            catch {
                try {
                    $waittime = 2 + (Get-Random -Maximum 5 -Minimum 0)
                    $newSourceUrl = ReplaceCDN -sourceUrl $sourceUrl
                    if ($sourceUrl -eq $newSourceUrl) {
                        Write-Host "Error downloading..., retrying in $waittime seconds..."
                    }
                    else {
                        Write-Host "Could not download from CDN..., retrying from blob storage in $waittime seconds..."
                    }
                    Start-Sleep -Seconds $waittime
                    DownloadFileLow -sourceUrl $newSourceUrl -destinationFile $destinationFile -dontOverwrite:$dontOverwrite -timeout $timeout -headers $headers
                }
                catch {
                    throw (GetExtendedErrorMessage $_)
                }
            }
        }
    }
    catch {
        TrackException -telemetryScope $telemetryScope -errorRecord $_
        throw
    }
    finally {
        TrackTrace -telemetryScope $telemetryScope
    }
}

function DownloadFileLow {
    Param(
        [string] $sourceUrl,
        [string] $destinationFile,
        [switch] $dontOverwrite,
        [switch] $useDefaultCredentials,
        [switch] $skipCertificateCheck,
        [hashtable] $headers = @{"UserAgent" = "BcContainerHelper $bcContainerHelperVersion" },
        [int] $timeout = 100
    )

    if ($useTimeOutWebClient) {
        Write-Host "Downloading using WebClient"
        if ($skipCertificateCheck) {
            Write-Host "Disabling SSL Verification"
            [SslVerification]::Disable()
        }
        $webClient = New-Object TimeoutWebClient -ArgumentList (1000 * $timeout)
        $headers.Keys | ForEach-Object {
            $webClient.Headers.Add($_, $headers."$_")
        }
        $webClient.UseDefaultCredentials = $useDefaultCredentials
        if (Test-Path $destinationFile -PathType Leaf) {
            if ($dontOverwrite) { 
                return
            }
            Remove-Item -Path $destinationFile -Force
        }
        try {
            $webClient.DownloadFile($sourceUrl, $destinationFile)
        }
        finally {
            $webClient.Dispose()
            if ($skipCertificateCheck) {
                Write-Host "Restoring SSL Verification"
                [SslVerification]::Enable()
            }
        }
    }
    else {
        Write-Host "Downloading using HttpClient"
        
        $handler = New-Object System.Net.Http.HttpClientHandler
        if ($skipCertificateCheck) {
            Write-Host "Disabling SSL Verification on HttpClient"
            [SslVerification]::DisableSsl($handler)
        }
        if ($useDefaultCredentials) {
            $handler.UseDefaultCredentials = $true
        }
        $httpClient = New-Object System.Net.Http.HttpClient -ArgumentList $handler
        $httpClient.Timeout = [Timespan]::FromSeconds($timeout)
        $headers.Keys | ForEach-Object {
            $httpClient.DefaultRequestHeaders.Add($_, $headers."$_")
        }
        $stream = $null
        $fileStream = $null
        if ($dontOverwrite) {
            $fileMode = [System.IO.FileMode]::CreateNew
        }
        else {
            $fileMode = [System.IO.FileMode]::Create
        }
        try {
            $stream = $httpClient.GetStreamAsync($sourceUrl).GetAwaiter().GetResult()
            $fileStream = New-Object System.IO.Filestream($destinationFile, $fileMode)
            $stream.CopyToAsync($fileStream).GetAwaiter().GetResult() | Out-Null
            $fileStream.Close()
        }
        finally {
            if ($fileStream) {
                $fileStream.Dispose()
            }
            if ($stream) {
                $stream.Dispose()
            }
        }
    }
}

function GetExtendedErrorMessage {
    Param(
        $errorRecord
    )

    $exception = $errorRecord.Exception
    $message = $exception.Message

    try {
        if ($errorRecord.ErrorDetails) {
            $errorDetails = $errorRecord.ErrorDetails | ConvertFrom-Json
            $message += " $($errorDetails.error)`r`n$($errorDetails.error_description)"
        }
    }
    catch {}
    try {
        if ($exception -is [System.Management.Automation.MethodInvocationException]) {
            $exception = $exception.InnerException
        }
        if ($exception -is [System.Net.Http.HttpRequestException]) {
            $message += "`r`n$($exception.Message)"
            if ($exception.InnerException) {
                if ($exception.InnerException -and $exception.InnerException.Message) {
                    $message += "`r`n$($exception.InnerException.Message)"
                }
            }

        }
        else {
            $webException = [System.Net.WebException]$exception
            $webResponse = $webException.Response
            try {
                if ($webResponse.StatusDescription) {
                    $message += "`r`n$($webResponse.StatusDescription)"
                }
            }
            catch {}
            $reqstream = $webResponse.GetResponseStream()
            $sr = new-object System.IO.StreamReader $reqstream
            $result = $sr.ReadToEnd()
        }
        try {
            $json = $result | ConvertFrom-Json
            $message += "`r`n$($json.Message)"
        }
        catch {
            $message += "`r`n$result"
        }
        try {
            $correlationX = $webResponse.GetResponseHeader('ms-correlation-x')
            if ($correlationX) {
                $message += " (ms-correlation-x = $correlationX)"
            }
        }
        catch {}
    }
    catch {}
    $message
}