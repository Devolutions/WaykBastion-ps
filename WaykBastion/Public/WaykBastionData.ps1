
. "$PSScriptRoot/../Private/DockerHelper.ps1"

function Backup-WaykBastionData
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
        [string] $BackupPath
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath

    $config = Get-WaykBastionConfig -ConfigPath:$ConfigPath
    Expand-WaykBastionConfig -Config $config

    $Platform = $config.DockerPlatform
    $Services = Get-WaykBastionService -ConfigPath:$ConfigPath -Config $config

    $Service = ($Services | Where-Object { $_.ContainerName -Like '*mongo' })[0]
    $ContainerName = $Service.ContainerName

    if ($Platform -eq "linux") {
        $PathSeparator = "/"
        $TempPath = "/tmp"
    } else {
        $PathSeparator = "\"
        $TempPath = "C:\Windows\temp"
    }

    if (-Not $BackupPath) {
        $BackupPath = Get-Location
    }

    $BackupPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($BackupPath)

    $BackupFileName = "den-mongo.tgz"
    if (($BackupPath -match ".tgz") -or ($BackupPath -match ".tar.gz")) {
        $BackupFileName = Split-Path -Path $BackupPath -Leaf
    } else {
        $BackupPath = Join-Path $BackupPath $BackupFileName
    }

    $TempBackupPath = @($TempPath, $BackupFileName) -Join $PathSeparator

    if (-Not (Get-ContainerIsRunning -Name $ContainerName)) {
        Start-DockerService $Service -Remove
    }

    # make sure parent output directory exists
    New-Item -Path $(Split-Path -Path $BackupPath) -ItemType "Directory" -Force | Out-Null

    if (($config.DockerNetwork -Match "none") -and $config.DockerHost) {
        $MongoUrl = "mongodb://$($config.DockerHost):27017"
    } else {
        $MongoUrl = "mongodb://${ContainerName}:27017"
    }
        
    $CmdArgs = @('docker', 'exec', $ContainerName, 'mongodump', '--gzip', `
        "--archive=${TempBackupPath}", '--uri', $MongoUrl)
    $cmd = $CmdArgs -Join " "
    Write-Verbose $cmd
    Invoke-Expression $cmd

    $CmdArgs = @('docker', 'cp', "$ContainerName`:$TempBackupPath", "`"$BackupPath`"")
    $cmd = $CmdArgs -Join " "
    Write-Verbose $cmd
    Invoke-Expression $cmd
}

function Restore-WaykBastionData
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
        [string] $BackupPath
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath

    $config = Get-WaykBastionConfig -ConfigPath:$ConfigPath
    Expand-WaykBastionConfig -Config $config

    $Platform = $config.DockerPlatform
    $Services = Get-WaykBastionService -ConfigPath:$ConfigPath -Config $config

    $Service = ($Services | Where-Object { $_.ContainerName -Like '*mongo' })[0]
    $ContainerName = $Service.ContainerName

    if ($Platform -eq "linux") {
        $PathSeparator = "/"
        $TempPath = "/tmp"
    } else {
        $PathSeparator = "\"
        $TempPath = "C:\Windows\temp"
    }

    $BackupFileName = "den-mongo.tgz"
    $BackupPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($BackupPath)

    if (($BackupPath -match ".tgz") -or ($BackupPath -match ".tar.gz")) {
        $BackupFileName = Split-Path -Path $BackupPath -Leaf
    } else {
        $BackupPath = Join-Path $BackupPath $BackupFileName
    }

    $TempBackupPath = @($TempPath, $BackupFileName) -Join $PathSeparator

    if (-Not (Get-ContainerIsRunning -Name $ContainerName)) {
        Start-DockerService $Service -Remove
    }

    if (-Not (Test-Path -Path $BackupPath -PathType 'Leaf')) {
        throw "$BackupPath does not exist"
    }

    $CmdArgs = @('docker', 'cp', "`"$BackupPath`"", "$ContainerName`:$TempBackupPath")
    $cmd = $CmdArgs -Join " "
    Write-Verbose $cmd
    Invoke-Expression $cmd

    if (($config.DockerNetwork -Match "none") -and $config.DockerHost) {
        $MongoUrl = "mongodb://$($config.DockerHost):27017"
    } else {
        $MongoUrl = "mongodb://${ContainerName}:27017"
    }

    $CmdArgs = @('docker', 'exec', $ContainerName, 'mongorestore', '--drop', '--gzip', `
        "--archive=${TempBackupPath}", '--uri', $MongoUrl)
    $cmd = $CmdArgs -Join " "
    Write-Verbose $cmd
    Invoke-Expression $cmd
}
