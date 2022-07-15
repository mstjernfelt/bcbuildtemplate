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
    Write-Host "Fetching custom script $($extension.path)"

    if ($extension.TaskName -ne $ENV:SYSTEM_TASKDISPLAYNAME) {
        Write-Host "No custom PS script matches TaskName $($extension.TaskName) ($($ENV:SYSTEM_TASKDISPLAYNAME))"
        continue
    }

    switch ($extension.path) {
        {$_ -like "*https://raw.githubusercontent.com*"} { 
            Set-Content -Path $ExtensionScript -Value (Invoke-WebRequest -Uri $extension.path).Content -Encoding UTF8 -Force
        }
        {$_ -like "*https://dev.azure.com/*"} {
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Authorization", "Basic OnRoZ2Rmcmtmc2p4bHA1ZmRrdWFjdGN6cm5rNW1oYXR0dG1ya2Z5bDJzcm1qNWpuNjV1Z2E=")
       
            Set-Content -Path $ExtensionScript -Value (Invoke-WebRequest -Uri $extension.path -Method 'GET' -Headers $headers).Content -Encoding UTF8 -Force
        }
        Default {
            Set-Content -Path $ExtensionScript -Value (Get-Content -Path $extension.path) -Encoding UTF8 -Force
        }        
    }

    Write-Host "Executing custom PS script $($extension.path) on task $($ENV:SYSTEM_TASKDISPLAYNAME)"

    . $ExtensionScript -parameters $extension.parameters
}