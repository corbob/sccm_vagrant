$buildStart = Get-Date
$DomainFullName = "contoso.com"
$CM = "CMCB"
$CMUser = "contoso\vagrant"
$Role = "PS1"

. $PSScriptRoot\funcs.ps1

#region AD Configuration
Write-Msg "Setting up AD for Configuration Manager"
$root = (Get-ADRootDSE).defaultNamingContext
$ou = $null 
try { 
    $ou = Get-ADObject "CN=System Management,CN=System,$root"
} 
catch { 
    Write-Verbose "System Management container does not currently exist."
}
if ($null -eq $ou) { 
    $ou = New-ADObject -Type Container -name "System Management" -Path "CN=System,$root" -Passthru 
}
$DomainName = 'contoso'
#Delegate Control
$cmd = "dsacls.exe"
$arg1 = "CN=System Management,CN=System,$root"
$arg2 = "/G"
$arg3 = "" + $DomainName + "\" + $env:computername + "`$:GA;;"
$arg4 = "/I:T"

& $cmd $arg1 $arg2 $arg3 $arg4
#endregion

#region Prerequisites

# Files directory can be used as storage for some of the files used so you don't need to download them every time...
Write-Msg "Copying files to root of C:\"
robocopy C:\vagrant\files c:\ConfigMgrFiles /mir
# Start with SQL Server Installation.
Write-Msg "Installing SQL Server 2019"
choco install sql-server-2019 -y --params="'/TCPENABLED=`"1`" /IsoPath:c:\ConfigMgrFiles\sql.iso'"

$_adkpath = 'C:\ConfigMgrFiles\adk.exe'
$_adkWinPEpath = 'C:\ConfigMgrFiles\winpe.exe'
if (!(Test-Path $_adkpath)) {
    Write-Msg "Downloading ADK"
    $adkurl = "https://go.microsoft.com/fwlink/?linkid=2120254"
    Invoke-WebRequest -Uri $adkurl -OutFile $_adkpath
}
if (!(Test-Path $_adkWinPEpath)) {
    Write-Msg "Downloading Windows PE"
    $adkurl = "https://go.microsoft.com/fwlink/?linkid=2120253"
    Invoke-WebRequest -Uri $adkurl -OutFile $_adkWinPEpath
}

#region Install DeploymentTools
Write-Msg "Installing ADK"
$adkinstallpath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools"
while (!(Test-Path $adkinstallpath)) {
    $cmd = $_adkpath
    $arg1 = "/Features"
    $arg2 = "OptionId.DeploymentTools"
    $arg3 = "/q"
    
    try {
        Write-Verbose "Installing ADK DeploymentTools..."
        & $cmd $arg1 $arg2 $arg3 | out-null
        Write-Verbose "ADK DeploymentTools Installed Successfully!"
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        throw "Failed to install ADK DeploymentTools with below error: $ErrorMessage"
    }
    
    Start-Sleep -Seconds 10
}

#endregion

#region Install UserStateMigrationTool
$adkinstallpath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\User State Migration Tool"
Write-Msg "Installing USMT"
while (!(Test-Path $adkinstallpath)) {
    $cmd = $_adkpath
    $arg1 = "/Features"
    $arg2 = "OptionId.UserStateMigrationTool"
    $arg3 = "/q"
    
    try {
        Write-Verbose "Installing ADK UserStateMigrationTool..."
        & $cmd $arg1 $arg2 $arg3 | out-null
        Write-Verbose "ADK UserStateMigrationTool Installed Successfully!"
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        throw "Failed to install ADK UserStateMigrationTool with below error: $ErrorMessage"
    }
    
    Start-Sleep -Seconds 10
}

#endregion

#region Install WindowsPreinstallationEnvironment
$adkinstallpath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
Write-Msg "Installing WinPE"
while (!(Test-Path $adkinstallpath)) {
    $cmd = $_adkWinPEpath
    $arg1 = "/Features"
    $arg2 = "OptionId.WindowsPreinstallationEnvironment"
    $arg3 = "/q"
    
    try {
        Write-Verbose "Installing WindowsPreinstallationEnvironment for ADK..."
        & $cmd $arg1 $arg2 $arg3 | out-null
        Write-Verbose "WindowsPreinstallationEnvironment for ADK Installed Successfully!"
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        throw "Failed to install WindowsPreinstallationEnvironment for ADK with below error: $ErrorMessage"
    }
    
    Start-Sleep -Seconds 10
}

