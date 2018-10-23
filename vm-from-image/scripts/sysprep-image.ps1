$vmName = 'temp-vm2'
$resourceGroupName = 'temp-rg'
$extensionName = 'sysprep-ext'
$scriptUri = 'https://raw.githubusercontent.com/lamst/azure-arm/master/vm-from-image/scripts/prep-vm.ps1'

# Retrieve the VM to run SysPrep
Write-Host 'Retrieving VM...'
$vm = Get-AzureRmVm -ResourceGroupName $resourceGroupName -Name $vmName -ErrorAction SilentlyContinue
if ($null -eq $vm) {
    Write-Host "The VM does not exist."
    exit 1
}

# Run custom script on VM
Write-Host 'Running sysprep on VM...'
Set-AzureRmVMCustomScriptExtension -FileUri $scriptUri -ResourceGroupName $resourceGroupName -VMName $vmName -Name $extensionName -Location $vm.Location -Run 'prep-vm.ps1'

# Retrieve status of the extension
$status = Get-AzureRmVMDiagnosticsExtension -ResourceGroupName $resourceGroupName -VMName $vmName -Name $extensionName -Status
$output = $status.SubStatuses[0].Message
$output.Replace( "\n", "`n")

# Retrieve the power state of the virtual machine
$vmStatus = Get-AzureRmVm -ResourceGroupName $resourceGroupName -Name $vmName -Status
$powerState = $vmStatus.Statuses[1].Code.Split('/')[1]
while ($powerState -ne 'stopped') {
    Write-Host 'Waiting for VM to be stopped...'
    Start-Sleep 5
    $vmStatus = Get-AzureRmVm -ResourceGroupName $resourceGroupName -Name $vmName -Status
    $powerState = $vmStatus.Statuses[1].Code.Split('/')[1]
}
Write-Host 'VM is Stopped.'