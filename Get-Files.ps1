$files = @(
    @{
        url  = 'https://download.microsoft.com/download/7/c/1/7c14e92e-bdcb-4f89-b7cf-93543e7112d1/SQLServer2019-x64-ENU-Dev.iso'
        file = 'sql.iso'
    },
    @{
        url  = 'https://go.microsoft.com/fwlink/?linkid=2120253'
        file = 'winpe.exe'
    },
    @{
        url  = 'https://go.microsoft.com/fwlink/?linkid=2120254'
        file = 'adk.exe'
    },
    @{
        url  = 'https://go.microsoft.com/fwlink/?linkid=2093192'
        file = 'CMCB.exe'
    }
)
if (!(Test-Path $PSScriptRoot/Files)) {
    mkdir $PSScriptRoot/Files
}
foreach ($entry in $files) {
    $outFile = "$PSScriptRoot/Files/$($entry.file)"
    if (!(Test-Path $outFile)) {
        Invoke-WebRequest -Uri $entry.url -OutFile $outFile
    }
}
