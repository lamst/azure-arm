# Install modules to update Windows
Install-Module PSWindowsUpdate -Confirm:$false -Force:$true
Get-WUInstall –MicrosoftUpdate –AcceptAll

# Generalize the VM
$sysprepPath = $env:windir + '\System32\Sysprep\sysprep.exe'
Start-Process -FilePath $sysprepPath -ArgumentList ("/oobe /shutdown /generalize /quiet") -Wait -NoNewWindow