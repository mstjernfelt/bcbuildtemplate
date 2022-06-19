Param(
    [Parameter(Mandatory = $true)]
    [string] $configurationFilePath
)

$settings = (Get-Content -Path $configurationFilePath -Encoding UTF8 | Out-String | ConvertFrom-Json)

$ExtensionScript = Join-Path $env:TEMP 'ExtensionScript.ps1'

if (Test-Path $ExtensionScript) {
    Remove-Item $ExtensionScript
  }

Write-Host "Executing custom Powershell script."

foreach ($extension in $settings.scriptExtension) {
    Write-Host "Fetching custom script from $extension.URI"

    if ($extension.TaskName -ne $ENV:SYSTEM_TASKDISPLAYNAME) {
        Write-Host "No custom PS script matches TaskName $($extension.TaskName) ($($ENV:SYSTEM_TASKDISPLAYNAME))"
        continue
    }

    switch ($extension.URI) {
        {$_ -like "*https://raw.githubusercontent.com*"} { 
            Set-Content -Path $ExtensionScript -Value (Invoke-WebRequest -Uri $extension.URI).Content -Encoding UTF8 -Force
        }
        {$_ -like "*https://dev.azure.com/*"} {
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Authorization", "Basic OnRoZ2Rmcmtmc2p4bHA1ZmRrdWFjdGN6cm5rNW1oYXR0dG1ya2Z5bDJzcm1qNWpuNjV1Z2E=")
            $headers.Add("Cookie", "VstsSession=%7B%22PersistentSessionId%22%3A%220bea08cd-0e83-4afd-bc1f-6778bff9b093%22%2C%22PendingAuthenticationSessionId%22%3A%2200000000-0000-0000-0000-000000000000%22%2C%22CurrentAuthenticationSessionId%22%3A%2200000000-0000-0000-0000-000000000000%22%2C%22SignInState%22%3A%7B%7D%7D")
       
            Set-Content -Path $ExtensionScript -Value (Invoke-WebRequest -Uri $extension.URI -Method 'GET' -Headers $headers).Content -Encoding UTF8 -Force
        }
        Default {
            Set-Content -Path $ExtensionScript -Value (Get-Content -Path $extension.URI) -Encoding UTF8 -Force
        }
    }

    Write-Host "Executing custom PS script $$extension.URI on task $settings.scriptExtension"
    . $ExtensionScript -parameters $extension.parameters
}