
. "$PSScriptRoot/../Private/CertificateHelper.ps1"
. "$PSScriptRoot/../Private/PlatformHelper.ps1"
. "$PSScriptRoot/../Private/DockerHelper.ps1"
. "$PSScriptRoot/../Private/CaseHelper.ps1"
. "$PSScriptRoot/../Private/YamlHelper.ps1"
. "$PSScriptRoot/../Private/CmdletService.ps1"

function Get-JetImage
{
    param(
        [string] $Platform
    )

    $JetVersion = '0.12.0' # Update Get-WaykBastionImage as well

    $image = if ($Platform -ne "windows") {
        "devolutions/devolutions-jet:${JetVersion}-buster"
    } else {
        "devolutions/devolutions-jet:${JetVersion}-servercore-ltsc2019"
    }

    return $image
}

class JetConfig
{
    [string] $JetInstance
    [string[]] $JetListeners

    [string] $DockerPlatform
    [string] $DockerIsolation
    [string] $DockerRestartPolicy
    [string] $DockerImage
}

function Set-JetConfig
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
        [string] $JetInstance,
        [string[]] $JetListeners,
        [ValidateSet("linux","windows")]
        [string] $DockerPlatform,
        [ValidateSet("process","hyperv")]
        [string] $DockerIsolation,
        [ValidateSet("no","on-failure","always","unless-stopped")]
        [string] $DockerRestartPolicy,
        [string] $DockerImage,
        [string] $Force
    )

    $ConfigPath = Find-JetConfig -ConfigPath:$ConfigPath

    if (-Not (Test-Path -Path $ConfigPath -PathType 'Container')) {
        New-Item -Path $ConfigPath -ItemType 'Directory'
    }

    $ConfigFile = Join-Path $ConfigPath "jet-relay.yml"

    if (-Not (Test-Path -Path $ConfigFile -PathType 'Leaf')) {
        $config = [JetConfig]::new()
    } else {
        $config = Get-JetConfig -ConfigPath:$ConfigPath
    }

    $properties = [JetConfig].GetProperties() | ForEach-Object { $_.Name }
    foreach ($param in $PSBoundParameters.GetEnumerator()) {
        if ($properties -Contains $param.Key) {
            $config.($param.Key) = $param.Value
        }
    }
 
    $JetRelayPath = Join-Path $ConfigPath "jet-relay"
    New-Item -Path $JetRelayPath -ItemType "Directory" -Force | Out-Null

    # always force overwriting jet-relay.yml when updating the config file
    ConvertTo-Yaml -Data (ConvertTo-SnakeCaseObject -Object $config) -OutFile $ConfigFile -Force
}

function Get-JetConfig
{
    [CmdletBinding()]
    [OutputType('JetConfig')]
    param(
        [string] $ConfigPath,
        [switch] $Expand
    )

    $ConfigPath = Find-JetConfig -ConfigPath:$ConfigPath

    $ConfigFile = Join-Path $ConfigPath "jet-relay.yml"
    $ConfigData = Get-Content -Path $ConfigFile -Raw -ErrorAction Stop
    $yaml = ConvertFrom-Yaml -Yaml $ConfigData -UseMergingParser -AllDocuments -Ordered

    $config = [JetConfig]::new()

    [JetConfig].GetProperties() | ForEach-Object {
        $Name = $_.Name
        $snake_name = ConvertTo-SnakeCase -Value $Name
        if ($yaml.Contains($snake_name)) {
            if ($yaml.$snake_name -is [string]) {
                if (![string]::IsNullOrEmpty($yaml.$snake_name)) {
                    $config.$Name = ($yaml.$snake_name).Trim()
                }
            } else {
                $config.$Name = $yaml.$snake_name
            }
        }
    }

    if ($Expand) {
        Expand-JetConfig $config
    }

    return $config
}

function Expand-JetConfig
{
    param(
        [JetConfig] $Config
    )

    if (-Not $config.DockerPlatform) {
        if (Get-IsWindows) {
            $config.DockerPlatform = "windows"
        } else {
            $config.DockerPlatform = "linux"
        }
    }

    if (-Not $config.DockerRestartPolicy) {
        $config.DockerRestartPolicy = "on-failure"
    }

    if (-Not $config.DockerImage) {
        $config.DockerImage = Get-JetImage -Platform $config.DockerPlatform
    }

    if (-Not $config.JetListeners) {
        $config.JetListeners = @("tcp://0.0.0.0:8080")
    }
}

