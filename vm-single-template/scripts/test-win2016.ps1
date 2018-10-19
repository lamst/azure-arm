# 1. Login: 
# Connect-AzureRmAccount

# 2. Create resource group:
$resourceGroup = "temp-rg"
Get-AzureRmResourceGroup -Name $resourceGroup -ErrorVariable notExist -ErrorAction SilentlyContinue
if ($notExist)
{
    Write-Host "Creating resource group..."
    New-AzureRmResourceGroup -Name $resourceGroup -Location "Southeast Asia"
}

# 2. Setup parameters
$templateName = "azuredeploy.json"
$parameterName = "azuredeploy.parameters.json"

# 3. Test
Write-Host "Validating deployment..."
Test-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroup -TemplateFile ("..\" + $templateName) -TemplateParameterFile ("..\" + $parameterName)

#4. Delete resource group
Get-AzureRmResourceGroup -Name $resourceGroup -ErrorVariable notExist -ErrorAction SilentlyContinue
if (-Not $notExist)
{
    Write-Host "Deleting resource group..."
    Remove-AzureRmResourceGroup -Name $resourceGroup -Force
}