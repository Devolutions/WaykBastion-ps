
function Get-CmdletServiceExecutable()
{
    Join-Path $PSScriptRoot "/../bin/cmdlet-service.exe"
}

function Register-CmdletService
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject] $Definition,
        [switch] $Force
    )

    if (Get-IsWindows) {
        $Executable = Get-CmdletServiceExecutable
        
        $ServiceName = $Definition.ServiceName
        $DisplayName = $Definition.DisplayName
        $Description = $Definition.Description
        $WorkingDir = $Definition.WorkingDir

        $ServicePath = [System.Environment]::ExpandEnvironmentVariables($WorkingDir)
        $BinaryPathName = Join-Path $ServicePath "${ServiceName}.exe"
        $ManifestFile = Join-Path $ServicePath "service.json"

        $Service = Get-Service | Where-Object { $_.Name -Like $ServiceName }

        if ($Service) {
            Unregister-CmdletService -Definition:$Definition -Force
        }

        $DependsOn = "Docker"
        $StartupType = "Automatic"

        New-Item -Path $ServicePath -ItemType 'Directory' -Force | Out-Null
        Copy-Item -Path $Executable -Destination $BinaryPathName -Force
        Set-Content -Path $ManifestFile -Value $($Definition | ConvertTo-Json) -Force

        $params = @{
            Name = $ServiceName
            DisplayName = $DisplayName
            Description = $Description
            BinaryPathName = $BinaryPathName
            DependsOn = $DependsOn
            StartupType = $StartupType
        }

        New-Service @params | Out-Null
    } else {
        throw "Service registration is not supported on this platform"
    }
}

function Unregister-CmdletService
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject] $Definition,
        [switch] $Force
    )

    if (Get-IsWindows) {
        $ServiceName = $Definition.ServiceName
        $WorkingDir = $Definition.WorkingDir

        $ServicePath = [System.Environment]::ExpandEnvironmentVariables($WorkingDir)
        $BinaryPathName = Join-Path $ServicePath "${ServiceName}.exe"
        $ManifestFile = Join-Path $ServicePath "service.json"

        $Service = Get-Service | Where-Object { $_.Name -Like $ServiceName }

        if ($Service) {
            Stop-Service -Name $ServiceName

            if (Get-Command 'Remove-Service' -ErrorAction SilentlyContinue) {
                Remove-Service -Name $ServiceName
            } else { # Windows PowerShell 5.1
                & 'sc.exe' 'delete' $ServiceName | Out-Null
            }
        }

        Remove-Item -Path $BinaryPathName -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $ManifestFile -Force -ErrorAction SilentlyContinue
    } else {
        throw "Service registration is not supported on this platform"
    }
}
