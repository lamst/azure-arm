# Install modules to update Windows
Import-Module PSWindowsUpdate -Confirm:$false -Force:$true
Get-WindowsUpdate
Install-WindowsUpdate -Confirm:$false