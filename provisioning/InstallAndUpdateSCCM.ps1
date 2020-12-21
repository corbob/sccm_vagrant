$DomainFullName = "contoso.com"
$CM = "CMCB"
$CMUser = "contoso\vagrant"
$Role = "PS1"

#region AD Configuration
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

. $PSScriptRoot\funcs.ps1

#region Prerequisites

$_adkpath = 'C:\ConfigMgrFiles\adk.exe'
$_adkWinPEpath = 'C:\ConfigMgrFiles\winpe.exe'
if (!(Test-Path $_adkpath)) {
    $adkurl = "https://go.microsoft.com/fwlink/?linkid=2120254"
    Invoke-WebRequest -Uri $adkurl -OutFile $_adkpath
}
if (!(Test-Path $_adkWinPEpath)) {
    $adkurl = "https://go.microsoft.com/fwlink/?linkid=2120253"
    Invoke-WebRequest -Uri $adkurl -OutFile $_adkWinPEpath
}

#region Install DeploymentTools
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

#region SQL Config
# Trying without this code because we're telling it to enable with the install...
# Import-Module SqlServer
# $smo = 'Microsoft.SqlServer.Management.Smo.'  
# $wmi = new-object ($smo + 'Wmi.ManagedComputer').  

# # Enable the TCP protocol on the default instance.  
# $uri = "ManagedComputer[@Name='" + (get-item env:\computername).Value + "']/ ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Tcp']"  
# $Tcp = $wmi.GetSmoObject($uri)  
# $Tcp.IsEnabled = $true  
# $Tcp.Alter()  

$_SQLInstanceName = $inst
$query = "Name = '" + $_SQLInstanceName.ToUpper() + "'"
$services = Get-WmiObject win32_service -Filter $query

if ($services.State -eq 'Running') {
    #Check if SQLSERVERAGENT is running
    $sqlserveragentflag = 0
    $sqlserveragentservices = Get-WmiObject win32_service -Filter "Name = 'SQLSERVERAGENT'"
    if ($null -ne $sqlserveragentservices) {
        if ($sqlserveragentservices.State -eq 'Running') {
            Write-Verbose "[$(Get-Date -format HH:mm:ss)] SQLSERVERAGENT need to be stopped first"
            $Result = $sqlserveragentservices.StopService()
            Write-Verbose "[$(Get-Date -format HH:mm:ss)] Stopping SQLSERVERAGENT.."
            if ($Result.ReturnValue -eq '0') {
                $sqlserveragentflag = 1
                Write-Verbose "[$(Get-Date -format HH:mm:ss)] Stopped"
            }
        }
    }
    $Result = $services.StopService()
    Write-Verbose "[$(Get-Date -format HH:mm:ss)] Stopping SQL Server services.."
    if ($Result.ReturnValue -eq '0') {
        Write-Verbose "[$(Get-Date -format HH:mm:ss)] Stopped"
    }

    Write-Verbose "[$(Get-Date -format HH:mm:ss)] Changing the services account..."
            
    $Result = $services.change($null, $null, $null, $null, $null, $null, "LocalSystem", $null, $null, $null, $null) 
    if ($Result.ReturnValue -eq '0') {
        Write-Verbose "[$(Get-Date -format HH:mm:ss)] Successfully Change the services account"
        if ($sqlserveragentflag -eq 1) {
            Write-Verbose "[$(Get-Date -format HH:mm:ss)] Starting SQLSERVERAGENT.."
            $Result = $sqlserveragentservices.StartService()
            if ($Result.ReturnValue -eq '0') {
                Write-Verbose "[$(Get-Date -format HH:mm:ss)] Started"
            }
        }
        $Result = $services.StartService()
        Write-Verbose "[$(Get-Date -format HH:mm:ss)] Starting SQL Server services.."
        while ($Result.ReturnValue -ne '0') {
            $returncode = $Result.ReturnValue
            Write-Verbose "[$(Get-Date -format HH:mm:ss)] Return $returncode , will try again"
            Start-Sleep -Seconds 10
            $Result = $services.StartService()
        }
        Write-Verbose "[$(Get-Date -format HH:mm:ss)] Started"
    }
}

#endregion

Write-Msg "Installing.."
# Start-Process -Filepath ($CMInstallationFile) -ArgumentList ('/NOUSERINPUT /script "' + $CMINIPath + '"') -wait
Start-Process -Filepath ($CMInstallationFile) -ArgumentList ('/script "' + $CMINIPath + '"') -wait

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
Write-Msg "Setting $CMUser as CM administrative user."
New-CMAdministrativeUser -Name $CMUser -RoleName "Full Administrator" -SecurityScopeName "All", "All Systems", "All Users and User Groups"
Write-Msg "Done"

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