#endregion

#endregion

$SMSInstallDir = "C:\Program Files\Microsoft Configuration Manager"

$cmpath = "C:\ConfigMgrFiles\$CM.exe"
$cmsourcepath = "c:\$CM"
if (!(Test-Path $cmpath)) {
    Write-Msg "Downloading SCCM installation source..."
    $cmurl = "https://go.microsoft.com/fwlink/?linkid=2093192"
    Invoke-WebRequest -Uri $cmurl -OutFile $cmpath
}
Write-Msg "SCCM Installation source downloaded."
if (!(Test-Path $cmsourcepath)) {
    Start-Process -Filepath ($cmpath) -ArgumentList ('/Auto "' + $cmsourcepath + '"') -wait
}
$CMINIPath = "c:\$CM\Standalone.ini"
Write-Msg "Installing WinPE"
Write-Msg "Check ini file."

$cmini = @'
[Identification]
Action=InstallPrimarySite

[Options]
ProductID=EVAL
SiteCode=%Role%
SiteName=%Role%
SMSInstallDir=%InstallDir%
SDKServer=%MachineFQDN%
RoleCommunicationProtocol=HTTPorHTTPS
ClientsUsePKICertificate=0
PrerequisiteComp=0
PrerequisitePath=C:\%CM%\REdist
MobileDeviceLanguage=0
AdminConsole=1
JoinCEIP=0

[SQLConfigOptions]
SQLServerName=%SQLMachineFQDN%
DatabaseName=%SQLInstance%CM_%Role%
SQLSSBPort=4022
SQLDataFilePath=%SQLDataFilePath%
SQLLogFilePath=%SQLLogFilePath%

[CloudConnectorOptions]
CloudConnector=1
CloudConnectorServer=%MachineFQDN%
UseProxy=0
ProxyName=
ProxyPort=

[SystemCenterOptions]
SysCenterId=

