
. "$PSScriptRoot/../Private/CaseHelper.ps1"
. "$PSScriptRoot/../Private/YamlHelper.ps1"
. "$PSScriptRoot/../Private/TraefikHelper.ps1"
. "$PSScriptRoot/../Private/RandomGenerator.ps1"
. "$PSScriptRoot/../Private/CertificateHelper.ps1"

class WaykBastionConfig
{
    # DenServer
    [string] $Realm
    [string] $ExternalUrl
    [string] $ListenerUrl
    [string] $ServerMode
    [string] $ServerLogLevel
    [int] $ServerCount
    [string] $DenServerUrl
    [string] $DenRouterUrl
    [int] $DenKeepAliveInterval
    [string] $DenApiKey
    [bool] $DisableTelemetry = $false
    [bool] $ExperimentalFeatures = $false
    [bool] $ServerExternal = $false
    [string] $ServerImage

    # MongoDB
    [string] $MongoUrl
    [string] $MongoVolume
    [bool] $MongoExternal = $false
    [string] $MongoImage

    # Traefik
    [bool] $TraefikExternal = $false
    [string] $TraefikImage

    # Jet
    [string] $JetRelayUrl
    [int] $JetTcpPort
    [bool] $JetExternal = $false
    [string] $JetRelayImage

    # Picky
    [string] $PickyUrl
    [bool] $PickyExternal = $false
    [string] $PickyImage

    # Lucid
    [string] $LucidUrl
    [string] $LucidApiKey
    [bool] $LucidExternal = $false
    [string] $LucidImage
    [string] $LucidLogLevel

    # NATS
    [string] $NatsUrl
    [string] $NatsUsername
    [string] $NatsPassword
    [bool] $NatsExternal = $false
    [string] $NatsImage
    
    # Redis
    [string] $RedisUrl
    [string] $RedisPassword
    [bool] $RedisExternal = $false
    [string] $RedisImage

    # Docker
    [string] $DockerNetwork
    [string] $DockerPlatform
    [string] $DockerIsolation
    [string] $DockerRestartPolicy
    [string] $DockerHost
    [string] $SyslogServer
}

$script:WaykBastionConfigFormat = "json"

function Find-WaykBastionConfig
{
    param(
        [string] $ConfigPath
    )

    if (-Not $ConfigPath) {
        $ConfigPath = Get-WaykBastionPath 'ConfigPath'

        if ($Env:WAYK_BASTION_CONFIG_PATH) {
            $ConfigPath = $Env:WAYK_BASTION_CONFIG_PATH
        }
    }

    return $ConfigPath
}

function Enter-WaykBastionConfig
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
        [switch] $ChangeDirectory
    )

    if ($ConfigPath) {
        $ConfigPath = Resolve-Path $ConfigPath
        $Env:WAYK_BASTION_CONFIG_PATH = $ConfigPath
    }

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath

    if ($ChangeDirectory) {
        Set-Location $ConfigPath
    }
}

function Exit-WaykBastionConfig
{
    Remove-Item Env:WAYK_BASTION_CONFIG_PATH
}

function Get-WaykBastionPath()
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0)]
        [ValidateSet("ConfigPath","GlobalPath","LocalPath")]
		[string] $PathType = "ConfigPath"
	)

    $DisplayName = "Wayk Bastion"
    $LowerName = "wayk-bastion"
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

function Expand-WaykBastionConfigKeys
{
    param(
        [WaykBastionConfig] $Config
    )

    if (-Not $config.DenApiKey) {
        $config.DenApiKey = New-RandomString -Length 32
    }

    if (-Not $config.LucidApiKey) {
        $config.LucidApiKey = New-RandomString -Length 32
    }
}

