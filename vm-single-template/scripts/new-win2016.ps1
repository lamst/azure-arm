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

# 3. Setup parameters
$templateName = "azuredeploy.json"
$parameterName = "azuredeploy.parameters.json"

# 4. Validate deployment
Write-Host "Validating deployment..."
Test-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroup -TemplateFile ("..\" + $templateName) -TemplateParameterFile ("..\" + $parameterName)

# 5. Deploy the resources
Write-Host "Deploying resources..."
New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroup -Name "temp-vm-deploy" -TemplateFile ("..\" + $templateName) -TemplateParameterFile ("..\" + $parameterName)