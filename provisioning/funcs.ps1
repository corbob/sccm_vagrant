function Write-Msg {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Message
    )
    Write-Host -ForegroundColor Green -NoNewline "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] "
    Write-Host $Message
}
