Param(
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyname=$true)]
    [string] $configurationFilePath,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyname=$true)]
    [string] $scriptToStart = (Join-path $PSScriptRoot $MyInvocation.MyCommand.Name)

)

$scriptPath = Split-Path -Path $configurationFilePath -Parent

# Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
 
# Get the security principal for the Administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
 
# Check to see if we are currently running "as Administrator"
$IsInAdminMode = $myWindowsPrincipal.IsInRole($adminRole)

if (!$IsInAdminMode) {
    $ArgumentList = "-noprofile -file ${scriptToStart}"
    Write-Host "Starting '${scriptToStart}' in Admin Mode..."
    Start-Process powershell -Verb runas -WorkingDirectory $scriptPath -ArgumentList @($ArgumentList,$configurationFilePath,$scriptToStart) -WindowStyle Normal -Wait 
    paus
}
else {
    Invoke-Expression -Command "Function Install-BCContainerHelper { $((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gunnargestsson/bcbuildtemplate/master/scripts/Install-BCContainerHelper.ps1").Content.Substring(1)) }"
    Install-BCContainerHelper
    $settings = (Get-Content -Path $configurationFilePath -Encoding UTF8 | Out-String | ConvertFrom-Json)
    $userProfile = $settings.userProfiles | Where-Object -Property profile -EQ "$env:computername\$env:username"
    if (!$userProfile) { 
        $credential = Get-Credential -Message 'New Container Credentials'
        if (-not $credential) { Throw 'Unable to create a container' }
        $licenseFilePath = Read-Host -Prompt "Enter License File Path" -AsSecureString
        $userProfile = New-Object -TypeName psobject
        $userProfile | Add-Member -NotePropertyName 'profile' -NotePropertyValue "$env:computername\$env:username"
        $userProfile | Add-Member -NotePropertyName 'Username' -NotePropertyValue $credential.UserName
        $userProfile | Add-Member -NotePropertyName "Password" -NotePropertyValue (ConvertFrom-SecureString $credential.Password)       
        $userProfile | Add-Member -NotePropertyName 'licenseFilePath' -NotePropertyValue (ConvertFrom-SecureString $licenseFilePath)
        $containerParameters = new-object -TypeName PSobject
        $containerParameters | Add-Member -NotePropertyName 'updateHosts' -NotePropertyValue $true
        $userProfile | Add-Member -MemberType NoteProperty -Name 'containerParameters' -Value $containerParameters       
        $settings.userProfiles += $userProfile
        Set-Content -Path $configurationFilePath -Encoding UTF8 -Value ($settings | ConvertTo-Json -Depth 10)
    }
    $containername = $settings.name.ToLower()
    $auth = 'UserPassword'
    $artifact = $settings.versions[0].artifact

    if ($artifact -like "https://*") {
        $artifactUrl = $artifact
    } else {
        $segments = "$artifact/////".Split('/')
        $artifactUrl = Get-BCArtifactUrl -storageAccount $segments[0] -type $segments[1] -version $segments[2] -country $segments[3] -select $segments[4] | Select-Object -First 1   
    }

    $username = $userProfile.Username
    $password = ConvertTo-SecureString -String $userProfile.Password
    $credential = New-Object System.Management.Automation.PSCredential ($username, $password)
    $licenseFile = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($(ConvertTo-SecureString -String $userProfile.licenseFilePath))))

    $parameters = @{
        "Accept_Eula"     = $true
        "Accept_Outdated" = $true
    }

    
    if ($settings.containerParameters) {
        Foreach ($parameter in ($settings.containerParameters.PSObject.Properties | Where-Object -Property MemberType -eq NoteProperty)) {
            try { $value = (Invoke-Expression $parameter.Value) } catch { $value = $parameter.Value }
            if (!([String]::IsNullOrEmpty($value))) { $parameters += @{ $parameter.Name = $value } }
        }
    }


    if ($settings.dotnetAddIns) {
        $parameters += @{ 
            "myscripts" = @( "$configurationFilePath"
                @{ "SetupAddins.ps1" = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gunnargestsson/bcbuildtemplate/master/scripts/Copy-AddIns.ps1").Content })
        }    
    }

    if ($userProfile.containerParameters) {
        Foreach ($parameter in ($userProfile.containerParameters.PSObject.Properties | Where-Object -Property MemberType -eq NoteProperty)) {
            try { $value = (Invoke-Expression $parameter.Value) } catch { $value = $parameter.Value }
            if (!([String]::IsNullOrEmpty($value))) { 
                try { $parameters += @{ $parameter.Name = $value } } catch { $parameters."$($parameter.Name)" = $value }
            }
        }
    }   

    if ($settings.serverConfiguration) {
        $serverConfiguration = ''
        Foreach ($parameter in ($settings.serverConfiguration.PSObject.Properties | Where-Object -Property MemberType -eq NoteProperty)) {
            try { $value = (Invoke-Expression $parameter.Value) } catch { $value = $parameter.Value }
            if (!([String]::IsNullOrEmpty($value))) { 
                if ($serverConfiguration -eq '') {
                    $serverConfiguration =  "$($parameter.Name)=$($value)"
                } else {
                    $serverConfiguration +=  ",$($parameter.Name)=$($value)"
                }
            } 
        }
        if ($serverConfiguration -ne '') {
            $additionalParameters = @("--env CustomNavSettings=${serverConfiguration}")
            try { $parameters += @{ "additionalParameters" = $additionalParameters } } catch { $parameters."additionalParameters" = $additionalParameters } 
        }
    }
    New-BCContainer @parameters `
        -containerName $containername `
        -artifactUrl $artifactUrl `
        -Credential $credential `
        -auth $auth `
        -timeout 5000 `
        -licenseFile $licenseFile

    $settings.dependencies | ForEach-Object {
        Write-Host "Publishing $_"
        Publish-BCContainerApp -containerName $containerName -appFile $_ -skipVerification -sync -install
    }

    if ($settings.includeTestRunnerOnly) {
        Import-TestToolkitToBcContainer -containerName $containerName -includeTestRunnerOnly 
    }
    if ($settings.includeTestLibrariesOnly) {
        Import-TestToolkitToBcContainer -containerName $containerName -includeTestLibrariesOnly 
    }
    if ($settings.includeTestFrameworkOnly) {
        Import-TestToolkitToBcContainer -containerName $containerName -includeTestFrameworkOnly
    }
    if ($settings.testToolkitCountry) {
        Import-TestToolkitToBcContainer -containerName $containerName -testToolkitCountry $settings.testToolkitCountry
    }

    Invoke-Expression -Command "Function Update-LaunchJson { $((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gunnargestsson/bcbuildtemplate/master/scripts/Update-LaunchJson.ps1").Content.Substring(1)) }"
    Update-LaunchJson -appFolders $settings.appFolders -BaseFolder (Split-Path -Path $scriptPath -Parent) 
    Update-LaunchJson -appFolders $settings.testFolders -BaseFolder (Split-Path -Path $scriptPath -Parent) -PageObjectId 130451

}