
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
    [int] $ServerCount
    [string] $DenServerUrl
    [string] $DenRouterUrl
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

    # LDAP
    [string] $LdapServerUrl
    [string] $LdapServerIp
    [string] $LdapUsername
    [string] $LdapPassword
    [string] $LdapUserGroup
    [string] $LdapServerType
    [string] $LdapBaseDn
    [string] $LdapBindType
    [bool] $LdapCertificateValidation = $false

    # Picky
    [string] $PickyUrl
    [bool] $PickyExternal = $false
    [string] $PickyImage

    # Lucid
    [string] $LucidUrl
    [string] $LucidApiKey
    [string] $LucidAdminUsername
    [string] $LucidAdminSecret
    [bool] $LucidExternal = $false
    [string] $LucidImage

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

function Find-WaykBastionConfig
{
    param(
        [string] $ConfigPath
    )

    if (-Not $ConfigPath) {
        $ConfigPath = Get-WaykBastionPath 'ConfigPath'
    }

    if (Test-Path -Path $(Join-Path $(Get-Location) "wayk-den.yml") -PathType "Leaf") {
        $ConfigPath = Get-Location
    }

    if ($Env:DEN_CONFIG_PATH) {
        $ConfigPath = $Env:DEN_CONFIG_PATH
    }

    return $ConfigPath
}

function Set-WaykBastionConfigPath
{
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [string] $ConfigPath
    )

    $Env:DEN_CONFIG_PATH = $ConfigPath
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

function Enter-WaykBastionConfigPath()
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0)]
        [ValidateSet("ConfigPath","GlobalPath","LocalPath")]
		[string] $PathType = "ConfigPath"
	)

    $ConfigPath = Find-WaykBastionConfig
    Set-Location $ConfigPath
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

    if (-Not $config.LucidAdminUsername) {
        $config.LucidAdminUsername = New-RandomString -Length 16
    }

    if (-Not $config.LucidAdminSecret) {
        $config.LucidAdminSecret = New-RandomString -Length 10
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
        [int] $ServerCount,
        [string] $DenServerUrl,
        [string] $DenRouterUrl,
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

        # LDAP
        [string] $LdapServerUrl,
        [string] $LdapServerIp,
        [string] $LdapUsername,
        [string] $LdapPassword,
        [string] $LdapUserGroup,
        [string] $LdapServerType,
        [string] $LdapBaseDn,
        [string] $LdapBindType,
        [bool] $LdapCertificateValidation,

        # Picky
        [string] $PickyUrl,
        [bool] $PickyExternal,
        [string] $PickyImage,

        # Lucid
        [string] $LucidUrl,
        [string] $LucidApiKey,
        [string] $LucidAdminUsername,
        [string] $LucidAdminSecret,
        [bool] $LucidExternal,
        [string] $LucidImage,

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
    $ConfigFile = Join-Path $ConfigPath "wayk-den.yml"

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
            $config.($param.Key) = $param.Value
        }
    }

    Expand-WaykBastionConfigKeys -Config:$config

    # remove default properties from object
    $config = Remove-DefaultProperties $config $([WaykBastionConfig]::new())

    ConvertTo-Yaml -Data (ConvertTo-SnakeCaseObject -Object $config) -OutFile $ConfigFile -Force:$Force

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
        [int] $ServerCount,
        [string] $DenServerUrl,
        [string] $DenRouterUrl,
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

        # LDAP
        [string] $LdapServerUrl,
        [string] $LdapServerIp,
        [string] $LdapUsername,
        [string] $LdapPassword,
        [string] $LdapUserGroup,
        [string] $LdapServerType,
        [string] $LdapBaseDn,
        [string] $LdapBindType,
        [bool] $LdapCertificateValidation,

        # Picky
        [string] $PickyUrl,
        [bool] $PickyExternal,
        [string] $PickyImage,

        # Lucid
        [string] $LucidUrl,
        [string] $LucidApiKey,
        [string] $LucidAdminUsername,
        [string] $LucidAdminSecret,
        [bool] $LucidExternal,
        [string] $LucidImage,

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
    $ConfigFile = Join-Path $ConfigPath "wayk-den.yml"

    $properties = [WaykBastionConfig].GetProperties() | ForEach-Object { $_.Name }
    foreach ($param in $PSBoundParameters.GetEnumerator()) {
        if ($properties -Contains $param.Key) {
            $config.($param.Key) = $param.Value
        }
    }

    Expand-WaykBastionConfigKeys -Config:$config

    # remove default properties from object
    $config = Remove-DefaultProperties $config $([WaykBastionConfig]::new())
 
    # always force overwriting wayk-den.yml when updating the config file
    ConvertTo-Yaml -Data (ConvertTo-SnakeCaseObject -Object $config) -OutFile $ConfigFile -Force

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

    $ConfigFile = Join-Path $ConfigPath "wayk-den.yml"
    $ConfigData = Get-Content -Path $ConfigFile -Raw -ErrorAction Stop
    $yaml = ConvertFrom-Yaml -Yaml $ConfigData -UseMergingParser -AllDocuments -Ordered

    $config = [WaykBastionConfig]::new()

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

    $ConfigFile = Join-Path $ConfigPath "wayk-den.yml"
    $ConfigData = Get-Content -Path $ConfigFile -Raw -ErrorAction Stop
    $yaml = ConvertFrom-Yaml -Yaml $ConfigData -UseMergingParser -AllDocuments -Ordered

    $config = [WaykBastionConfig]::new()

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

    # remove default properties from object
    $config = Remove-DefaultProperties $config $([WaykBastionConfig]::new())

    # always force overwriting wayk-den.yml when updating the config file
    ConvertTo-Yaml -Data (ConvertTo-SnakeCaseObject -Object $config) -OutFile $ConfigFile -Force
}

function Remove-WaykBastionConfig
{
    [CmdletBinding()]
    param(
        [string] $ConfigPath
    )

    $ConfigPath = Find-WaykBastionConfig -ConfigPath:$ConfigPath
    Remove-Item -Path $(Join-Path $ConfigPath 'wayk-den.yml')
    Remove-Item -Path $(Join-Path $ConfigPath 'den-server') -Recurse
    Remove-Item -Path $(Join-Path $ConfigPath 'traefik') -Recurse
}

Export-ModuleMember -Function New-WaykBastionConfig, Set-WaykBastionConfig, Get-WaykBastionConfig, `
    Clear-WaykBastionConfig, Remove-WaykBastionConfig, Set-WaykBastionConfigPath, Enter-WaykBastionConfigPath, Get-WaykBastionPath
