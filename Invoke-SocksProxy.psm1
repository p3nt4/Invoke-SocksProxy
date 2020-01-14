<#
.SYNOPSIS

Powershell Socks Proxy
 
Author: p3nt4 (https://twitter.com/xP3nt4)
License: MIT
 
.DESCRIPTION
 
Creates a local or "reverse" Socks proxy using powershell.
 
Supports both Socks4 and Socks5 connections.
This is only a subset of the Socks 4 and 5 protocols: It does not support authentication, It does not support UDP or bind requests.
 
New features will be implemented in the future. PRs are welcome.
 
 .EXAMPLE_LOCAL
 
# Create a Socks proxy on port 1234:
Invoke-SocksProxy -bindPort 1234
# Change the number of threads from 200 to 400:
Invoke-SocksProxy -bindPort 1234 -threads 400

 .EXAMPLE_REVERSE
 
# On the remote host: 
# Generate a private key and self signed cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout private.key -out cert.pem
# Get the certificate fingerprint to verify it:
openssl x509 -in cert.pem -noout -sha1 -fingerprint | cut -d "=" -f 2 | tr -d ":"
# Start the handler
python ReverseSocksProxyHandler.py 443 1080 ./cert.pem ./private.key

# On the local host:
Import-Module .\Invoke-SocksProxy.psm1
Invoke-ReverseSocksProxy -remotePort 443 -remoteHost 192.168.49.130 
# Go through the system proxy:
Invoke-ReverseSocksProxy -remotePort 443 -remoteHost 192.168.49.130 -useSystemProxy
# Validate certificate
Invoke-ReverseSocksProxy -remotePort 443 -remoteHost 192.168.49.130 -certFingerprint '93061FDB30D69A435ACF96430744C5CC5473D44E'
# Give up after a number of failed connections to the handler:
Invoke-ReverseSocksProxy -remotePort 443 -remoteHost 192.168.49.130 -maxRetries 10
#>
 
 
 
[ScriptBlock]$SocksConnectionMgr = {
    param($vars)
    $Script = {
            param($vars)
            $vars.inStream.CopyTo($vars.outStream)
            Exit
    }
    $rsp=$vars.rsp;
    function Get-IpAddress{
        param($ip)
        IF ($ip -as [ipaddress]){
            return $ip
        }else{
            $ip2 = [System.Net.Dns]::GetHostAddresses($ip)[0].IPAddressToString;
        }
        return $ip2
    }
    $client=$vars.cliConnection
    $buffer = New-Object System.Byte[] 32
    try
    {
        $cliStream = $vars.cliStream
        $cliStream.Read($buffer,0,2) | Out-Null
        $socksVer=$buffer[0]
        if ($socksVer -eq 5){
            $cliStream.Read($buffer,2,$buffer[1]) | Out-Null
            for ($i=2; $i -le $buffer[1]+1; $i++) {
                if ($buffer[$i] -eq 0) {break}
            }
            if ($buffer[$i] -ne 0){
                $buffer[1]=255
                $cliStream.Write($buffer,0,2)
            }else{
                $buffer[1]=0
                $cliStream.Write($buffer,0,2)
            }
            $cliStream.Read($buffer,0,4) | Out-Null
            $cmd = $buffer[1]
            $atyp = $buffer[3]
            if($cmd -ne 1){
                $buffer[1] = 7
                $cliStream.Write($buffer,0,2)
                throw "Not a connect"
            }
            if($atyp -eq 1){
                $ipv4 = New-Object System.Byte[] 4
                $cliStream.Read($ipv4,0,4) | Out-Null
                $ipAddress = New-Object System.Net.IPAddress(,$ipv4)
                $hostName = $ipAddress.ToString()
            }elseif($atyp -eq 3){
                $cliStream.Read($buffer,4,1) | Out-Null
                $hostBuff = New-Object System.Byte[] $buffer[4]
                $cliStream.Read($hostBuff,0,$buffer[4]) | Out-Null
                $hostName = [System.Text.Encoding]::ASCII.GetString($hostBuff)
            }
            else{
                $buffer[1] = 8
                $cliStream.Write($buffer,0,2)
                throw "Not a valid destination address"
            }
            $cliStream.Read($buffer,4,2) | Out-Null
            $destPort = $buffer[4]*256 + $buffer[5]
            $destHost = Get-IpAddress($hostName)
            if($destHost -eq $null){
                $buffer[1]=4
                $cliStream.Write($buffer,0,2)
                throw "Cant resolve destination address"
            }
            $tmpServ = New-Object System.Net.Sockets.TcpClient($destHost, $destPort)
            if($tmpServ.Connected){
                $buffer[1]=0
                $buffer[3]=1
                $buffer[4]=0
                $buffer[5]=0
                $cliStream.Write($buffer,0,10)
                $cliStream.Flush()
                $srvStream = $tmpServ.GetStream() 
                $AsyncJobResult2 = $srvStream.CopyToAsync($cliStream)
                $AsyncJobResult = $cliStream.CopyToAsync($srvStream)
                $AsyncJobResult.AsyncWaitHandle.WaitOne();
                $AsyncJobResult2.AsyncWaitHandle.WaitOne();
                
            }
            else{
                $buffer[1]=4
                $cliStream.Write($buffer,0,2)
                throw "Cant connect to host"
            }
       }elseif($socksVer -eq 4){
            $cmd = $buffer[1]
            if($cmd -ne 1){
                $buffer[0] = 0
                $buffer[1] = 91
                $cliStream.Write($buffer,0,2)
                throw "Not a connect"
            }
            $cliStream.Read($buffer,2,2) | Out-Null
            $destPort = $buffer[2]*256 + $buffer[3]
            $ipv4 = New-Object System.Byte[] 4
            $cliStream.Read($ipv4,0,4) | Out-Null
            $destHost = New-Object System.Net.IPAddress(,$ipv4)
            $buffer[0]=1
            while ($buffer[0] -ne 0){
                $cliStream.Read($buffer,0,1)
            }
            $tmpServ = New-Object System.Net.Sockets.TcpClient($destHost, $destPort)
            
            if($tmpServ.Connected){
                $buffer[0]=0
                $buffer[1]=90
                $buffer[2]=0
                $buffer[3]=0
                $cliStream.Write($buffer,0,8)
                $cliStream.Flush()
                $srvStream = $tmpServ.GetStream() 
                $AsyncJobResult2 = $srvStream.CopyToAsync($cliStream)
                $AsyncJobResult = $cliStream.CopyTo($srvStream)
                $AsyncJobResult.AsyncWaitHandle.WaitOne();
                $AsyncJobResult2.AsyncWaitHandle.WaitOne();
            }
       }else{
            throw "Unknown socks version"
       }
    }
    catch {
        #$_ >> "error.log"
    }
    finally {
        if ($client -ne $null) {
            $client.Dispose()
        }
        if ($tmpServ -ne $null) {
            $tmpServ.Dispose()
        }
        Exit;
    }
}
 

function Invoke-SocksProxy{
    param (
 
            [String]$bindIP = "0.0.0.0",
 
            [Int]$bindPort = 1080,

            [Int]$threads = 200
 
     )
    try{
        $listener = new-object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Parse($bindIP), $bindPort)
        $listener.start()
        $rsp = [runspacefactory]::CreateRunspacePool(1,$threads);
        $rsp.CleanupInterval = New-TimeSpan -Seconds 30;
        $rsp.open();
        write-host "Listening on port $bindPort..."
        while($true){
            $client = $listener.AcceptTcpClient()
            $cliStream = $client.GetStream()
            Write-Host "New Connection from " $client.Client.RemoteEndPoint
            $vars = [PSCustomObject]@{"cliConnection"=$client; "rsp"=$rsp; "cliStream" = $cliStream}
            $PS3 = [PowerShell]::Create()
            $PS3.RunspacePool = $rsp;
            $PS3.AddScript($SocksConnectionMgr).AddArgument($vars) | Out-Null
            $PS3.BeginInvoke() | Out-Null
            Write-Host "Threads Left:" $rsp.GetAvailableRunspaces()
        }
     }
    catch{
        throw $_
    }
    finally{
        write-host "Server closed."
        if ($listener -ne $null) {
                  $listener.Stop()
           }
        if ($client -ne $null) {
            $client.Dispose()
            $client = $null
        }
        if ($PS3 -ne $null -and $AsyncJobResult3 -ne $null) {
            $PS3.EndInvoke($AsyncJobResult3) | Out-Null
            $PS3.Runspace.Close()
            $PS3.Dispose()
        }
    }
}