function Expand-WaykBastionConfigImage
{
    param(
        [WaykBastionConfig] $Config
    )

    $images = Get-WaykBastionImage -Config:$Config

    if (-Not $config.LucidImage) {
        $config.LucidImage = $images['den-lucid']
    }
    
    if (-Not $config.PickyImage) {
        $config.PickyImage = $images['den-picky']
    }

    if (-Not $config.ServerImage) {
        $config.ServerImage = $images['den-server']
    }

    if (-Not $config.MongoImage) {
        $config.MongoImage = $images['den-mongo']
    }

    if (-Not $config.TraefikImage) {
        $config.TraefikImage = $images['den-traefik']
    }

    if (-Not $config.NatsImage) {
        $config.NatsImage = $images['nats-image']
    }

    if (-Not $config.RedisImage) {
        $config.RedisImage = $images['den-redis']
    }
}

function Expand-WaykBastionConfig
{
    param(
        [WaykBastionConfig] $Config
    )

    $DockerNetworkDefault = "den-network"
    $MongoUrlDefault = "mongodb://den-mongo:27017"
    $MongoVolumeDefault = "den-mongodata"
    $ServerModeDefault = "Private"
    $ServerLogLevelDefault = "info"
    $LucidLogLevelDefault = "warn"
    $ListenerUrlDefault = "http://0.0.0.0:4000"
    $JetRelayUrlDefault = "https://api.jet-relay.net"
    $PickyUrlDefault = "http://den-picky:12345"
    $LucidUrlDefault = "http://den-lucid:4242"
    $DenServerUrlDefault = "http://den-server:10255"
    $DenRouterUrlDefault = "http://den-server:4491"

    if (-Not $config.DockerNetwork) {
        $config.DockerNetwork = $DockerNetworkDefault
    }

    if (($config.DockerNetwork -Match "none") -and $config.DockerHost) {
        $MongoUrlDefault = $MongoUrlDefault -Replace "den-mongo", $config.DockerHost
        $PickyUrlDefault = $PickyUrlDefault -Replace "den-picky", $config.DockerHost
        $LucidUrlDefault = $LucidUrlDefault -Replace "den-lucid", $config.DockerHost
        $DenServerUrlDefault = $DenServerUrlDefault -Replace "den-server", $config.DockerHost
        $DenRouterUrlDefault = $DenRouterUrlDefault -Replace "den-server", $config.DockerHost
    }

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

    if (-Not $config.ServerMode) {
        $config.ServerMode = $ServerModeDefault
    }

    if (-Not $config.ServerLogLevel) {
        $config.ServerLogLevel = $ServerLogLevelDefault
    }

    if (-Not $config.LucidLogLevel) {
        $config.LucidLogLevel = $LucidLogLevelDefault
    }

    if (-Not $config.ServerCount) {
        $config.ServerCount = 1
    }

    if (-Not $config.ListenerUrl) {
        $config.ListenerUrl = $ListenerUrlDefault
    }

    if (-Not $config.MongoUrl) {
        $config.MongoUrl = $MongoUrlDefault
    }

    if (-Not $config.MongoVolume) {
        $config.MongoVolume = $MongoVolumeDefault
    }

    if (-Not $config.PickyUrl) {
        $config.PickyUrl = $PickyUrlDefault
    }

    if (-Not $config.LucidUrl) {
        $config.LucidUrl = $LucidUrlDefault
    }

    if (-Not $config.DenServerUrl) {
        $config.DenServerUrl = $DenServerUrlDefault
    }

    if (-Not $config.DenRouterUrl) {
        $config.DenRouterUrl = $DenRouterUrlDefault
    }

    if ($config.JetExternal) {
        if (-Not $config.JetRelayUrl) {
            $config.JetRelayUrl = $JetRelayUrlDefault
        }
    } else {
        if (-Not $config.JetRelayUrl) {
            $config.JetRelayUrl = $config.ExternalUrl
        }
        if (-Not $config.JetTcpPort) {
            $config.JetTcpPort = 8080
        }
    }

    Expand-WaykBastionConfigImage -Config:$Config
}

