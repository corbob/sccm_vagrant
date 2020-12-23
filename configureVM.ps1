. $PSScriptRoot\provisioning\funcs.ps1

Write-Msg "Stand up the vagrant box"
vagrant up
Write-Msg "We are going to install AD on the server. This **WILL** result in an exception... We will be ignoring it."

vagrant winrm -e -c '& c:\vagrant\provisioning\dcpromo.ps1'
Write-Msg "The domain install is done. Getting some files and then waiting until the DC is fully rebooted."
# The DC Promo will take about 3 minutes to reboot after DC Promo. We're going to go and get files if we need them, then wait for a total of 10 minutes because the first test 5  wasn't long enough...
$CurrentTime = Get-Date
& $PSScriptRoot\Get-Files.ps1
$howLong = New-TimeSpan -Start $CurrentTime -End (Get-Date)
if($howLong.TotalSeconds -lt 600){
    Write-Msg "That only took $($howLong.TotalSeconds) seconds. Waiting longer."
    Start-Sleep -Seconds (600 - $howLong.TotalSeconds)
}

Write-Msg "Reboot the VM because reasons..."

vagrant reload

Write-Msg "Starting install of SCCM. This will be a while."

vagrant winrm -e -c '& C:\vagrant\provisioning\InstallAndUpdateSCCM.ps1'
Write-Msg "We're finally done! You will need to launch the Admin Console and update it, as we haven't found a way to automate that update just yet."
