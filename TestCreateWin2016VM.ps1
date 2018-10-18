# 1. Login: 
# Connect-AzureRmAccount

# 2. Create resource group:
$resourceGroup = "temp-rg"
Get-AzureRmResourceGroup -Name $resourceGroup -ErrorVariable notExist -ErrorAction SilentlyContinue
if ($notExist)
{
    New-AzureRmResourceGroup -Name $resourceGroup -Location "Southeast Asia"
}

# 2. Setup parameters
$templateName = "CreateVMTemplate.json"
$parameterName = "Parameters.json"

# 3. Test
Test-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroup -TemplateFile (".\" + $templateName) -TemplateParameterFile (".\" + $parameterName)

#4. Delete resource group
Get-AzureRmResourceGroup -Name $resourceGroup -ErrorVariable notExist -ErrorAction SilentlyContinue
if (-Not $notExist)
{
    Remove-AzureRmResourceGroup -Name $resourceGroup -Force
}