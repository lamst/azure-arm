# Parameters
Param(
    # The name of the image
    [Parameter(Mandatory=$true)]
    [string] $NewImageName,
    
    # The name of the virtual machine to create the image from
    [Parameter(Mandatory=$true)]
    [string] $VmName,

    # The name of the resource group
    [Parameter(Mandatory=$true)]
    [string] $ResourceGroupName,

    # The location to store the custom image
    [string] $Location = 'Southeast Asia'
)

$TemplateName = "azuredeploy.json"
$ParameterName = "azuredeploy.parameters.json"
$ExtensionName = 'sysprep-ext'
$ScriptUri = 'https://raw.githubusercontent.com/lamst/azure-arm/master/vm-from-image/scripts/prep-vm.ps1'

# Deploy VM from a previous image
Write-Host "Deploying resources..."
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name "image-vm-deploy" -TemplateFile ("..\" + $TemplateName) -TemplateParameterFile ("..\" + $ParameterName)

# Retrieve reference to the VM deployed
Write-Host "Retrieving VM..."
$vm = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction SilentlyContinue
if ($null -eq $vm) {
    Write-Host "The virtual machine does not exist."
    exit 1
}

# Infer location of the image from the virtual machine
if ([string]::IsNullOrEmpty($Location)) {
    $Location = $vm.Location
}

# Run custom script on VM
Write-Host 'Running sysprep on VM...'
Set-AzureRmVMCustomScriptExtension -FileUri $ScriptUri -ResourceGroupName $ResourceGroupName -VmName $VmName -Name $ExtensionName -Location $vm.Location -Run 'prep-vm.ps1'

# Wait for the extension to be provisioned
$status = Get-AzureRmVMDiagnosticsExtension -ResourceGroupName $ResourceGroupName -VmName $VmName -Name $ExtensionName -Status
$provisioningState = $status.ProvisioningState
while ($provisioningState -ne 'succeeded') {
    Write-Host 'Provisioning extension...'
    Start-Sleep 10
    $status = Get-AzureRmVMDiagnosticsExtension -ResourceGroupName $ResourceGroupName -VmName $VmName -Name $ExtensionName -Status
    $provisioningState = $status.ProvisioningState
}

# Wait for the custom script to ccomplete execution
$status = Get-AzureRmVMDiagnosticsExtension -ResourceGroupName $ResourceGroupName -VmName $VmName -Name $ExtensionName -Status
$displayStatus = $status.Statuses[0].DisplayStatus
while ($displayStatus -eq 'transitioning') {
    Write-Host 'Executing script...'
    Start-Sleep 10
    $status = Get-AzureRmVMDiagnosticsExtension -ResourceGroupName $ResourceGroupName -VmName $VmName -Name $ExtensionName -Status
    $displayStatus = $status.Statuses[0].DisplayStatus
}

$output = $status.SubStatuses[0].Message
if ($output) {
    $output.Replace( "\n", "`n")
}

# Retrieve the power state of the virtual machine
$vmStatus = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $VmName -Status
$powerState = $vmStatus.Statuses[1].Code.Split('/')[1]
while ($powerState -ne 'stopped') {
    Write-Host 'Stopping VM...'
    Start-Sleep 10
    $vmStatus = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $VmName -Status
    $powerState = $vmStatus.Statuses[1].Code.Split('/')[1]
}

# Deallocate the VM
Write-Host 'Deallocating VM...'
Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VmName -Force

# Set the status of the VM to -Generalized
Set-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VmName -Generalized

# Create a generalized image from the VM
Write-Host 'Creating generalized image...'
$vm = Get-AzureRmVM -Name $VmName -ResourceGroupName $ResourceGroupName
$imageConfig = New-AzureRmImageConfig -Location $location -SourceVirtualMachineId $vm.Id
$image = New-AzureRmImage -Image $imageConfig -ImageName $NewImageName -ResourceGroupName $ResourceGroupName

Write-Host "-------------------------"
Write-Host "Resource Id: " + $image.Id

# Cleanup resources
Write-Host 'Removing VM...'
Remove-AzureRmVm -Name $VmName -ResourceGroupName $ResourceGroupName -Confirm:$false -Force:$true
Write-Host 'Removing network interface...'
Remove-AzureRmNetworkInterface -Name ($VmName + "-nic1009") -ResourceGroupName $ResourceGroupName -Confirm:$false -Force:$true
Write-Host 'Removing disk...'
Remove-AzureRmDisk -DiskName ($VmName + "-osdisk") -ResourceGroupName $ResourceGroupName -Confirm:$false -Force:$true