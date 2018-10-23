# Parameters
Param(
    # The name of the image
    [Parameter(Mandatory=$true)]
    [string] $ImageName,
    
    # The name of the virtual machine to create the image from
    [Parameter(Mandatory=$true)]
    [string] $VmName,

    # The name of the resource group
    [Parameter(Mandatory=$true)]
    [string] $ResourceGroupName,

    # The location to store the custom image
    [string] $Location = 'Southeast Asia'
)

$Location = 'Southeast Asia'
$ExtensionName = 'sysprep-ext'
$ScriptUri = 'https://raw.githubusercontent.com/lamst/azure-arm/master/vm-from-image/scripts/prep-vm.ps1'

# Retrieve the VM to run SysPrep
Write-Host 'Retrieving VM...'
$vm = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction SilentlyContinue
if ($null -eq $vm) {
    Write-Host "The VM does not exist."
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
    Write-Host 'Waiting for VM to be stopped...'
    Start-Sleep 10
    $vmStatus = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $VmName -Status
    $powerState = $vmStatus.Statuses[1].Code.Split('/')[1]
}
Write-Host 'VM is Stopped.'

# Deallocate the VM
Write-Host 'Deallocating VM...'
Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VmName -Force

# Set the status of the VM to -Generalized
Set-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VmName -Generalized

# Create a generalized image from the VM
Write-Host 'Creating generalized image...'
$vm = Get-AzureRmVM -Name $VmName -ResourceGroupName $ResourceGroupName
$imageConfig = New-AzureRmImageConfig -Location $Location -SourceVirtualMachineId $vm.Id
$image = New-AzureRmImage -Image $imageConfig -ImageName $ImageName -ResourceGroupName $ResourceGroupName

Write-Host "-------------------------"
Write-Host "Resource Id: " + $image.Id