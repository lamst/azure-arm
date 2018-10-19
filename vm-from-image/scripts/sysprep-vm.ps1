# Generalize the VM
$sysprepPath = $env:windir + '\System32\Sysprep\sysprep.exe'
Start-Process -FilePath $sysprepPath -ArgumentList ("/oobe /shutdown /generalize /quiet") -Wait -NoNewWindow