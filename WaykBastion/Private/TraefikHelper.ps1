
function New-TraefikToml
{
    [OutputType('System.String')]
    param(
        [string] $Platform,
        [string] $ListenerUrl,
        [string] $LucidUrl,
        [string] $PickyUrl,
        [string] $DenRouterUrl,
        [string] $DenServerUrl,
        [bool] $JetExternal
    )

    $url = [System.Uri]::new($ListenerUrl)
    $Port = $url.Port
    $Protocol = $url.Scheme

    if ($Platform -eq "linux") {
        $PathSeparator = "/"
        $TraefikDataPath = "/etc/traefik"
    } else {
        $PathSeparator = "\"
        $TraefikDataPath = "c:\etc\traefik"
    }

    # note: .pem file should contain leaf cert + intermediate CA cert, in that order.

    $TraefikPort = $Port
    $TraefikEntrypoint = $Protocol
    $TraefikCertFile = $(@($TraefikDataPath, "den-server.pem") -Join $PathSeparator)
    $TraefikKeyFile = $(@($TraefikDataPath, "den-server.key") -Join $PathSeparator)

    # escape backslash characters
    $TraefikCertFile = $TraefikCertFile -replace '\\', '\\'
    $TraefikKeyFile = $TraefikKeyFile -replace '\\', '\\'

    $templates = @()

    $templates += '
logLevel = "INFO"

[file]

[entryPoints]
    [entryPoints.${TraefikEntrypoint}]
    address = ":${TraefikPort}"'

    if ($Protocol -eq 'https') {
        $templates += '
        [entryPoints.${TraefikEntrypoint}.tls]
            [entryPoints.${TraefikEntrypoint}.tls.defaultCertificate]
            certFile = "${TraefikCertFile}"
            keyFile = "${TraefikKeyFile}"'
    }

    $templates += '
        [entryPoints.${TraefikEntrypoint}.redirect]
        regex = "^http(s)?://([^/]+)/?`$"
        replacement = "http`$1://`$2/web"
    '

    $templates += '
[frontends]
    [frontends.lucid]
    passHostHeader = true
    backend = "lucid"
    entrypoints = ["${TraefikEntrypoint}"]
        [frontends.lucid.routes.lucid]
        rule = "PathPrefixStrip:/lucid"

    [frontends.lucidop]
    passHostHeader = true
    backend = "lucid"
    entrypoints = ["${TraefikEntrypoint}"]
        [frontends.lucidop.routes.lucidop]
        rule = "PathPrefix:/op"

    [frontends.lucidauth]
    passHostHeader = true
    backend = "lucid"
    entrypoints = ["${TraefikEntrypoint}"]
        [frontends.lucidauth.routes.lucidauth]
        rule = "PathPrefix:/auth"

    [frontends.picky]
    passHostHeader = true
    backend = "picky"
    entrypoints = ["${TraefikEntrypoint}"]
        [frontends.picky.routes.picky]
        rule = "PathPrefixStrip:/picky"

    [frontends.router]
    passHostHeader = true
    backend = "router"
    entrypoints = ["${TraefikEntrypoint}"]
        [frontends.router.routes.router]
        rule = "PathPrefixStrip:/cow"

    [frontends.server]
    passHostHeader = true
    backend = "server"
    entrypoints = ["${TraefikEntrypoint}"]
'

    if (-Not $JetExternal) {
        $templates += '
    [frontends.jet-relay]
    passHostHeader = true
    backend = "jet-relay"
    entrypoints = ["${TraefikEntrypoint}"]
        [frontends.jet-relay.routes.jet-relay]
        rule = "PathPrefix:/jet"
'
    }

    $templates += '
[backends]
    [backends.lucid]
        [backends.lucid.servers.lucid]
        url = "${LucidUrl}"
        weight = 10

    [backends.picky]
        [backends.picky.servers.picky]
        url = "${PickyUrl}"
        method="drr"
        weight = 10

    [backends.router]
        [backends.router.servers.router]
        url = "${DenRouterUrl}"
        method="drr"
        weight = 10

    [backends.server]
        [backends.server.servers.server]
        url = "${DenServerUrl}"
        weight = 10
        method="drr"
'

    if (-Not $JetExternal) {
            $templates += '
    [backends.jet-relay]
        [backends.jet-relay.servers.jet-relay]
        url = "http://devolutions-jet:7171"
        weight = 10
        method="drr"
'
    }

    $template = -Join $templates

    return Invoke-Expression "@`"`r`n$template`r`n`"@"
}