function Find-JetConfig
{
    param(
        [string] $ConfigPath
    )

    if (-Not $ConfigPath) {
        $ConfigPath = Get-Location
    }

    if ($Env:JET_CONFIG_PATH) {
        $ConfigPath = $Env:JET_CONFIG_PATH
    }

    return $ConfigPath
}

function Set-JetConfigPath
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [string] $ConfigPath
    )

    $Env:JET_CONFIG_PATH = $ConfigPath
}

function Get-JetRelayPath()
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory,Position=0)]
        [ValidateSet("ConfigPath","GlobalPath","LocalPath")]
		[string] $PathType
	)

    $DisplayName = "Jet Relay"
    $LowerName = "jet-relay"
    $CompanyName = "Devolutions"
	$HomePath = Resolve-Path '~'

	if (Get-IsWindows)	{
		$LocalPath = $Env:AppData + "\${CompanyName}\${DisplayName}";
		$GlobalPath = $Env:ProgramData + "\${CompanyName}\${DisplayName}"
	} elseif ($IsMacOS) {
		$LocalPath = "$HomePath/Library/Application Support/${DisplayName}"
		$GlobalPath = "/Library/Application Support/${DisplayName}"
	} elseif ($IsLinux) {
		$LocalPath = "$HomePath/.config/${LowerName}"
		$GlobalPath = "/etc/${LowerName}"
	}

	switch ($PathType) {
		'LocalPath' { $LocalPath }
		'GlobalPath' { $GlobalPath }
        'ConfigPath' { $GlobalPath }
		default { throw("Invalid path type: $PathType") }
	}
}

function Import-JetCertificate
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
        [string] $CertificateFile,
        [string] $PrivateKeyFile,
        [string] $Password
    )

    $ConfigPath = Find-JetConfig -ConfigPath:$ConfigPath
    $config = Get-JetConfig -ConfigPath:$ConfigPath

    $result = Get-PemCertificate -CertificateFile:$CertificateFile `
        -PrivateKeyFile:$PrivateKeyFile -Password:$Password
        
    $CertificateData = $result.Certificate
    $PrivateKeyData = $result.PrivateKey

    $JetRelayPath = Join-Path $ConfigPath "jet-relay"
    New-Item -Path $JetRelayPath -ItemType "Directory" -Force | Out-Null

    $JetRelayPemFile = Join-Path $JetRelayPath "jet-relay.pem"
    $JetRelayKeyFile = Join-Path $JetRelayPath "jet-relay.key"

    Set-Content -Path $JetRelayPemFile -Value $CertificateData -Force
    Set-Content -Path $JetRelayKeyFile -Value $PrivateKeyData -Force
}

function Get-JetService
{
    param(
        [string] $ConfigPath,
        [JetConfig] $Config
    )

    if ($config.DockerPlatform -eq "linux") {
        $PathSeparator = "/"
        $JetRelayDataPath = "/etc/jet-relay"
    } else {
        $PathSeparator = "\"
        $JetRelayDataPath = "c:\jet-relay"
    }

    $Service = [DockerService]::new()
    $Service.ContainerName = 'devolutions-jet'
    $Service.Image = $config.DockerImage
    $Service.Platform = $config.DockerPlatform
    $Service.Isolation = $config.DockerIsolation
    $Service.RestartPolicy = $config.DockerRestartPolicy
    $Service.TargetPorts = @(10256)

    foreach ($JetListener in $config.JetListeners) {
        $ListenerUrl = ([string[]] $($JetListener -Split ','))[0]
        $url = [System.Uri]::new($ListenerUrl)
        $Service.TargetPorts += @($url.Port)
    }

    $Service.PublishAll = $true
    $Service.Environment = [ordered]@{
        "JET_INSTANCE" = $config.JetInstance;
        "JET_UNRESTRICTED" = "true";
        "RUST_BACKTRACE" = "1";
        "RUST_LOG" = "info";
    }
    $Service.Volumes = @("$ConfigPath/jet-relay:$JetRelayDataPath")
    $Service.External = $false

    if (Test-Path "$ConfigPath/jet-relay/jet-relay.pem" -PathType 'Leaf') {
        $Service.Environment['JET_CERTIFICATE_FILE'] = @($JetRelayDataPath, 'jet-relay.pem') -Join $PathSeparator
    }

    if (Test-Path "$ConfigPath/jet-relay/jet-relay.key" -PathType 'Leaf') {
        $Service.Environment['JET_PRIVATE_KEY_FILE'] = @($JetRelayDataPath, 'jet-relay.key') -Join $PathSeparator
    }

    $args = @()
    foreach ($JetListener in $config.JetListeners) {
        $args += @('-l', "`"$JetListener`"")
    }

    $Service.Command = $($args -Join " ")

    return $Service
}