function Test-WaykBastionConfig
{
    param(
        [WaykBastionConfig] $Config
    )

    if ($config.ListenerUrl) {
        $url = [System.Uri]::new($config.ListenerUrl)

        if (-Not (($url.Scheme -eq 'http') -Or ($url.Scheme -eq 'https'))) {
            Write-Warning "Invalid ListenerUrl: $($url.OriginalString) (should begin with 'http://' or 'https://')"
        }
    }

    if ($config.ExternalUrl) {
        $url = [System.Uri]::new($config.ExternalUrl)

        if (-Not (($url.Scheme -eq 'http') -Or ($url.Scheme -eq 'https'))) {
            Write-Warning "Invalid ExternalUrl: $($url.OriginalString) (should begin with 'http://' or 'https://')"
        } elseif ($url.Scheme -ne 'https') {
            Write-Warning "HTTPS is not configured for external access, peer-to-peer sessions will be disabled"
        }
    }
}

function Export-TraefikToml()
{
    param(
        [string] $ConfigPath
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath

    $config = Get-WaykBastionConfig -ConfigPath:$ConfigPath
    Expand-WaykBastionConfig $config

    $TraefikPath = Join-Path $ConfigPath "traefik"
    New-Item -Path $TraefikPath -ItemType "Directory" -Force | Out-Null

    $TraefikTomlFile = Join-Path $TraefikPath "traefik.toml"

    $TraefikToml = New-TraefikToml -Platform $config.DockerPlatform `
        -ListenerUrl $config.ListenerUrl `
        -LucidUrl $config.LucidUrl `
        -PickyUrl $config.PickyUrl `
        -DenRouterUrl $config.DenRouterUrl `
        -DenServerUrl $config.DenServerUrl `
        -JetExternal $config.JetExternal

    Set-Content -Path $TraefikTomlFile -Value $TraefikToml
}

function Export-PickyConfig()
{
    param(
        [string] $ConfigPath
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath

    $config = Get-WaykBastionConfig -ConfigPath:$ConfigPath
    Expand-WaykBastionConfig $config

    $PickyPath = Join-Path $ConfigPath "picky"
    New-Item -Path $PickyPath -ItemType "Directory" -Force | Out-Null

    $DenServerPath = Join-Path $ConfigPath "den-server"
    $DenServerPublicKey = Join-Path $DenServerPath "den-public.pem"

    $PickyPublicKey = Join-Path $PickyPath "picky-public.pem"
    Copy-Item -Path $DenServerPublicKey -Destination $PickyPublicKey -Force
}

function Export-HostInfo()
{
    param(
        [string] $ConfigPath,
        [PSCustomObject] $HostInfo
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath

    $config = Get-WaykBastionConfig -ConfigPath:$ConfigPath
    Expand-WaykBastionConfig $config

    $DenServerPath = Join-Path $ConfigPath "den-server"
    New-Item -Path $DenServerPath -ItemType "Directory" -Force | Out-Null

    $JsonValue = $($HostInfo | ConvertTo-Json)
    $HostInfoFile = Join-Path $DenServerPath "host_info.json"
    Set-Content -Path $HostInfoFile -Value $JsonValue -Force
}

function Save-WaykBastionConfig
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
        [Parameter(Mandatory=$true)]
        [WaykBastionConfig] $Config,
        [ValidateSet("yaml","json")]
        [string] $ConfigFormat = "json"
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath
    $Config = Remove-DefaultProperties $Config $([WaykBastionConfig]::new())

    New-Item -Path $ConfigPath -ItemType "Directory" -Force | Out-Null

    if ($ConfigFormat -eq 'json') {
        $ConfigFile = Join-Path $ConfigPath "bastion.json"
        $Properties = $Config.PSObject.Properties.Name
        $NonNullProperties = $Properties.Where({ -Not [string]::IsNullOrEmpty($Config.$_) })
        $ConfigData = $Config | Select-Object $NonNullProperties | ConvertTo-Json
        $AsByteStream = if ($PSEdition -eq 'Core') { @{AsByteStream = $true} } else { @{'Encoding' = 'Byte'} }
        $ConfigBytes = $([System.Text.Encoding]::UTF8).GetBytes($ConfigData)
        Set-Content -Path $ConfigFile -Value $ConfigBytes @AsByteStream
    } elseif ($ConfigFormat -eq 'yaml') {
        $ConfigFile = Join-Path $ConfigPath "wayk-den.yml"
        ConvertTo-Yaml -Data (ConvertTo-SnakeCaseObject -Object $Config) -OutFile $ConfigFile -Force
    }
}

function New-WaykBastionConfig
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
    
        # Server
        [Parameter(Mandatory=$true)]
        [string] $Realm,
        [Parameter(Mandatory=$true)]
        [string] $ExternalUrl,
        [string] $ListenerUrl,
        [string] $ServerMode,
        [ValidateSet("off","error", "warn", "info", "debug", "trace", IgnoreCase = $false)]
        [string] $ServerLogLevel,
        [int] $ServerCount,
        [string] $DenServerUrl,
        [string] $DenRouterUrl,
        [int] $DenKeepAliveInterval,
        [string] $DenApiKey,
        [bool] $DisableTelemetry,
        [bool] $ExperimentalFeatures,
        [bool] $ServerExternal,
        [string] $ServerImage,

        # MongoDB
        [string] $MongoUrl,
        [string] $MongoVolume,
        [bool] $MongoExternal,
        [string] $MongoImage,

        # Traefik
        [bool] $TraefikExternal,
        [string] $TraefikImage,

        # Jet
        [string] $JetRelayUrl,
        [int] $JetTcpPort,
        [bool] $JetExternal,
        [string] $JetRelayImage,

        # Picky
        [string] $PickyUrl,
        [bool] $PickyExternal,
        [string] $PickyImage,

        # Lucid
        [string] $LucidUrl,
        [string] $LucidApiKey,
        [bool] $LucidExternal,
        [string] $LucidImage,
        [ValidateSet("off","error", "warn", "info", "debug", "trace", IgnoreCase = $false)]
        [string] $LucidLogLevel,


        # NATS
        [string] $NatsUrl,
        [string] $NatsUsername,
        [string] $NatsPassword,
        [bool] $NatsExternal,
        [string] $NatsImage,
        
        # Redis
        [string] $RedisUrl,
        [string] $RedisPassword,
        [bool] $RedisExternal,
        [string] $RedisImage,

        # Docker
        [string] $DockerNetwork,
        [ValidateSet("linux","windows")]
        [string] $DockerPlatform,
        [ValidateSet("process","hyperv")]
        [string] $DockerIsolation,
        [ValidateSet("no","on-failure","always","unless-stopped")]
        [string] $DockerRestartPolicy,
        [string] $DockerHost,
        [string] $SyslogServer,

        [switch] $Force
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath

    New-Item -Path $ConfigPath -ItemType "Directory" -Force | Out-Null

    $DenServerPath = Join-Path $ConfigPath "den-server"
    $DenPublicKeyFile = Join-Path $DenServerPath "den-public.pem"
    $DenPrivateKeyFile = Join-Path $DenServerPath "den-private.key"
    New-Item -Path $DenServerPath -ItemType "Directory" -Force | Out-Null

    if (!((Test-Path -Path $DenPublicKeyFile -PathType "Leaf") -and
          (Test-Path -Path $DenPrivateKeyFile -PathType "Leaf"))) {
            $KeyPair = New-RsaKeyPair -KeySize 2048
            Set-Content -Path $DenPublicKeyFile -Value $KeyPair.PublicKey -Force
            Set-Content -Path $DenPrivateKeyFile -Value $KeyPair.PrivateKey -Force
    }

    $config = [WaykBastionConfig]::new()
    
    $properties = [WaykBastionConfig].GetProperties() | ForEach-Object { $_.Name }
    foreach ($param in $PSBoundParameters.GetEnumerator()) {
        if ($properties -Contains $param.Key) {
            if ($param.Key -like "*Url") {
                $config.($param.Key) = ConvertTo-NormalizedUrlString $param.Value
            } else {
                $config.($param.Key) = $param.Value
            }
        }
    }

    Expand-WaykBastionConfigKeys -Config:$config

    Save-WaykBastionConfig -ConfigPath:$ConfigPath -Config:$Config -ConfigFormat $WaykBastionConfigFormat -ErrorAction 'Stop'

    Export-TraefikToml -ConfigPath:$ConfigPath
}

function Set-WaykBastionConfig
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
    
        # Server
        [string] $Realm,
        [string] $ExternalUrl,
        [string] $ListenerUrl,
        [string] $ServerMode,
        [ValidateSet("off","error", "warn", "info", "debug", "trace", IgnoreCase = $false)]
        [string] $ServerLogLevel,
        [int] $ServerCount,
        [string] $DenServerUrl,
        [string] $DenRouterUrl,
        [int] $DenKeepAliveInterval,
        [string] $DenApiKey,
        [bool] $DisableTelemetry,
        [bool] $ExperimentalFeatures,
        [bool] $ServerExternal,
        [string] $ServerImage,

        # MongoDB
        [string] $MongoUrl,
        [string] $MongoVolume,
        [bool] $MongoExternal,
        [string] $MongoImage,

        # Traefik
        [bool] $TraefikExternal,
        [string] $TraefikImage,

        # Jet
        [string] $JetRelayUrl,
        [int] $JetTcpPort,
        [bool] $JetExternal,
        [string] $JetRelayImage,

        # Picky
        [string] $PickyUrl,
        [bool] $PickyExternal,
        [string] $PickyImage,

        # Lucid
        [string] $LucidUrl,
        [string] $LucidApiKey,
        [bool] $LucidExternal,
        [string] $LucidImage,
        [ValidateSet("off","error", "warn", "info", "debug", "trace", IgnoreCase = $false)]
        [string] $LucidLogLevel,


        # NATS
        [string] $NatsUrl,
        [string] $NatsUsername,
        [string] $NatsPassword,
        [bool] $NatsExternal,
        [string] $NatsImage,
        
        # Redis
        [string] $RedisUrl,
        [string] $RedisPassword,
        [bool] $RedisExternal,
        [string] $RedisImage,

        # Docker
        [string] $DockerNetwork,
        [ValidateSet("linux","windows")]
        [string] $DockerPlatform,
        [ValidateSet("process","hyperv")]
        [string] $DockerIsolation,
        [ValidateSet("no","on-failure","always","unless-stopped")]
        [string] $DockerRestartPolicy,
        [string] $DockerHost,
        [string] $SyslogServer,

        [switch] $Force
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath

    $config = Get-WaykBastionConfig -ConfigPath:$ConfigPath

    New-Item -Path $ConfigPath -ItemType "Directory" -Force | Out-Null

    $properties = [WaykBastionConfig].GetProperties() | ForEach-Object { $_.Name }
    foreach ($param in $PSBoundParameters.GetEnumerator()) {
        if ($properties -Contains $param.Key) {
            if ($param.Key -like "*Url") {
                $config.($param.Key) = ConvertTo-NormalizedUrlString $param.Value
            } else {
                $config.($param.Key) = $param.Value
            }
        }
    }

    Expand-WaykBastionConfigKeys -Config:$config

    Save-WaykBastionConfig -ConfigPath:$ConfigPath -Config:$Config -ConfigFormat $WaykBastionConfigFormat -ErrorAction 'Stop'

    Export-TraefikToml -ConfigPath:$ConfigPath
}

