
function New-RandomString
{
    [OutputType('string')]
    param(
        [Parameter(Mandatory=$true)]
        [int] $Length
    )

    $charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"

    $sb = [System.Text.StringBuilder]::new()
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()

    $bytes = New-Object Byte[] 4

    0 .. ($Length - 1) | % {
        $rng.GetBytes($bytes)
        $num = [System.BitConverter]::ToUInt32($bytes, 0)
        $sb.Append($charset[$num % $charset.Length]) | Out-Null
    }

    return $sb.ToString()
}
