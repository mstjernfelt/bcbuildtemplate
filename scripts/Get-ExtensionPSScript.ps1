Param(
    [Parameter(Mandatory = $true)]
    [string] $configurationFilePath
)

$settings = (Get-Content -Path $configurationFilePath -Encoding UTF8 | Out-String | ConvertFrom-Json)

$ExtensionScript = Join-Path $env:TEMP 'ExtensionScript.ps1'

if (Test-Path $ExtensionScript) {
    Remove-Item $ExtensionScript
  }

foreach ($extension in $settings.scriptExtension) {
    if ($extension.URI -like '*https://dev.azure.com/*') {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Basic OnRoZ2Rmcmtmc2p4bHA1ZmRrdWFjdGN6cm5rNW1oYXR0dG1ya2Z5bDJzcm1qNWpuNjV1Z2E=")
        $headers.Add("Cookie", "VstsSession=%7B%22PersistentSessionId%22%3A%220bea08cd-0e83-4afd-bc1f-6778bff9b093%22%2C%22PendingAuthenticationSessionId%22%3A%2200000000-0000-0000-0000-000000000000%22%2C%22CurrentAuthenticationSessionId%22%3A%2200000000-0000-0000-0000-000000000000%22%2C%22SignInState%22%3A%7B%7D%7D")
   
        Set-Content -Path $ExtensionScript -Value (Invoke-WebRequest -Uri $extension.URI -Method 'GET' -Headers $headers).Content -Encoding UTF8 -Force
    
        . $ExtensionScript -parameters $extension.parameters
    } else {
        Set-Content -Path $ExtensionScript -Value (Get-Content -Path $extension.URI)
    
        . $ExtensionScript -parameters $extension.parameters
    }
}