function Update-JetRelay
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath
    )

    $ConfigPath = Find-JetConfig -ConfigPath:$ConfigPath
    $config = Get-JetConfig -ConfigPath:$ConfigPath
    Expand-JetConfig -Config $config

    $Service = Get-JetService -ConfigPath:$ConfigPath -Config:$config
    Request-ContainerImage -Name $Service.Image
}

function Start-JetRelay
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
        [switch] $SkipPull
    )

    $ConfigPath = Find-JetConfig -ConfigPath:$ConfigPath
    $config = Get-JetConfig -ConfigPath:$ConfigPath
    Expand-JetConfig -Config $config

    $Service = Get-JetService -ConfigPath:$ConfigPath -Config:$config

    if (-Not $SkipPull) {
        # pull docker images only if they are not cached locally
        if (-Not (Get-ContainerImageId -Name $Service.Image)) {
            Request-ContainerImage -Name $Service.Image
        }
    }

    Start-DockerService -Service $Service -Remove
}

function Stop-JetRelay
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
        [switch] $Remove
    )

    $ConfigPath = Find-JetConfig -ConfigPath:$ConfigPath
    $config = Get-JetConfig -ConfigPath:$ConfigPath
    Expand-JetConfig -Config $config

    $Service = Get-JetService -ConfigPath:$ConfigPath -Config:$config

    Write-Host "Stopping $($Service.ContainerName)"
    Stop-Container -Name $Service.ContainerName -Quiet

    if ($Remove) {
        Remove-Container -Name $Service.ContainerName
    }
}

function Restart-JetRelay
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath
    )

    $ConfigPath = Find-JetConfig -ConfigPath:$ConfigPath
    Stop-JetRelay -ConfigPath:$ConfigPath
    Start-JetRelay -ConfigPath:$ConfigPath
}

function Get-JetRelayServiceDefinition()
{
    $ServiceName = "JetRelay"
    $ModuleName = "WaykBastion"
    $DisplayName = "Jet Relay"
    $CompanyName = "Devolutions"
    $Description = "Jet relay service"

    return [PSCustomObject]@{
        ServiceName = $ServiceName
        DisplayName = $DisplayName
        Description = $Description
        CompanyName = $CompanyName
        ModuleName = $ModuleName
        StartCommand = "Start-JetRelay"
        StopCommand = "Stop-JetRelay"
        WorkingDir = "%ProgramData%\${CompanyName}\${DisplayName}"
    }
}

function Register-JetRelayService
{
    [CmdletBinding()]
    param(
        [string] $ServicePath,
        [switch] $Force
    )

    $Definition = Get-JetRelayServiceDefinition

    if ($ServicePath) {
        $Definition.WorkingDir = $ServicePath
    }

    Register-CmdletService -Definition $Definition -Force:$Force

    $ServiceName = $Definition.ServiceName
    $ServicePath = [System.Environment]::ExpandEnvironmentVariables($Definition.WorkingDir)
    Write-Host "`"$ServiceName`" service has been installed to `"$ServicePath`""
}

function Unregister-JetRelayService
{
    [CmdletBinding()]
    param(
        [string] $ServicePath,
        [switch] $Force
    )

    $Definition = Get-JetRelayServiceDefinition

    if ($ServicePath) {
        $Definition.WorkingDir = $ServicePath
    }

    Unregister-CmdletService -Definition $Definition -Force:$Force
}

Export-ModuleMember -Function `
    Set-JetConfig, Get-JetConfig, `
    Set-JetConfigPath, Get-JetRelayPath, `
    Import-JetCertificate, `
    Start-JetRelay, Stop-JetRelay, Restart-JetRelay, Update-JetRelay, `
    Register-JetRelayService, Unregister-JetRelayService