[HierarchyExpansionOption]
'@
$inst = (get-itemproperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances[0]
$p = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').$inst

$sqlinfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$p\$inst"

Write-Msg "ini file exist."
$cmini = $cmini.Replace('%InstallDir%', $SMSInstallDir)
$cmini = $cmini.Replace('%MachineFQDN%', "$env:computername.$DomainFullName")
$cmini = $cmini.Replace('%SQLMachineFQDN%', "$env:computername.$DomainFullName")
$cmini = $cmini.Replace('%Role%', $Role)
$cmini = $cmini.Replace('%SQLDataFilePath%', $sqlinfo.DefaultData)
$cmini = $cmini.Replace('%SQLLogFilePath%', $sqlinfo.DefaultLog)
$cmini = $cmini.Replace('%CM%', $CM)

if (!(Test-Path C:\$CM\Redist)) {
    New-Item C:\$CM\Redist -ItemType directory | Out-Null
}
    
if ($inst.ToUpper() -eq "MSSQLSERVER") {
    $cmini = $cmini.Replace('%SQLInstance%', "")
}
else {
    $tinstance = $inst.ToUpper() + "\"
    $cmini = $cmini.Replace('%SQLInstance%', $tinstance)
}
$CMInstallationFile = "c:\$CM\SMSSETUP\BIN\X64\Setup.exe"
$cmini > $CMINIPath  

$_SQLInstanceName = $inst
$query = "Name = '" + $_SQLInstanceName.ToUpper() + "'"
$services = Get-WmiObject win32_service -Filter $query

if ($services.State -eq 'Running') {
    #Check if SQLSERVERAGENT is running
    $sqlserveragentflag = 0
    $sqlserveragentservices = Get-WmiObject win32_service -Filter "Name = 'SQLSERVERAGENT'"
    if ($null -ne $sqlserveragentservices) {
        if ($sqlserveragentservices.State -eq 'Running') {
            Write-Msg "SQLSERVERAGENT need to be stopped first"
            $Result = $sqlserveragentservices.StopService()
            Write-Msg " Stopping SQLSERVERAGENT.."
            if ($Result.ReturnValue -eq '0') {
                $sqlserveragentflag = 1
                Write-Msg " Stopped"
            }
        }
    }
    $Result = $services.StopService()
    Write-Msg " Stopping SQL Server services.."
    if ($Result.ReturnValue -eq '0') {
        Write-Msg " Stopped"
    }

    Write-Msg " Changing the services account..."
            
    $Result = $services.change($null, $null, $null, $null, $null, $null, "LocalSystem", $null, $null, $null, $null) 
    if ($Result.ReturnValue -eq '0') {
        Write-Msg " Successfully Change the services account"
        if ($sqlserveragentflag -eq 1) {
            Write-Msg " Starting SQLSERVERAGENT.."
            $Result = $sqlserveragentservices.StartService()
            if ($Result.ReturnValue -eq '0') {
                Write-Msg " Started"
            }
        }
        $Result = $services.StartService()
        Write-Msg " Starting SQL Server services.."
        while ($Result.ReturnValue -ne '0') {
            $returncode = $Result.ReturnValue
            Write-Msg " Return $returncode , will try again"
            Start-Sleep -Seconds 10
            $Result = $services.StartService()
        }
        Write-Msg " Started"
    }
}

#endregion

Write-Msg "Installing ConfigMgr..."
Start-Process -Filepath ($CMInstallationFile) -ArgumentList ('/NOUSERINPUT /script "' + $CMINIPath + '"') -wait
# Start-Process -Filepath ($CMInstallationFile) -ArgumentList ('/script "' + $CMINIPath + '"') -wait

Write-Msg "Finished installing CM."

# Remove-Item $CMINIPath


#Upgrade SCCM

Start-Sleep -Seconds 120
$SiteCode = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\SMS\Identification' -Name 'Site Code'

$ProviderMachineName = $env:COMPUTERNAME + "." + $DomainFullName # SMS Provider machine name

# Customizations
$initParams = @{}
if ($null -eq $ENV:SMS_ADMIN_UI_PATH) {
    $ENV:SMS_ADMIN_UI_PATH = "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\i386"
}

# Import the ConfigurationManager.psd1 module 
if ($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
}

# Connect to the site's drive if it is not already present
Write-Msg "Setting PS Drive..."
New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams

while ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    Write-Msg "Retry in 10s to set PS Drive. Please wait."
    Start-Sleep -Seconds 10
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

#Add domain user as CM administrative user

$upgradingfailed = $false
$originalbuildnumber = ""

#Wait for SMS_DMP_DOWNLOADER running
$key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
$subKey = $key.OpenSubKey("SOFTWARE\Microsoft\SMS\Components\SMS_Executive\Threads\SMS_DMP_DOWNLOADER")
$DMPState = $subKey.GetValue("Current State")
while ($DMPState -ne "Running") {
    Write-Msg "Current SMS_DMP_DOWNLOADER state is : $DMPState , will try again 30 seconds later..."
    Start-Sleep -Seconds 30
    $DMPState = $subKey.GetValue("Current State")
}

Write-Msg "Current SMS_DMP_DOWNLOADER state is : $DMPState "

#get the available update
function getupdate() {
    Write-Msg "Get CM update..."
    $updatepacklist = Get-CMSiteUpdate -Fast | Where-Object { $_.State -ne 196612 }
    $getupdateretrycount = 0
    while ($updatepacklist.Count -eq 0) {
        if ($getupdateretrycount -eq 3) {
            break
        }
        Write-Msg "Not found any updates, retry to invoke update check."
        $getupdateretrycount++
        Write-Msg "Invoke CM Site update check..."
        Invoke-CMSiteUpdateCheck -ErrorAction Ignore
        Start-Sleep 120

        $updatepacklist = Get-CMSiteUpdate | Where-Object { $_.State -ne 196612 }
    }

    $updatepack = ""

    if ($updatepacklist.Count -eq 0) {
    }
    elseif ($updatepacklist.Count -eq 1) {
        $updatepack = $updatepacklist
    }
    else {
        $updatepack = ($updatepacklist | Sort-Object -Property fullversion)[-1] 
    }
    return $updatepack
}

#----------------------------------------------------
$state = @{
    0      = 'UNKNOWN'
    2      = 'ENABLED'
    #DMP DOWNLOAD
    262145 = 'DOWNLOAD_IN_PROGRESS'
    262146 = 'DOWNLOAD_SUCCESS'
    327679 = 'DOWNLOAD_FAILED'
    #APPLICABILITY
    327681 = 'APPLICABILITY_CHECKING'
    327682 = 'APPLICABILITY_SUCCESS'
    393213 = 'APPLICABILITY_HIDE'
    393214 = 'APPLICABILITY_NA'
    393215 = 'APPLICABILITY_FAILED'
    #CONTENT
    65537  = 'CONTENT_REPLICATING'
    65538  = 'CONTENT_REPLICATION_SUCCESS'
    131071 = 'CONTENT_REPLICATION_FAILED'
    #PREREQ
    131073 = 'PREREQ_IN_PROGRESS'
    131074 = 'PREREQ_SUCCESS'
    131075 = 'PREREQ_WARNING'
    196607 = 'PREREQ_ERROR'
    #Apply changes
    196609 = 'INSTALL_IN_PROGRESS'
    196610 = 'INSTALL_WAITING_SERVICE_WINDOW'
    196611 = 'INSTALL_WAITING_PARENT'
    196612 = 'INSTALL_SUCCESS'
    196613 = 'INSTALL_PENDING_REBOOT'
    262143 = 'INSTALL_FAILED'
    #CMU SERVICE UPDATEI
    196614 = 'INSTALL_CMU_VALIDATING'
    196615 = 'INSTALL_CMU_STOPPED'
    196616 = 'INSTALL_CMU_INSTALLFILES'
    196617 = 'INSTALL_CMU_STARTED'
    196618 = 'INSTALL_CMU_SUCCESS'
    196619 = 'INSTALL_WAITING_CMU'
    262142 = 'INSTALL_CMU_FAILED'
    #DETAILED INSTALL STATUS
    196620 = 'INSTALL_INSTALLFILES'
    196621 = 'INSTALL_UPGRADESITECTRLIMAGE'
    196622 = 'INSTALL_CONFIGURESERVICEBROKER'
    196623 = 'INSTALL_INSTALLSYSTEM'
    196624 = 'INSTALL_CONSOLE'
    196625 = 'INSTALL_INSTALLBASESERVICES'
    196626 = 'INSTALL_UPDATE_SITES'
    196627 = 'INSTALL_SSB_ACTIVATION_ON'
    196628 = 'INSTALL_UPGRADEDATABASE'
    196629 = 'INSTALL_UPDATEADMINCONSOLE'
}
#----------------------------------------------------
$sites = Get-CMSite
if ($originalbuildnumber -eq "") {
    if ($sites.count -eq 1) {
        $originalbuildnumber = $sites.BuildNumber
    }
    else {
        $originalbuildnumber = $sites[0].BuildNumber
    }
}

#----------------------------------------------------
$retrytimes = 0
$downloadretrycount = 0
$updatepack = getupdate
if ($updatepack -ne "") {
    Write-Msg "Update package is $($updatepack.Name)"
}
else {
    Write-Msg "No update package be found."
}
while ($updatepack -ne "") {
    if ($retrytimes -eq 3) {
        $upgradingfailed = $true
        break
    }
    $updatepack = Get-CMSiteUpdate -Fast -Name $updatepack.Name 
    while ($updatepack.State -eq 327682 -or $updatepack.State -eq 262145 -or $updatepack.State -eq 327679) {
        #package not downloaded
        if ($updatepack.State -eq 327682) {
            Invoke-CMSiteUpdateDownload -Name $updatepack.Name -Force -WarningAction SilentlyContinue
            Start-Sleep 120
            $updatepack = Get-CMSiteUpdate -Name $updatepack.Name -Fast
            $downloadstarttime = get-date
            while ($updatepack.State -eq 327682) {
                
                Write-Msg "Waiting SCCM Upgrade package start to download, sleep 2 min..."
                Start-Sleep 120
                $updatepack = Get-CMSiteUpdate -Name $updatepack.Name -Fast
                $downloadspan = New-TimeSpan -Start $downloadstarttime -End (Get-Date)
                if ($downloadspan.Hours -ge 1) {
                    Restart-Service -DisplayName "SMS_Executive"
                    $downloadretrycount++
                    Start-Sleep 120
                    $downloadstarttime = get-date
                }
                if ($downloadretrycount -ge 2) {
                    Write-Msg "Update package $($updatepack.Name) failed to start downloading in 2 hours."
                    break
                }
            }
        }
        
        if ($downloadretrycount -ge 2) {
            break
        }
        
        #waiting package downloaded
        $downloadstarttime = get-date
        while ($updatepack.State -eq 262145) {
            Write-Msg "Waiting SCCM Upgrade package download, sleep 2 min..."
            Start-Sleep 120
            $updatepack = Get-CMSiteUpdate -Name $updatepack.Name -Fast
            $downloadspan = New-TimeSpan -Start $downloadstarttime -End (Get-Date)
            if ($downloadspan.Hours -ge 1) {
                Restart-Service -DisplayName "SMS_Executive"
                Start-Sleep 120
                $downloadstarttime = get-date
            }
        }

        #downloading failed
        if ($updatepack.State -eq 327679) {
            $retrytimes++
            Start-Sleep 300
            continue
        }
    }
    
    if ($downloadretrycount -ge 2) {
        break
    }
    
    #trigger prerequisites check after the package downloaded
    Invoke-CMSiteUpdatePrerequisiteCheck -Name $updatepack.Name
    while ($updatepack.State -ne 196607 -and $updatepack.State -ne 131074 -and $updatepack.State -ne 131075) {
        (Write-Msg "Waiting checking prerequisites complete, current pack $($updatepack.Name) state is $($state.($updatepack.State)), sleep 2 min...")
        Start-Sleep 120
        $updatepack = Get-CMSiteUpdate -Fast -Name $updatepack.Name 
    }
    if ($updatepack.State -eq 196607) {
        $retrytimes++
        Start-Sleep 300
        continue
    }
    #trigger setup after the prerequisites check
    Install-CMSiteUpdate -Name $updatepack.Name -SkipPrerequisiteCheck -Force
    while ($updatepack.State -ne 196607 -and $updatepack.State -ne 262143 -and $updatepack.State -ne 196612) {
        (Write-Msg "Waiting SCCM Upgrade Complete, current pack $($updatepack.Name) state is $($state.($updatepack.State)), sleep 2 min...")
        Start-Sleep 120
        $updatepack = Get-CMSiteUpdate -Fast -Name $updatepack.Name 
    }
    if ($updatepack.State -eq 196612) {
        (Write-Msg "SCCM Upgrade Complete, current pack $($updatepack.Name) state is $($state.($updatepack.State))" )
        #we need waiting the copying files finished if there is only one site
        $toplevelsite = Get-CMSite | Where-Object { $_.ReportingSiteCode -eq "" }
        if ((Get-CMSite).count -eq 1) {
            $path = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\SMS\Setup' -Name 'Installation Directory'

            $fileversion = (Get-Item ($path + '\cd.latest\SMSSETUP\BIN\X64\setup.exe')).VersionInfo.FileVersion.split('.')[2]
            while ($fileversion -ne $toplevelsite.BuildNumber) {
                Start-Sleep 120
                $fileversion = (Get-Item ($path + '\cd.latest\SMSSETUP\BIN\X64\setup.exe')).VersionInfo.FileVersion.split('.')[2]
            }
            #Wait for copying files finished
            Start-Sleep 600
        }
        #Get if there are any other updates need to be installed
        $updatepack = getupdate 
        if ($updatepack -ne "") {
            Write-Msg "Found another update package : " + $updatepack.Name
        }
    }
    if ($updatepack.State -eq 196607 -or $updatepack.State -eq 262143 ) {
        if ($retrytimes -le 3) {
            $retrytimes++
            Start-Sleep 300
            continue
        }
    }
}

if ($upgradingfailed -eq $true) {
    (Write-Msg "Upgrade " + $updatepack.Name + " failed")
    if ($($updatepack.Name).ToLower().Contains("hotfix")) {
        (Write-Msg "This is a hotfix, skip it and continue...")
    }
    else {

        throw
    }
}

if ($downloadretrycount -ge 2) {
    (Write-Msg "Upgrade $($updatepack.Name) failed to start downloading")
    throw
}

$key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32)
$subKey = $key.OpenSubKey("SOFTWARE\Microsoft\ConfigMgr10\Setup")
$uiInstallPath = $subKey.GetValue("UI Installation Directory")
$modulePath = $uiInstallPath + "bin\ConfigurationManager.psd1"
# Import the ConfigurationManager.psd1 module 
if ($null -eq (Get-Module ConfigurationManager)) {
    Import-Module $modulePath
}
$key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
$subKey = $key.OpenSubKey("SOFTWARE\Microsoft\SMS\Identification")
$SiteCode = $subKey.GetValue("Site Code")
$MachineName = $env:COMPUTERNAME + ".contoso.com"
$initParams = @{}

