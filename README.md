# Build Template for Business Central
- Based on the HelloWorld sample from @freddydk 
- https://dev.azure.com/businesscentralapps/HelloWorld

# Getting Started
1.	For a basic CI/CD flow add Current.yml to your respository
1.  For a more advanced CI/CD flow add Release.yml to your repository
2.  If you plan to use Insider Builds add NextMinor.yml, NextMinor.yml to your repository
2.  If you plan to use build validation add Current-Validation.yml to your repository
2.	Add Variable Library for Build parameters
    - BuildVariables
        - CodeSignPfxFile (optional for signing the apps)
        - CodeSignPfxPassword (optional for signing the apps)
        - LicenseFile
        - TestLicenseFile (optional if unit tests require development license and build is using customer license)
        - Password
        - ClientId (optional for online tenant deployment)
        - ClientSecret (optional for online tenant deployment)
        - PowerShellUsername (optional for powershell deployment)
        - PowerShellPassword (optional for powershell deployment)
    - InsiderBuilds
        - InsiderSasToken
3.	Create DevOps pipelines

# Current.yml
This pipeline will trigger automatically when changes are done to the main branch.
# Release.yml
This pipeline will not trigger automatically, it needs to be triggered manually. You will get the choice to select a build form your CI pipeline when executing.
# Build validation
If pipeline is setup as a validation pipeline deployment and artifact publishing is skipped, only unit tests are executed.
To setup a Build validation pipeline specify true for parameter validationBuild in your validation pipeline taml.

## Setup build validation for branch
1. Go to branch policies
2. Add Build Validation
3. Specify your validation pipeline
   
# Service Connection
Create a service connection to GitHub and update the endpoint
-  https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml

# Azure Blob
To upload artifacts to Azure Blob container
-  Create service connection to your Azure Blob subscription using Azure Resource Manager and recomended options.
-  Creates a service principal in Azure Active Directory based on DevOps organization, project and Azure Subscription Id.
-  Add Role Assignment "Storage Blob Data Contributor" to Azure Storage Account 
-  Add Service connection Name as azureSubscription in Current.yml file.
-  Add Storage Account and Container name to build-settings.json

# Build Agent
Build Agent must have Docker and Azure compatibility
- Install-Module AZ

# Update AzCopy.exe
- $AzCopyLocation = Get-ChildItem -Path $env:SystemDrive -Filter azcopy.exe -Recurse -ErrorAction SilentlyContinue| Select-Object -First 1
- Invoke-WebRequest -Uri https://aka.ms/downloadazcopy-v10-windows -OutFile ~\Downloads\azcopy.zip
- Unblock-File ~\Downloads\azcopy.zip
- Expand-Archive ~\Downloads\azcopy.zip -DestinationPath ~\Downloads\azcopy -Force
- Copy-Item ~\Downloads\azcopy\*\azcopy.exe $AzCopyLocation -Force
- Remove-Item ~\Downloads\azcopy -Recurse -Force