# Credit to Arno0x for this technique
function getProxyConnection{

    param (
 
            [String]$remoteHost,
 
            [Int]$remotePort

     )
    #Sleep -Milliseconds 500
    $request = [System.Net.HttpWebRequest]::Create("http://" + $remoteHost + ":" + $remotePort ) 
    $request.Method = "CONNECT";
    $proxy = [System.Net.WebRequest]::GetSystemWebProxy();
    $proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials;
    $request.Proxy = $proxy;
    $request.timeout = 1000;
    $serverResponse = $request.GetResponse();
    $request.timeout = 100000;
    $responseStream = $serverResponse.GetResponseStream()
    $BindingFlags= [Reflection.BindingFlags] "NonPublic,Instance"
    $rsType = $responseStream.GetType()
    $connectionProperty = $rsType.GetProperty("Connection", $BindingFlags)
    $connection = $connectionProperty.GetValue($responseStream, $null)
    $connectionType = $connection.GetType()
    $networkStreamProperty = $connectionType.GetProperty("NetworkStream", $BindingFlags)
    $serverStream = $networkStreamProperty.GetValue($connection, $null)
    return $connection, $serverStream
}


## EXPERIMENTAL.....
function Invoke-ReverseSocksProxy{
    param (
 
            [String]$remoteHost = "127.0.0.1",
 
            [Int]$remotePort = 1080,

            [Switch]$useSystemProxy = $false,

            [String]$certFingerprint = "",

            [Int]$threads = 200,

            [Int]$maxRetries = 0

     )
    try{
        $currentTry = 0;
        $rsp = [runspacefactory]::CreateRunspacePool(1,$threads);
        $rsp.CleanupInterval = New-TimeSpan -Seconds 30;
        $rsp.open();
        while($true){
            Write-Host "Connecting to: " $remoteHost ":" $remotePort
            try{
                if($useSystemProxy -eq $false){
                        $client = New-Object System.Net.Sockets.TcpClient($remoteHost, $remotePort)
                        $cliStream_clear = $client.GetStream()
                    }else{
                        $ret = getProxyConnection -remoteHost $remoteHost -remotePort $remotePort
                        $client = $ret[0]
                        $cliStream_clear = $ret[1]
                }
                if($certFingerprint -eq ''){
                    $cliStream = New-Object System.Net.Security.SslStream($cliStream_clear,$false,({$true} -as[Net.Security.RemoteCertificateValidationCallback]));
                }else{
                    $cliStream = New-Object System.Net.Security.SslStream($cliStream_clear,$false,({return $args[1].GetCertHashString() -eq $certFingerprint } -as[Net.Security.RemoteCertificateValidationCallback]));
                }
                $cliStream.AuthenticateAsClient($remoteHost)
                Write-Host "Connected"
                $currentTry = 0;
                $buffer = New-Object System.Byte[] 32
                $cliStream.ReadTimeout = 30000
                $cliStream.Read($buffer,0,5) | Out-Null
                $message = [System.Text.Encoding]::ASCII.GetString($buffer)
                if($message -ne "HELLO"){
                    throw "No Client connected";
                }else{
                    Write-Host "Connection received"
                }
                $cliStream.ReadTimeout = 100000;
                $vars = [PSCustomObject]@{"cliConnection"=$client; "rsp"=$rsp; "cliStream" = $cliStream}
                $PS3 = [PowerShell]::Create()
                $PS3.RunspacePool = $rsp;
                $PS3.AddScript($SocksConnectionMgr).AddArgument($vars) | Out-Null
                $PS3.BeginInvoke() | Out-Null
                Write-Host "Threads Left:" $rsp.GetAvailableRunspaces()
            }catch{
                $currentTry = $currentTry + 1;
                Write-Error $_;
                if (($maxRetries -ne 0) -and ($currentTry -eq $maxRetries)){
                    Throw "Cannot connect to handler, max Number of attempts reached, exiting";
                }
                if ($_.Exception.message -eq 'Exception calling "AuthenticateAsClient" with "1" argument(s): "The remote certificate is invalid according to the validation procedure."'){
                    throw $_
                }
                if ($_.Exception.message -eq 'Exception calling "AuthenticateAsClient" with "1" argument(s): "Authentication failed because the remote party has closed the transport stream."'){
                    sleep 5
                }

                if (($_.Exception.Message.Length -ge 121) -and $_.Exception.Message.substring(0,120) -eq 'Exception calling ".ctor" with "2" argument(s): "No connection could be made because the target machine actively refused'){
                    sleep 5
                }
                try{
                    $client.Close()
                    $client.Dispose()
                }catch{}
                    sleep -Milliseconds 200
                }
        }
     }
    catch{
        throw $_
    }
    finally{
        write-host "Server closed."
        if ($client -ne $null) {
            $client.Dispose()
            $client = $null
        }
        if ($PS3 -ne $null -and $AsyncJobResult3 -ne $null) {
            $PS3.EndInvoke($AsyncJobResult3) | Out-Null
            $PS3.Runspace.Close()
            $PS3.Dispose()
        }
    }
}
 


function Get-IpAddress{
    param($ip)
    IF ($ip -as [ipaddress]){
        return $ip
    }else{
        $ip2 = [System.Net.Dns]::GetHostAddresses($ip)[0].IPAddressToString;
        Write-Host "$ip resolved to $ip2"
    }
    return $ip2
}
export-modulemember -function Invoke-SocksProxy
export-modulemember -function Invoke-ReverseSocksProxy
