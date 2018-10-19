# Parameters
$vmName = 'temp-vm1'
$resourceGroupName = 'temp-rg'
$location = 'Southeast Asia'
$imageName = 'win2016-lamst'

# Deallocate the VM
Write-Host 'Stopping VM...'
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName -Force

# Set the status of the VM to -Generalized
Set-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName -Generalized

# Create a generalized image from the VM
Write-Host 'Creating generalized image...'
$vm = Get-AzureRmVM -Name $vmName -ResourceGroupName $resourceGroupName
$imageConfig = New-AzureRmImageConfig -Location $location -SourceVirtualMachineId $vm.Id
$image = New-AzureRmImage -Image $imageConfig -ImageName $imageName -ResourceGroupName $resourceGroupName

Write-Host "-------------------------"
Write-Host "Resource Id: " + $image.Id