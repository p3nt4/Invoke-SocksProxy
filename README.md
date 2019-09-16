# Invoke-SocksProxy
Creates a local or "reverse" Socks proxy using powershell.

Supports both Socks4 and Socks5 connections.

# Examples

## Local 

Create a Socks 4/5 proxy on port 1080:
```
Import-Module .\Invoke-SocksProxy.psm1
Invoke-SocksProxy -bindPort 1080
```

Increase the number of threads from 200 to 400
```
Import-Module .\Invoke-SocksProxy.psm1
Invoke-SocksProxy -threads 400
```
## Reverse

Create a "reverse" Socks 4/5 proxy on port 1080 of a remote host:
```
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
Invoke-ReverseSocksProxy -remotePort 443 -remoteHost 192.168.49.130 -useSystemProxy -certFingerprint '93061FDB30D69A435ACF96430744C5CC5473D44E'
```

Credit: https://github.com/Arno0x/PowerShellScripts/blob/master/proxyTunnel.ps1


# Limitations
- This is only a subset of the Socks 4 and 5 protocols: It does not support authentication, It does not support UDP or bind requests.
- When the Socks Proxy runs out of available threads, new connections cannot be established until a thread is freed.
- New features will be implemented in the future. PR are welcome.


