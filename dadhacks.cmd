:: this script is based off https://jamielinux.com/docs/openssl-certificate-authority/create-the-intermediate-pair.html
:: those 2 below are all CC of jamielinux but complete the setup nicely
:: http:\\dadhacks.org\2017\12\27\building-a-root-ca-and-an-intermediate-ca-using-openssl-and-debian-stretch\
:: https://www.golinuxcloud.com/openssl-create-certificate-chain-linux/

@echo OFF
pushd %~dp0

md dadhacks 2>NUL
echo|set /p=>dadhacks\index.txt
echo|set /p="unique_subject = yes">dadhacks\index.txt.attr
echo|set /p="01">dadhacks\crlnumber
echo|set /p="1000">dadhacks\serial


echo -------------------------------------------------------------------------------- CA
openssl genrsa -aes256 -passout pass:aaaa -out dadhacks\ca.DOMAINNAME.key 2048
IF %ERRORLEVEL% NEQ 0 pause
openssl req -batch -config dadhacks_root.cfg -new -x509 -sha512 -extensions v3_ca -key dadhacks\ca.DOMAINNAME.key -passin pass:aaaa -out dadhacks\ca.DOMAINNAME.crt -days 3650 -set_serial 0
IF %ERRORLEVEL% NEQ 0 pause
openssl x509 -noout -text -in dadhacks\ca.DOMAINNAME.crt

:: https://www.golinuxcloud.com/openssl-create-certificate-chain-linux/
openssl req -batch -new -x509 -days 3650 -config dadhacks_root.cfg -extensions v3_ca -key dadhacks\ca.DOMAINNAME.key -passin pass:aaaa -out dadhacks\ca.DOMAINNAME.crt



echo|set /p=>dadhacks\index.txt
echo|set /p="unique_subject = yes">dadhacks\index.txt.attr
echo|set /p="01">dadhacks\crlnumber
echo|set /p="1000">dadhacks\serial
echo -------------------------------------------------------------------------------- int
openssl req -batch -config dadhacks_intermediate.cfg -new -newkey rsa:2048 -keyout dadhacks\int.DOMAIN.key -passout pass:aaaa -out dadhacks\int.DOMAIN.csr
IF %ERRORLEVEL% NEQ 0 pause
openssl ca -batch -config dadhacks_root.cfg         -extensions v3_intermediate_ca -days 3650 -notext -md sha512 -in dadhacks\int.DOMAIN.csr -passin pass:aaaa -out dadhacks\int.DOMAIN.crt
IF %ERRORLEVEL% NEQ 0 pause
REM error below caused by # policy            = policy_strict
REM The organizationName field is different between
REM CA certificate (Organization ca) and the request (Organization int)


:: https://jamielinux.com/docs/openssl-certificate-authority/create-the-intermediate-pair.html
openssl genrsa -aes256 -passout pass:aaaa -out dadhacks\int.DOMAIN.key 2048
openssl req -batch -config dadhacks_intermediate.cfg -new -sha256 -passin pass:aaaa -key dadhacks\int.DOMAIN.key -out dadhacks\int.DOMAIN.csr
openssl ca -batch -config dadhacks_root.cfg -create_serial -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -passin pass:aaaa -in dadhacks\int.DOMAIN.csr -out dadhacks\int.DOMAIN.crt

type dadhacks\int.DOMAIN.crt dadhacks\ca.DOMAINNAME.crt >dadhacks\DOMAINNAME.chain.pem
openssl pkcs12 -inkey dadhacks\int.DOMAIN.key -passin pass:aaaa -passout pass:aaaa -in dadhacks\DOMAINNAME.chain.pem -export -out dadhacks\DOMAINNAME.chain.pfx


echo -------------------------------------------------------------------------------- www
REM 3-steps:
openssl genrsa -aes256 -passout pass:aaaa -out dadhacks\www.example.com 2048
openssl req -batch -config dadhacks_csr_san.cfg -new -sha256 -passin pass:aaaa -key dadhacks\int.DOMAIN.key -out dadhacks\int.DOMAIN.csr
openssl ca -batch -config dadhacks_intermediate.cfg -create_serial -extensions v3_server_cert -days 3650 -notext -md sha256 -passin pass:aaaa -in dadhacks\int.DOMAIN.csr -out dadhacks\int.DOMAIN.crt

REM 2-steps:
openssl req -batch -passout pass:aaaa -out dadhacks\www.example.com.csr -newkey rsa:2048 -nodes -keyout dadhacks\www.example.com.key -config dadhacks_csr_san.cfg
IF %ERRORLEVEL% NEQ 0 pause
openssl ca -batch -config dadhacks_intermediate.cfg -extensions v3_server_cert -days 3750 -notext -md sha512 -in dadhacks\www.example.com.csr -passin pass:aaaa -out dadhacks\www.example.com.crt
IF %ERRORLEVEL% NEQ 0 pause


echo -------------------------------------------------------------------------------- pfx
type dadhacks\www.example.com.crt dadhacks\int.DOMAIN.crt dadhacks\ca.DOMAINNAME.crt >dadhacks\chain.www.example.com.pem
openssl pkcs12 -inkey dadhacks\www.example.com.key -passin pass:aaaa -passout pass:aaaa -in dadhacks\chain.www.example.com.pem -export -out dadhacks\www.example.com.combined.pfx

REM openssl pkcs12 -inkey dadhacks\www.example.com.key -passin pass:aaaa -passout pass:aaaa -in dadhacks\www.example.com.crt -export -out dadhacks\www.example.com.combined.pfx
REM openssl pkcs12 -in dadhacks\www.example.com.combined.pfx -passin pass:aaaa -nodes -out dadhacks\www.example.com.combined.crt


pause