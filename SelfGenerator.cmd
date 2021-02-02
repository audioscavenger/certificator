@echo OFF
pushd %~dp0

powershell -executionPolicy bypass -Command $Certificate = New-SelfSignedCertificate -CertStoreLocation cert:\localmachine\my -dnsname %COMPUTERNAME%.%USERDNSDOMAIN%; copy-item -path cert:\LocalMachine\My\$Certificate.Thumbprint -Destination cert:\LocalMachine\Root\
