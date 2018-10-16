# 1. Login: 
# Connect-AzureRmAccount

# 2. Get a list of available locations: 
# Get-AzureRmLocation | sort DisplayName | Select DisplayName

# 3. Create resource group: 
$resourceGroup = "temp-rg"
Get-AzureRmResourceGroup -Name $resourceGroup -ErrorVariable notExist -ErrorAction SilentlyContinue
if ($notExist)
{
    New-AzureRmResourceGroup -Name $resourceGroup -Location "Southeast Asia"
}

# 4. Specifies the storage account:
$storageName = "tempdemodata001"
New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageName -Location "Southeast Asia" -SkuName Standard_LRS

# 5. Create the BLOB container:
$containerName = "templates"
New-AzureRmStorageContainer -ResourceGroupName $resourceGroup -StorageAccountName $storageName -Name $containerName -PublicAccess Container

# 6. Upload template files to storage account
$templateName = "CreateVMTemplate.json"
$parameterName = "Parameters.json"
$accountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroup -Name $storageName).Value[0]
$context = New-AzureStorageContext -StorageAccountName $storageName -StorageAccountKey $accountKey 
Set-AzureStorageBlobContent -File (".\" + $templateName) -Container $containerName -Blob $templateName -Context $context
Set-AzureStorageBlobContent -File (".\" + $parameterName) -Container $containerName -Blob $parameterName -Context $context

# 7. Test the resources
$templatePath = "https://" + $storageName + ".blob.core.windows.net/" + $containerName + "/" + $templateName
$parametersPath = "https://" + $storageName + ".blob.core.windows.net/" + $containerName + "/" + $parameterName
Test-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroup -TemplateUri $templatePath -TemplateParameterUri $parametersPath

# 8. Deploy the resources
# New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroup -Name "temp-vm-deploy" -TemplateUri $templatePath -TemplateParameterUri $parametersPath