$ProviderMachineName = $env:COMPUTERNAME + ".contoso.com"
New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
while ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    Write-Msg "Retry in 10s to set PS Drive. Please wait."
    Start-Sleep -Seconds 10
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

Set-Location "$($SiteCode):\" @initParams

$Date = [DateTime]::Now.AddYears(30)
$SystemServer = Get-CMSiteSystemServer -SiteSystemServerName $MachineName
if ((get-cmdistributionpoint -SiteSystemServerName $MachineName).count -ne 1) {
    #Install DP
    Write-Msg "Adding distribution point on $MachineName ..."
    Add-CMDistributionPoint -InputObject $SystemServer -CertificateExpirationTimeUtc $Date
    Write-Msg "Finished adding distribution point on $MachineName ..."


    if ((get-cmdistributionpoint -SiteSystemServerName $MachineName).count -eq 1) {
        Write-Msg "Finished running the script."
    }
    else {
        Write-Msg "Failed to run the script."
    }
}
else {
    Write-Msg "$MachineName is already a distribution point , skip running this script."
}

#Get Database name
$DatabaseValue = 'Database Name'
$DatabaseName = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\SMS\SQL Server' -Name 'Database Name').$DatabaseValue
#Get Instance Name
$InstanceValue = 'Service Name'
$InstanceName = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\SMS\SQL Server' -Name 'Service Name').$InstanceValue

