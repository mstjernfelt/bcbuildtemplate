Param(
    [Parameter(Mandatory = $true)]
    [string] $configurationFilePath,

    [ValidateSet('AzureDevOps', 'Local', 'AzureVM')]
    [Parameter(Mandatory = $false)]
    [string] $buildEnv = "AzureDevOps",

    [Parameter(Mandatory = $false)]
    [string] $version = $ENV:VERSION,

    [Parameter(Mandatory = $false)]
    [string] $buildProjectFolder = $ENV:BUILD_REPOSITORY_LOCALPATH,

    [Parameter(Mandatory = $false)]
    [string] $appVersion = "",

    [Parameter(Mandatory = $true)]
    [string] $branchName
)

if ($appVersion) {
    Write-Host "Updating build number to $appVersion"
    write-host "##vso[build.updatebuildnumber]$appVersion"
}

$settings = (Get-Content -Path $configurationFilePath -Encoding UTF8 | Out-String | ConvertFrom-Json)
if ("$version" -eq "") {
    $version = $settings.versions[0].version
    Write-Host "Version not defined, using $version"
}

$imageName = "build"
$property = $settings.PSObject.Properties.Match('imageName')
if ($property.Value) {
    $imageName = $property.Value
}

$property = $settings.PSObject.Properties.Match('bccontainerhelperVersion')
if ($property.Value) {
    $bccontainerhelperVersion = $property.Value
}
else {
    $bccontainerhelperVersion = "latest"
}
Write-Host "Set bccontainerhelperVersion = $bccontainerhelperVersion"
Write-Host "##vso[task.setvariable variable=bccontainerhelperVersion]$bccontainerhelperVersion"

$appFolders = $settings.appFolders
Write-Host "Set appFolders = $appFolders"
Write-Host "##vso[task.setvariable variable=appFolders]$appFolders"

$testFolders = $settings.testFolders
Write-Host "Set testFolders = $testFolders"
Write-Host "##vso[task.setvariable variable=testFolders]$testFolders"

$property = $settings.PSObject.Properties.Match('azureBlob')
if ($property.Value) {
    $branches = $settings.azureBlob.PSObject.Properties.Match('BranchNames')
    if ($branches.Value) {
        if ($branches.Value -icontains $branchName -or $branches.Value -icontains ($branchName.split('/') | Select-Object -Last 1)) {
            Write-Host "Set azureStorageAccount = $($settings.azureBlob.azureStorageAccount)"
            Write-Host "##vso[task.setvariable variable=azureStorageAccount]$($settings.azureBlob.azureStorageAccount)"
            Write-Host "Set azureContainerName = $($settings.azureBlob.azureContainerName)"
            Write-Host "##vso[task.setvariable variable=azureContainerName]$($settings.azureBlob.azureContainerName)"            
        } else {
            Write-Host "Set azureStorageAccount = ''"
            Write-Host "##vso[task.setvariable variable=azureStorageAccount]"        
        }
    } else {
        Write-Host "Set azureStorageAccount = $($settings.azureBlob.azureStorageAccount)"
        Write-Host "##vso[task.setvariable variable=azureStorageAccount]$($settings.azureBlob.azureStorageAccount)"
        Write-Host "Set azureContainerName = $($settings.azureBlob.azureContainerName)"
        Write-Host "##vso[task.setvariable variable=azureContainerName]$($settings.azureBlob.azureContainerName)"            
    }
} else {
    Write-Host "Set azureStorageAccount = ''"
    Write-Host "##vso[task.setvariable variable=azureStorageAccount]"
}

$property = $settings.PSObject.Properties.Match('azureBlobRelease')
if ($property.Value) {
    Write-Host "Set azureReleaseStorageAccount = $($settings.azureBlobRelease.azureStorageAccount)"
    Write-Host "##vso[task.setvariable variable=azureReleaseStorageAccount]$($settings.azureBlobRelease.azureStorageAccount)"
    Write-Host "Set azureReleaseContainerName = $($settings.azureBlobRelease.azureContainerName)"
    Write-Host "##vso[task.setvariable variable=azureReleaseContainerName]$($settings.azureBlobRelease.azureContainerName)"
    }
else {
    Write-Host "Set azureReleaseStorageAccount = ''"
    Write-Host "##vso[task.setvariable variable=azureReleaseStorageAccount]"
    Write-Host "Set azureReleaseContainerName = ''"
    Write-Host "##vso[task.setvariable variable=azureReleaseContainerName]"
}

$imageversion = $settings.versions | Where-Object { $_.version -eq $version }
if ($imageversion) {
    Write-Host "Set artifact = $($imageVersion.artifact)"
    Write-Host "##vso[task.setvariable variable=artifact]$($imageVersion.artifact)"
    
    "reuseContainer" | ForEach-Object {
        $property = $imageVersion.PSObject.Properties.Match($_)
        if ($property.Value) {
            $propertyValue = $property.Value
        }
        else {
            $propertyValue = $false
        }
        Write-Host "Set $_ = $propertyValue"
        Write-Host "##vso[task.setvariable variable=$_]$propertyValue"
    }
    if ($imageVersion.PSObject.Properties.Match("imageName").Value) {
        $imageName = $imageversion.imageName
    }
}
else {
    throw "Unknown version: $version"
}

if ("$($ENV:AGENT_NAME)" -eq "Hosted Agent" -or "$($ENV:AGENT_NAME)" -like "Azure Pipelines*") {
    $containerNamePrefix = ""
    Write-Host "Set imageName = ''"
    Write-Host "##vso[task.setvariable variable=imageName]"
}
else {
    if ($imageName -eq "") {
        $containerNamePrefix = "bld"
    }
    else {
        $containerNamePrefix = "$imageName"
    }
    Write-Host "Set imageName = $imageName"
    Write-Host "##vso[task.setvariable variable=imageName]$imageName"
}
$buildName = $ENV:BUILD_SOURCEBRANCHNAME + $appVersion.Split('.')[2]
$containerName = "$($containerNamePrefix)$("${buildName}$($ENV:AGENT_NAME)" -replace '[^a-zA-Z0-9]', '')".ToUpper()
if ($containerName.Length -gt 15) {
    $containerName = $containerName.Substring(0, 15)
}
Write-Host "Set containerName = $containerName"
Write-Host "##vso[task.setvariable variable=containerName]$containerName"

$testCompanyName = $settings.TestMethod.companyName
Write-Host "Set testCompanyName = $testCompanyName"
Write-Host "##vso[task.setvariable variable=testCompanyName]$testCompanyName"

$testCodeunitId = $settings.TestMethod.CodeunitId
Write-Host "Set testCodeunitId = $testCodeunitId"
Write-Host "##vso[task.setvariable variable=testCodeunitId]$testCodeunitId"

$testMethodName = $settings.TestMethod.MethodName
Write-Host "Set testMethodName = $testMethodName"
Write-Host "##vso[task.setvariable variable=testMethodName]$testMethodName"
