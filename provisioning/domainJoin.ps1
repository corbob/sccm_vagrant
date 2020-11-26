# "10.0.0.10      contoso.com" | Add-Content 'C:\Windows\System32\drivers\etc\hosts'
$nic = Get-NetIPAddress | Where-Object IPAddress -Like '10.0.0.*'
Set-DnsClientServerAddress -InterfaceIndex $nic.InterfaceIndex -ServerAddresses 10.0.0.10
$secpasswd = ConvertTo-SecureString 'vagrant' -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ('contoso\vagrant', $secpasswd)

Add-Computer -Domain 'contoso' -Credential $Credential
