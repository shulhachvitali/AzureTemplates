Login-AzureRmAccount

Select-AzureRmSubscription -Subscription "Subscription's id"

# PARAMETERS BLOCK

$ErrorActionPreference = "stop"
$ResourceGroupName = "Resiurce Group Name"
$location1 = "Location" # Location for storage with scenarios  
$serviceGroup = "Service Resource Group" # Service resource group, contains the scenarios  
$serviceStorageAcc = "Service storage account" # Storage account for service purposes
$storageContainerName = "Container name" # Container for service scripts
$location2 = "Location for main resources stack"
$PathToJson = Get-Item "$PSScriptRoot\MainTemplate.json"
$pathToDSC = Get-Item "$PSScriptRoot\DSC_DefaultWebSite.ps1"
$pathtoparams = Get-Item "$PSScriptRoot\SecParams.json"

################################################################################

#step 1 - creating storage account for placing service sources

Write-Output "Uploading DSC configuration file to Azure storage"
Write-Output "Check for service resource group existing"

if (!(Get-AzureRmResourceGroup $serviceGroup -ErrorAction SilentlyContinue))
{
    New-AzureRmResourceGroup -Name $serviceGroup -Location $location1
    Write-Output "Resource Group $serviceGroup, created in the $location1 region"
}

Write-Output "Check for storage account existing"

if (!(Get-AzureRmStorageAccount -StorageAccountName $serviceStorageAcc -ResourceGroupName $serviceGroup -ErrorAction SilentlyContinue))
{
    New-AzureRmStorageAccount -ResourceGroupName $serviceGroup -Name $serviceStorageAcc -Type Standard_LRS -Location $location1 -Kind Storage -Verbose
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $serviceGroup -Name $serviceStorageAcc -Verbose
    Write-Output "New storage account - $serviceStorageAcc - was created"
}
else 
{
Set-AzureRmCurrentStorageAccount -ResourceGroupName $serviceGroup -Name $serviceStorageAcc -Verbose
}

Write-Output "Check for blob container existing"
if (!(Get-AzureStorageBlob -Container $storageContainerName -ErrorAction SilentlyContinue))
{
    New-AzureStorageContainer -Name $storageContainerName -Permission Container -Verbose
    Publish-AzureRmVMDscConfiguration -ResourceGroupName $serviceGroup -ConfigurationPath $pathToDSC.FullName -ContainerName $storageContainerName -StorageAccountName $serviceStorageAcc
}
Else 
{
Publish-AzureRmVMDscConfiguration -ResourceGroupName $serviceGroup -ConfigurationPath $pathToDSC.FullName -ContainerName $storageContainerName -StorageAccountName $serviceStorageAcc -Force
Write-Output "file with DSC config - $($pathToDSC.Name) - was uploaded"
}
Write-Output "Creating SAS token URI for DSC"
$ModuleName = $pathToDSC.Name + ".zip"
$templateuri = New-AzureStorageBlobSASToken -Container $storageContainerName -Blob $($ModuleName) -Permission r `
  -ExpiryTime (Get-Date).AddHours(2.0) -FullUri

$paramDSC = (Get-Content $pathtoparams.FullName |Select-String -Pattern "DSCModuleUrl")
$replacementItem = ($paramDSC.ToString()).Trim()
$toreplace = '"DSCModuleUrl":'+'"'+$templateuri+'",'
$newFile = (Get-Content $pathtoparams.FullName).Replace("$replacementItem","$toreplace")
$newFile | Out-File $pathtoparams.FullName

Write-Output "Creating SAS token for Parameters"
Set-AzureStorageBlobContent -Container $storageContainerName -File $($pathtoparams.FullName) -Force -Verbose
$secparams = New-AzureStorageBlobSASToken -Container $storageContainerName -Blob $($pathtoparams.Name) -Permission r `
  -ExpiryTime (Get-Date).AddHours(2.0) -FullUri
################################################################################
Write-Output "Starting Deployment"
if (!(Get-AzureRmResourceGroup $ResourceGroupName -ErrorAction SilentlyContinue))
{
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location2
}
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
  -TemplateFile $PathToJson.FullName -SecTemplate $secparams -Debug 
<#
Remove-AzureRmResourceGroup -Name $ResourceGroupName -Force -Verbose
Remove-AzureRmResourceGroup -Name $serviceGroup -Force -Verbose
#>