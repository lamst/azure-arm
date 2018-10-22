# Install modules to update Windows
Install-PackageProvider -Name "Nuget" -Force:$true -Confirm:$false
Install-Module PSWindowsUpdate -Confirm:$false -Force:$true -SkipPublisherCheck:$true -Scope AllUsers
Get-WUInstall -WindowsUpdate -AcceptAll -IgnoreReboot -Confirm:$false -ErrorAction Stop
# Generalize the VM
$sysprepPath = $env:windir + '\System32\Sysprep\sysprep.exe'
Start-Process -FilePath $sysprepPath -ArgumentList ("/oobe /shutdown /generalize /quiet")