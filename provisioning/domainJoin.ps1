"10.0.0.10      contoso.com" | Add-Content 'C:\Windows\System32\drivers\etc\hosts'

$secpasswd = ConvertTo-SecureString 'vagrant' -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ('vagrant', $secpasswd)

Add-Computer -Domain 'contoso.com' -Credential $Credential
