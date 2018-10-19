$vmName = 'temp-vm1'
$resourceGroupName = 'temp-rg'
$extensionName = 'sysprep-ext'
$scriptUri = 'https://raw.githubusercontent.com/lamst/azure-arm/master/vm-from-image/scripts/sysprep-vm.ps1'

# Retrieve the VM to run SysPrep
Write-Host 'Retrieving VM...'
$vm = Get-AzureRmVm -ResourceGroupName $resourceGroupName -Name $vmName

# Run custom script on VM
Write-Host 'Running sysprep on VM...'
Set-AzureRmVMCustomScriptExtension -FileUri $scriptUri -ResourceGroupName $resourceGroupName -VMName $vmName -Name $extensionName -Location $vm.Location -Run './sysprep-vm.ps1'

# Retrieve status of the extension
$status = Get-AzureRmVMDiagnosticsExtension -ResourceGroupName $resourceGroupName -VMName $vmName -Name $extensionName -Status
Write-Host 'Status: ' + $status.SubStatuses.message