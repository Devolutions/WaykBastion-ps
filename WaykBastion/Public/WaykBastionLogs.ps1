. "$PSScriptRoot/../Private/PlatformHelper.ps1"

function Export-WaykBastionLogs
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
        [string] $LogPath
    )

    # Get services to know which containers exist
    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath
    $config = Get-WaykBastionConfig -ConfigPath:$ConfigPath
    Expand-WaykBastionConfig -Config $config
    $Services = Get-WaykBastionService -ConfigPath:$ConfigPath -Config $config
    
    # Get temp folder to generate logs
    if (Get-IsWindows) {
        $TempPath = "C:\Windows\temp"
    } else {
        $TempPath = "/tmp"
    }

    # Build the zip file path
    if (-Not $LogPath) {
        $LogPath = Get-Location
    }
    $LogPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($LogPath)

    if (-Not ($LogPath -match ".zip")) {
        $LogFileName = "WaykBastion-" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".zip"
        $LogFilePath = Join-Path $LogPath $LogFileName
    } else {
        $LogFilePath = $LogPath
    }

    # Generate containers state
    $TempFilePath = Join-Path $TempPath "docker_ps.log"
    Export-ContainersState -FilePath $TempFilePath
    $FilesToZip = @($TempFilePath)

    # Generate container log
    foreach ($Service in $Services) {
        if (Get-ContainerExists -Name $Service.ContainerName) {
            $FileName = $Service.ContainerName + ".log"
            $TempFilePath = Join-Path $TempPath $FileName
            Export-ContainerLogs -Name $Service.ContainerName -FilePath $TempFilePath
            $FilesToZip += $TempFilePath
        }
    }

    # Generate zip file
    Compress-Archive -Path $FilesToZip -CompressionLevel "Optimal" -DestinationPath $LogFilePath

    # Clean temp folder
    foreach ($File in $FilesToZip) {
        Remove-Item $File
    }   
}