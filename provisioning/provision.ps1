# Files directory can be used as storage for some of the files used so you don't need to download them every time...
Write-Host "Copying files to root of C:\"
robocopy C:\vagrant\files c:\ConfigMgrFiles /mir

Write-Host "Done copying files to root of C:\"

# Install Chocolatey... Because Chocolatey!!!
Write-Host "Installing Chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -Value 1 -PropertyType "DWord" -Force | Out-Null
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
Write-Host "Done Installing Chocolatey"

# # Set PSGallery to trusted so we can install the SQL Server module.
# Write-Host "Install SQLServer PS Module"
# Set-PSRepository PSGallery -InstallationPolicy Trusted
# Install-Module sqlserver
# Write-Host "Done Install SQLServer PS Module"

# Install all the Features needed for all the things...
Write-Host "Installing ALL the things!"
Install-WindowsFeature BITS, BITS-IIS-Ext, Web-Windows-Auth, web-ISAPI-Ext, Web-WMI, Web-Metabase, Rdc, Net-Framework-Core,RSAT-AD-Tools,ad-domain-services,dns, gpmc -IncludeAllSubFeature -IncludeManagementTools 
Write-Host "Finally done Installing ALL the things!"

# Disable the firewall because it's easier this way...
Set-NetFirewallProfile -All -Enabled False