if ((Get-CMManagementPoint -SiteSystemServerName $MachineName).count -ne 1) {
    #Install MP
    Write-Msg "Adding management point on $MachineName ..."
    Add-CMManagementPoint -InputObject $SystemServer -CommunicationType Http
    Write-Msg "Finished adding management point on $MachineName ..."
    
    $connectionString = "Data Source=.; Integrated Security=SSPI; Initial Catalog=$DatabaseName"
    if ($InstanceName.ToUpper() -ne 'MSSQLSERVER') {
        $connectionString = "Data Source=.\$InstanceName; Integrated Security=SSPI; Initial Catalog=$DatabaseName"
    }
    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $sqlCommand = "INSERT INTO [Feature_EC] (FeatureID,Exposed) values (N'49E3EF35-718B-4D93-A427-E743228F4855',0)"
    $connection.Open() | Out-Null
    $command = new-object system.data.sqlclient.sqlcommand($sqlCommand, $connection)
    $command.ExecuteNonQuery() | Out-Null

    if ((Get-CMManagementPoint -SiteSystemServerName $MachineName).count -eq 1) {
        Write-Msg "Finished running the script."
    }
    else {
        Write-Msg "Failed to run the script."
    }
}
else {
    Write-Msg "$MachineName is already a management point , skip running this script."
}


# Now that we're done, we'll remove the files...
mkdir $env:temp\emptyFolder
robocopy /mir $env:temp\emptyFolder C:\CMCB
robocopy /mir $env:temp\emptyFolder C:\ConfigMgrFiles

Start-Process -FilePath "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\AdminUI.ExtensionInstaller.exe" -ArgumentList @("SiteServerName=$($env:COMPUTERNAME).contoso.com", "ReinstallConsole")

while (!(Get-Process "Microsoft.ConfigurationManagement" -ErrorAction Ignore)){
    Write-Msg "We're still waiting for the client updater to finish..."
    start-sleep -Seconds 60
}
Get-Process "Microsoft.ConfigurationManagement" | Stop-Process
$buildStop = Get-Date

$buildDuration = New-TimeSpan -Start $buildStart -End $buildStop

Write-Msg "We are officially done the setup of the system after $($buildDuration.TotalMinutes) minutes"
