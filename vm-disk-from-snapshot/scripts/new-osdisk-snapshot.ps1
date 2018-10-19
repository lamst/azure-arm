$resourceGroupName = 'temp-rg'
$location = 'southeastasia'
$vmName = 'temp-vm1'
$snapshotName = 'temp-vm1-osdisk-ss'
$osDiskName = 'win2016-osdisk'

# Retrieve the VM to snapshot the OS disk
$vm = Get-AzureRmVm -ResourceGroupName $resourceGroupName -Name $vmName

# Take snapshot of the OS disk
$snapshotConfig = New-AzureRmSnapshotConfig -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption Copy
$snapshot = New-AzureRmSnapshot -Snapshot $snapshotConfig -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName

# Convert the snapshot to a disk
$diskConfig = New-AzureRmDiskConfig -Location $snapshot.Location -SourceResourceId $snapshot.Id -CreateOption Copy
$disk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $resourceGroupName -DiskName $osDiskName

Write-Host "Resource Id: " + $disk.Id