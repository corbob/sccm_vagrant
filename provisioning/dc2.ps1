Add-WindowsFeature -Name "ad-domain-services" -IncludeAllSubFeature -IncludeManagementTools
Add-WindowsFeature -Name "dns" -IncludeAllSubFeature -IncludeManagementTools
Add-WindowsFeature -Name "gpmc" -IncludeAllSubFeature -IncludeManagementTools 

$domainname = "nwtraders.msft"
$netbiosName = "NWTRADERS"
Import-Module ADDSDeployment
$installADDSForestSplat = @{
    CreateDnsDelegation  = $false
    DatabasePath         = "C:\Windows\NTDS"
    DomainMode           = "Win2012"
    DomainName           = $domainname
    DomainNetbiosName    = $netbiosName
    ForestMode           = "Win2012"
    InstallDns           = $true
    LogPath              = "C:\Windows\NTDS"
    NoRebootOnCompletion = $false
    SysvolPath           = "C:\Windows\SYSVOL"
    Force                = $true
}
Install-ADDSForest @installADDSForestSplat