function Get-WaykBastionConfig
{
    [CmdletBinding()]
    [OutputType('WaykBastionConfig')]
    param(
        [string] $ConfigPath,
        [switch] $Expand,
        [switch] $NonDefault
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath

    $config = [WaykBastionConfig]::new()

    $ConfigFileJson = Join-Path $ConfigPath "bastion.json"
    $ConfigFileYaml = Join-Path $ConfigPath "wayk-den.yml"

    if (Test-Path -Path $ConfigFileJson -PathType 'Leaf') {
        $ConfigFile = $ConfigFileJson
        $ConfigFormat = 'json'
    } elseif (Test-Path -Path $ConfigFileYaml -PathType 'Leaf') {
        $ConfigFile = $ConfigFileYaml
        $ConfigFormat = 'yaml'
    } else {
        throw "Config file not found in $ConfigPath"
    }

    if ($ConfigFormat -eq 'json') {
        $ConfigData = Get-Content -Path $ConfigFile -Encoding UTF8 -ErrorAction Stop
        $json = $ConfigData | ConvertFrom-Json

        [WaykBastionConfig].GetProperties() | ForEach-Object {
            $Name = $_.Name
            if ($json.PSObject.Properties[$Name]) {
                $Property = $json.PSObject.Properties[$Name]
                $Value = $Property.Value
                $config.$Name = $Value
            }
        }
    } else {
        $ConfigData = Get-Content -Path $ConfigFile -Raw -ErrorAction Stop
        $yaml = ConvertFrom-Yaml -Yaml $ConfigData -UseMergingParser -AllDocuments -Ordered

        [WaykBastionConfig].GetProperties() | ForEach-Object {
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

        # automatically convert to bastion.json format for next time (fail silently if we can't write config file)
        Save-WaykBastionConfig -ConfigPath:$ConfigPath -Config:$Config -ConfigFormat 'json' -ErrorAction 'SilentlyContinue'
    }

    if ($Expand) {
        Expand-WaykBastionConfig $config
    }

    if ($NonDefault) {
        # remove default properties from object
        $config = Remove-DefaultProperties $config $([WaykBastionConfig]::new())
    }

    return $config
}

function Clear-WaykBastionConfig
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
        [Parameter(Mandatory=$true,Position=0)]
        [string] $Filter
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath

    $config = [WaykBastionConfig]::new()

    $ConfigFileJson = Join-Path $ConfigPath "bastion.json"
    $ConfigFileYaml = Join-Path $ConfigPath "wayk-den.yml"

    if (Test-Path -Path $ConfigFileJson -PathType 'Leaf') {
        $ConfigFile = $ConfigFileJson
        $ConfigFormat = 'json'
    } elseif (Test-Path -Path $ConfigFileYaml -PathType 'Leaf') {
        $ConfigFile = $ConfigFileYaml
        $ConfigFormat = 'yaml'
    } else {
        throw "Config file not found in $ConfigPath"
    }

    if ($ConfigFormat -eq 'json') {
        $ConfigData = Get-Content -Path $ConfigFile -Encoding UTF8 -ErrorAction Stop
        $json = $ConfigData | ConvertFrom-Json

        [WaykBastionConfig].GetProperties() | ForEach-Object {
            $Name = $_.Name
            if ($Name -NotLike $Filter) {
                if ($json.PSObject.Properties[$Name]) {
                    if ($json.$Name -is [string]) {
                        if (![string]::IsNullOrEmpty($json.$Name)) {
                            $config.$Name = ($json.$Name).Trim()
                        }
                    } else {
                        $config.$Name = $json.$Name
                    }
                }
            }
        }
    } else {
        $ConfigData = Get-Content -Path $ConfigFile -Raw -ErrorAction Stop
        $yaml = ConvertFrom-Yaml -Yaml $ConfigData -UseMergingParser -AllDocuments -Ordered
    
        [WaykBastionConfig].GetProperties() | ForEach-Object {
            $Name = $_.Name
            if ($Name -NotLike $Filter) {
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
        }
    }

    Save-WaykBastionConfig -ConfigPath:$ConfigPath -Config:$Config -ConfigFormat $WaykBastionConfigFormat -ErrorAction 'Stop'
}

function Remove-WaykBastionConfig
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath
    Remove-Item -Path $(Join-Path $ConfigPath 'bastion.json') -Force
    Remove-Item -Path $(Join-Path $ConfigPath 'wayk-den.yml') -Force
    Remove-Item -Path $(Join-Path $ConfigPath 'den-server') -Recurse
    Remove-Item -Path $(Join-Path $ConfigPath 'traefik') -Recurse
}

function ConvertTo-NormalizedUrlString
{
    [OutputType('System.String')]
    param(
        [Parameter(Position=0)]
        [string] $Value
    )
    if (-Not [string]::IsNullOrEmpty($Value)) {
        $url = [System.Uri]::new($Value)
        $start = $url.Scheme + "://" + $url.DnsSafeHost
        $Value = $Value -IReplace $start, $start
    }
    $Value
}