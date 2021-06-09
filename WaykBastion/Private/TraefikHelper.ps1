
function New-TraefikConfig
{
    [OutputType('System.String')]
    param(
        [string] $Platform,
        [string] $ListenerUrl,
        [string] $ExternalUrl,
        [string] $LucidUrl,
        [string] $PickyUrl,
        [string] $DenRouterUrl,
        [string] $DenServerUrl,
        [bool] $JetExternal,
        [string] $GatewayUrl
    )

    $url = [System.Uri]::new($ExternalUrl)
    $ExternalScheme = $url.Scheme

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
    $TraefikYamlFile = $(@($TraefikDataPath, "traefik.yaml") -Join $PathSeparator)
    $TraefikCertFile = $(@($TraefikDataPath, "den-server.pem") -Join $PathSeparator)
    $TraefikKeyFile = $(@($TraefikDataPath, "den-server.key") -Join $PathSeparator)

    # escape backslash characters
    $TraefikCertFile = $TraefikCertFile -replace '\\', '\\'
    $TraefikKeyFile = $TraefikKeyFile -replace '\\', '\\'

    $traefik = [ordered]@{
        "log"         = [ordered]@{
            "level" = "WARN";
        }
        "providers"   = [ordered]@{
            "file" = [ordered]@{
                "watch"     = $true;
                "filename" = $TraefikYamlFile;
            }
        }
        "entryPoints" = [ordered]@{
            "web" = [ordered]@{
                "address" = "`:$TraefikPort";
            }
        }
        "http"        = [ordered]@{
            "routers"     = [ordered]@{
                "lucid"      = [ordered]@{
                    "rule"        = "PathPrefix(``/lucid``)";
                    "service"     = "lucid";
                    "middlewares" = @("lucid");
                }
                "picky"      = [ordered]@{
                    "rule"        = "PathPrefix(``/picky``)";
                    "service"     = "picky";
                    "middlewares" = @("picky");
                }
                "den-router" = [ordered]@{
                    "rule"        = "PathPrefix(``/cow``)";
                    "service"     = "den-router";
                    "middlewares" = @("den-router");
                }
                "den-server" = [ordered]@{
                    "rule"        = "PathPrefix(``/``)";
                    "service"     = "den-server";
                    "middlewares" = @("web-redirect");
                }
            }
            "middlewares" = [ordered]@{
                "lucid"        = [ordered]@{
                    "stripPrefix" = [ordered]@{
                        "prefixes" = @("/lucid")
                    }
                }
                "picky"        = [ordered]@{
                    "stripPrefix" = [ordered]@{
                        "prefixes" = @("/picky")
                    }
                }
                "den-router"   = [ordered]@{
                    "stripPrefix" = [ordered]@{
                        "prefixes" = @("/cow")
                    }
                }
                "web-redirect" = [ordered]@{
                    "redirectRegex" = [ordered]@{
                        "regex"       = "^http(s)?://([^/]+)/?$";
                        "replacement" = "${ExternalScheme}`://`$2/web";
                    }
                }
            }
            "services"    = [ordered]@{
                "lucid"      = [ordered]@{
                    "loadBalancer" = [ordered]@{
                        "passHostHeader" = $true;
                        "servers"        = @(
                            @{"url" = $LucidUrl }
                        )
                    }
                }
                "picky"      = [ordered]@{
                    "loadBalancer" = [ordered]@{
                        "passHostHeader" = $true;
                        "servers"        = @(
                            @{"url" = $PickyUrl }
                        )
                    }
                }
                "den-router" = [ordered]@{
                    "loadBalancer" = [ordered]@{
                        "passHostHeader" = $true;
                        "servers"        = @(
                            @{"url" = $DenRouterUrl }
                        )
                    }
                }
                "den-server" = [ordered]@{
                    "loadBalancer" = [ordered]@{
                        "passHostHeader" = $true;
                        "servers"        = @(
                            @{"url" = $DenServerUrl }
                        )
                    }
                }
            }
        }
    }

    if (-Not $JetExternal) {
        $traefik.http.routers.Add("gateway", [ordered]@{
                    "rule"        = "PathPrefix(``/jet``)";
                    "service"     = "gateway";
                })
        $traefik.http.services.Add("gateway", [ordered]@{
                    "loadBalancer" = [ordered]@{
                        "passHostHeader" = $true;
                        "servers"        = @(
                            @{"url" = $GatewayUrl }
                        )
                    }
                })
    }

    if ($Protocol -eq 'https') {
        $traefik.Add("tls", [ordered]@{
                "stores" = [ordered]@{
                    "default" = [ordered]@{
                        "defaultCertificate" = [ordered]@{
                            "certFile" = $TraefikCertFile;
                            "keyFile"  = $TraefikKeyFile;
                        }
                    }
                }
            })

        foreach ($router in $traefik.http.routers.GetEnumerator()) {
            $router.Value.Add("tls", @{})
        }
    }

    $traefik | ConvertTo-Yaml
}
