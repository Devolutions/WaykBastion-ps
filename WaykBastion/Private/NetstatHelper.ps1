
function Get-Netstat
{
    $netstat = Get-Command -Name 'netstat' -ErrorAction SilentlyContinue

    if (-Not $netstat) {
        Write-Warning "netstat command not available"
        return ,@()
    }

    if ($IsLinux) {
        # Linux netstat:
        # Proto Recv-Q Send-Q Local Address           Foreign Address         State
        # tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN
        # tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN
        # tcp        0      0 127.0.0.1:631           0.0.0.0:*               LISTEN

        $output = netstat -an --tcp | grep LISTEN

        foreach ($line in $output) {
            $line = $line.Trim()
            $line = $line -Split '\s+' # split line by whitespace
            $Protocol = $line[0]
            $LocalAddress = $line[3]
            $ForeignAddress = $line[4]
            $State = $line[5]

            # Linux uses ':' separator for port
            $LocalPort = $($LocalAddress -Split ':')[-1] -as [int]

            [PSCustomObject]@{
                Protocol = $Protocol
                LocalAddress = $LocalAddress
                LocalPort = $LocalPort
                ForeignAddress = $ForeignAddress
                State = $State
            }
        }
    }
    elseif ($IsMacOS) {
        # macOS netstat:
        # Proto Recv-Q Send-Q  Local Address          Foreign Address        (state)
        # tcp46      0      0  *.8080                 *.*                    LISTEN
        # tcp4       0      0  127.0.0.1.631          *.*                    LISTEN

        $output = netstat -an -p tcp | grep LISTEN

        foreach ($line in $output) {
            $line = $line.Trim()
            $line = $line -Split '\s+' # split line by whitespace
            $Protocol = $line[0]
            $LocalAddress = $line[3]
            $ForeignAddress = $line[4]
            $State = $line[5]

            # macOS uses '.' separator for port, replace it with ':'
            $LocalAddress = $LocalAddress -Replace '(.+)\.(\d+)', '$1:$2'
            $LocalPort = $($LocalAddress -Split ':')[-1] -as [int]

            [PSCustomObject]@{
                Protocol = $Protocol
                LocalAddress = $LocalAddress
                LocalPort = $LocalPort
                ForeignAddress = $ForeignAddress
                State = $State
            }
        }
    }
    else { # Windows
        # Windows netstat:
        # Proto  Local Address          Foreign Address        State
        # TCP    0.0.0.0:135            0.0.0.0:0              LISTENING
        # TCP    192.168.25.132:4489    0.0.0.0:0              LISTENING

        $output = netstat -an -p tcp | findstr LISTEN

        foreach ($line in $output) {
            $line = $line.Trim()
            $line = $line -Split '\s+' # split line by whitespace
            $Protocol = $line[0]
            $LocalAddress = $line[1]
            $ForeignAddress = $line[2]
            $State = $line[3]

            # Windows uses ':' separator for port
            $LocalPort = $($LocalAddress -Split ':')[-1] -as [int]

            # Normalize TCP state names according to
            # https://tools.ietf.org/html/rfc793#section-3.2

            if ($State -eq 'LISTENING') {
                $State = 'LISTEN' 
            }

            [PSCustomObject]@{
                Protocol = $Protocol
                LocalAddress = $LocalAddress
                LocalPort = $LocalPort
                ForeignAddress = $ForeignAddress
                State = $State
            }
        }
    }
}

function Get-LocalTcpPorts
{
    $netstat = Get-Netstat

    if ($netstat) {
        $netstat | Select-Object -ExpandProperty 'LocalPort'
    } else {
        return ,@()
    }
}

# Check if a TCP port is already taken:
# $(Get-LocalTcpPorts).Contains(3389)
