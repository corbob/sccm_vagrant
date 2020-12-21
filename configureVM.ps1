vagrant up
vagrant winrm -e -c '& c:\vagrant\provisioning\dcpromo.ps1'
vagrant winrm -e -c "choco install sql-server-2019 -y --params=`"'/TCPENABLED=`"1`" /IsoPath:c:\sql.iso'`""
vagrant winrm -e -c '& c:\vagrant\provisioning\InstallAndUpdateSCCM.ps1'
