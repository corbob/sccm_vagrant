$null = Add-WindowsFeature "RSAT-AD-Tools"
$null = Add-WindowsFeature -Name "ad-domain-services" -IncludeAllSubFeature -IncludeManagementTools
$null = Add-WindowsFeature -Name "dns" -IncludeAllSubFeature -IncludeManagementTools
$null = Add-WindowsFeature -Name "gpmc" -IncludeAllSubFeature -IncludeManagementTools 

$domainname = "contoso.com"
$netbiosName = "CONTOSO"
$secpasswd = ConvertTo-SecureString 'Vagrant12345' -AsPlainText -Force
Import-Module ADDSDeployment
$installADDSForestSplat = @{
    CreateDnsDelegation           = $false
    DatabasePath                  = "C:\Windows\NTDS"
    DomainMode                    = "Win2012R2"
    DomainName                    = $domainname
    DomainNetbiosName             = $netbiosName
    ForestMode                    = "Win2012R2"
    InstallDns                    = $true
    LogPath                       = "C:\Windows\NTDS"
    NoRebootOnCompletion          = $false
    SysvolPath                    = "C:\Windows\SYSVOL"
    Force                         = $true
    SafeModeAdministratorPassword = $secpasswd
}
Install-ADDSForest @installADDSForestSplat
