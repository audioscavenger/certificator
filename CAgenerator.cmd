@echo OFF
pushd %~dp0

:: Certificate output breakdown: https://www.misterpki.com/openssl-view-certificate/
REM openssl x509 -text -noout -in 
REM openssl s_client -showcerts -connect https://www.nqzw.com
REM openssl s_client -servername  www.nqzw.com -connect www.nqzw.com:443 | sed -ne "/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p" > www.nqzw.com.crt
REM openssl x509 -text -noout -in www.nqzw.com.crt

:: //TODO: separate CSR from KEY
:: //TODO: working example = microsoft.com certificate
:: //TODO: store Server serial.pem in its rightful folder

:: CANCEL:  2-step Ca + *.domain / separate CRT key     https://adfinis.com/en/blog/openssl-x509-certificates/
:: DONE:    2-step Ca + *.domain / separate CA/CRT keys https://gist.github.com/Dan-Q/4c7108f1e539ee5aefbb53a334320b27
:: CURRENT: 3-step complete CA + inter + *.domain + client https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
:: TOTEST:  3-step complete CA/IA/server https://raymii.org/s/tutorials/OpenSSL_command_line_Root_and_Intermediate_CA_including_OCSP_CRL%20and_revocation.html
:: TOTEST:  3-step complete CA/IA/server https://www.golinuxcloud.com/openssl-create-certificate-chain-linux/
:: KO:  3-step http://dadhacks.org/2017/12/27/building-a-root-ca-and-an-intermediate-ca-using-openssl-and-debian-stretch/
:: KO:  3-step https://jamielinux.com/docs/openssl-certificate-authority/create-the-root-pair.html

::  1.1.0   separated server csr from key; can regenerate csr
::  1.1.1   renamed root folder to just ORG_Root
::  1.1.2   using RSA keysize from cfg only
::  1.2.0   added CRL list generation
::  1.2.1   added questions to renew certificates
::  1.2.2   switched back to 3-step KEY+CSR+CRT generation
::  1.3.0   CA Browser EV Guidelines
::  1.3.1   added policiesOIDs
::  1.3.2   separated Root/Intermediate/Server for CA sections and altNames
::  1.3.3   added policy_match / policy_amything fields for EV
::  1.3.4   added permitted_intermediate_section
::  1.3.5   added @crl_section
::  1.3.6   added @alt_names_Server
::  1.3.7   added @ocsp_section
::  1.3.8   added working AIA: caIssuers + OCSP
::  1.3.9   added correct policyIdentifier
::  1.4.0   separated Root csr from key; can regenerate csr
::  1.5.0   following guidelines from 3 websites, separating root/subordinate/server/user cfg
::  1.5.1   renamed subordinate->intermediate because people

:init
set version=1.5.1
set author=lderewonko

call :detect_admin_mode
call :set_colors

REM set PAUSE=echo:
set PAUSE=pause
set DEMO=y
set RESET=y
set FORCE_Root=y
set FORCE_Intermediate=y
set FORCE_Server=y
set IMPORT_PFX=n


:prechecks
for %%x in (powershell.exe) do (set "powershell=%%~$PATH:x")
IF NOT DEFINED powershell call :error %~0: powershell NOT FOUND

call :check_exist_exit openssl.TEMPLATE.Root.cfg
call :check_exist_exit openssl.TEMPLATE.intermediate.cfg
call :check_exist_exit openssl.TEMPLATE.server.cfg
call :check_exist_exit openssl.TEMPLATE.Root.cmd
call :check_exist_exit openssl.TEMPLATE.intermediate.cmd
call :check_exist_exit openssl.TEMPLATE.server.cmd



:defaults
set ENCRYPTION=RSA
set ORG_Root_DEMO=YOURORG
set ORG_Intermediate_DEMO=YOURDOMAIN
set DOMAIN_DEMO=INTERNAL.YOURDOMAIN.LOCAL
set ORG_Root=%ORG_Root_DEMO%
set ORG_Intermediate=%ORG_Intermediate_DEMO%
set DOMAIN=%DOMAIN_DEMO%
IF DEFINED DEMO goto :main

set ORG_Root=
set ORG_Intermediate=%USERDOMAIN%
set DOMAIN=%USERDNSDOMAIN%
set /P         ORG_Root=Organisation?  [%ORG_Root%] 
set /P ORG_Intermediate=Intermediate?  [%ORG_Intermediate%] 
set /P           DOMAIN=Server DOMAIN? [%DOMAIN%] 
set /P       ENCRYPTION=ENCRYPTION?    [%ENCRYPTION%/ECC] 
)
IF NOT DEFINED ORG_Root         call :error Organisation is required
IF NOT DEFINED ORG_Intermediate call :error Intermediate is required
IF NOT DEFINED DOMAIN           call :error DOMAIN is required

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:main
call :set_variables
call :create_folders
call :reset
call :init_cmd
call :init_cfg

:: https://sectigo.com/resource-library/rsa-vs-dsa-vs-ecc-encryption
::    RSA     ECC
::    1024    160
::    2048    224
::    3072    256
::    7680    384
::    15360   521
:: https://crypto.stackexchange.com/questions/70889/is-curve-p-384-equal-to-secp384r1?newreg=a86ae3c6cbfd427e94e0a8682450c2cf
:: ASN1 OID: secp521r1 == NIST CURVE: P-521 = NIST/SECG curve over a 384 bit prime field
:: prime256v1                               = X9.62/SECG curve over a 256 bit prime field

call :create_KEY_Root_%ENCRYPTION%
%PAUSE%
call :create_CRT_Root
%PAUSE%
REM call :create_PFX_Root // this makes no sense with Intermediate CA

call :create_KEY_Intermediate_%ENCRYPTION%
%PAUSE%
call :create_CSR_Intermediate
%PAUSE%
call :create_CRT_Intermediate
%PAUSE%
call :create_PFX_IntermediateChain
%PAUSE%
call :create_CRL_Intermediate
%PAUSE%

call :create_KEY_Server_RSA
%PAUSE%
call :create_CSR_Server
%PAUSE%
call :create_CRT_Server
%PAUSE%
call :create_PFX_chainServer
%PAUSE%
call :create_CRL_Server
%PAUSE%

:: //TODO: test revoking
REM call :revoke_CRT_Intermediate
REM call :revoke_CRT_Server

goto :end
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


:set_variables
echo %c%%~0%END%

:: we don't provide cfgCAIntermediate to the client the CAServer is for
:: we do    provide    CAIntermediate to the client the CAServer is for so they can generate more CAServers
set cfgCARoot=%ORG_Root%\openssl.%ORG_Root%
set cfgCAIntermediate=%ORG_Root%\openssl.%ORG_Intermediate%
set cfgCAServer=%ORG_Root%\%ORG_Intermediate%\openssl.%DOMAIN%
set CARoot=%ORG_Root%\ca.%ORG_Root%
set CAIntermediate=%ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%
set CAServer=%ORG_Root%\%ORG_Intermediate%\%DOMAIN%

:: OPENSSL_CONF must have full path, and extension cfg on Windows. don't ask me why.
:: we don't use it anymore because we need to pass config directly to each command
REM set OPENSSL_CONF=%~dp0\openssl.github.cfg
REM set OPENSSL_CONF=%~dp0\openssl.cfg
REM set OPENSSL_CONF=%~dp0\openssl.MIT.cfg
REM set OPENSSL_CONF=%~dp0\openssl.pki-tutorial.cfg
REM set OPENSSL_CONF=%~dp0\openssl.%ORG_Root%.cfg
REM set OPENSSL_CONF=%~dp0\openssl.%ORG_Root%.cfg

goto :EOF


:create_folders
echo %c%%~0%END%

IF EXIST %ORG_Root%\%ORG_Intermediate%\ exit /b 0

md %ORG_Root%\ 2>NUL
md %ORG_Root%\%ORG_Intermediate% 2>NUL
REM md %ORG_Root%\certs 2>NUL
REM md %ORG_Root%\crl 2>NUL
REM md %ORG_Root%\newcerts 2>NUL
REM md %ORG_Root%\private 2>NUL
REM md %ORG_Root%\req 2>NUL
goto :EOF


:reset
echo %c%%~0%END%

IF /I "%RESET%"=="y" (
  for %%e in (cfg txt key csr crt pem pfx) DO (
    del /f /q /s %ORG_Root%\*.%%e 2>NUL
    del /f /q /s %ORG_Root%\%ORG_Intermediate%\*.%%e 2>NUL
  )
  del /f /q /s %ORG_Root%\crlnumber 2>NUL
  del /f /q /s %ORG_Root%\serial 2>NUL
  del /f /q /s %ORG_Root%\%ORG_Intermediate%\crlnumber 2>NUL
  del /f /q /s %ORG_Root%\%ORG_Intermediate%\serial 2>NUL
)

IF EXIST %CARoot%.crt         set /P          FORCE_Root=Regenerate Root cert?         [%FORCE_Root%] 
IF EXIST %CAIntermediate%.crt set /P  FORCE_Intermediate=Regenerate Intermediate cert? [%FORCE_Intermediate%] 
IF EXIST %CAServer%.crt       set /P    FORCE_Server=Regenerate Server cert?       [%FORCE_Server%] 

:: https://serverfault.com/questions/857131/odd-error-while-using-openssl
:: https://www.linuxquestions.org/questions/linux-security-4/why-can%27t-i-generate-a-new-certificate-with-openssl-312716/
IF NOT EXIST %ORG_Root%\index.txt echo|set /p=>%ORG_Root%\index.txt
IF NOT EXIST %ORG_Root%\index.txt.attr echo|set /p="unique_subject = yes">%ORG_Root%\index.txt.attr
IF NOT EXIST %ORG_Root%\%ORG_Intermediate%\index.txt echo|set /p=>%ORG_Root%\index.txt
IF NOT EXIST %ORG_Root%\%ORG_Intermediate%\index.txt.attr echo|set /p="unique_subject = yes">%ORG_Root%\index.txt.attr

:: https://serverfault.com/questions/823679/openssl-error-while-loading-crlnumber
IF NOT EXIST %ORG_Root%\crlnumber echo|set /p="01">%ORG_Root%\crlnumber
IF NOT EXIST %ORG_Root%\serial echo|set /p="1000">%ORG_Root%\serial
IF NOT EXIST %ORG_Root%\%ORG_Intermediate%\crlnumber echo|set /p="01">%ORG_Root%\crlnumber
IF NOT EXIST %ORG_Root%\%ORG_Intermediate%\serial echo|set /p="1000">%ORG_Root%\serial

goto :EOF


:init_cmd
echo %c%%~0%END%

IF EXIST %cfgCARoot%.cmd IF EXIST %cfgCAIntermediate%.cmd IF EXIST %cfgCAServer%.cmd exit /b 0
IF NOT EXIST %cfgCARoot%.cmd    copy openssl.TEMPLATE.Root.cmd          %cfgCARoot%.cmd
IF NOT EXIST %cfgCARoot%.cmd    copy openssl.TEMPLATE.Intermediate.cmd  %cfgCAIntermediate%.cmd
IF NOT EXIST %cfgCAServer%.cmd  copy openssl.TEMPLATE.Server.cmd        %cfgCAServer%.cmd

echo:
echo   %HIGH%Please edit all the %c%%ORG_Root%\*\openssl.*.cmd%w%
echo                            Then restart this batch%END%
echo                                   Thank you
echo:
pause
exit 99
goto :EOF


:init_cfg
echo %c%%~0%END%

call %cfgCARoot%.cmd
call :create_cfg openssl.TEMPLATE.Root.cfg openssl.%ORG_Root%.cfg
call %cfgCAIntermediate%.cmd
call :create_cfg openssl.TEMPLATE.Intermediate.cfg openssl.%ORG_Intermediate%.cfg
call %cfgCAServer%.cmd
call :create_cfg openssl.TEMPLATE.Server.cfg openssl.%DOMAIN%.cfg

goto :EOF


:create_cfg in out
echo %c%%~0%END%

:: too slow:
copy /y %1 %2
REM for /f "eol=: tokens=1,2 delims==" %%V in (openssl.ORG_Root.cmd) DO (
  REM powershell -executionPolicy bypass -Command "(Get-Content -Path '%~2') -replace '{%%V}', '%%W' | Set-Content -Path '%~2'"
REM )

powershell -executionPolicy bypass -Command ^(Get-Content %1^) ^| Foreach-Object { ^
    $_ -replace '{DOMAIN}', '%DOMAIN%' `^
       -replace '{ORG_Root}', '%ORG_Root%' `^
       -replace '{ORG_Intermediate}', '%ORG_Intermediate%' `^
       -replace '{ORG_Server}', '%ORG_Server%' `^
       -replace '{default_days}', '%default_days%' `^
       -replace '{default_days_Root}', '%default_days_Root%' `^
       -replace '{default_days_Intermediate}', '%default_days_Intermediate%' `^
       -replace '{default_days_Server}', '%default_days_Server%' `^
       -replace '{default_md}', '%default_md%' `^
       -replace '{default_md_Root}', '%default_md_Root%' `^
       -replace '{default_md_Intermediate}', '%default_md_Intermediate%' `^
       -replace '{default_md_Server}', '%default_md_Server%' `^
       -replace '{default_bits}', '%default_bits%' `^
       -replace '{default_bits_Root}', '%default_bits_Root%' `^
       -replace '{default_bits_Intermediate}', '%default_bits_Intermediate%' `^
       -replace '{default_bits_Server}', '%default_bits_Server%' `^
       -replace '{default_ECC}', '%default_ECC%' `^
       -replace '{default_ECC_Root}', '%default_ECC_Root%' `^
       -replace '{default_ECC_Intermediate}', '%default_ECC_Intermediate%' `^
       -replace '{default_ECC_Server}', '%default_ECC_Server%' `^
       -replace '{PASSWORD_Root}', '%PASSWORD_Root%' `^
       -replace '{PASSWORD_Intermediate}', '%PASSWORD_Intermediate%' `^
       -replace '{PASSWORD_Server}', '%PASSWORD_Server%' `^
       -replace '{PASSWORD_PFX_Intermediate}', '%PASSWORD_PFX_Intermediate%' `^
       -replace '{PASSWORD_PFX_Server}', '%PASSWORD_PFX_Server%' `^
       -replace '{countryName}', '%countryName%' `^
       -replace '{stateOrProvinceName}', '%stateOrProvinceName%' `^
       -replace '{localityName}', '%localityName%' `^
       -replace '{organizationName}', '%organizationName%' `^
       -replace '{organizationalUnitName}', '%organizationalUnitName%' `^
       -replace '{commonName}', '%commonName%' `^
       -replace '{emailAddress}', '%emailAddress%' `^
       -replace '{postalCode}', '%postalCode%' `^
       -replace '{streetAddress}', '%streetAddress%' `^
       -replace '{unstructuredName}', '%unstructuredName%' `^
       -replace '{policiesOIDsIntermediate}', '%policiesOIDsIntermediate%' `^
       -replace '{policiesOIDsSubscriber}', '%policiesOIDsIntermediate%' `^
       -replace '{policyIdentifier}', '%policyIdentifier%' `^
       -replace '{CPS.1}', '%CPS.1%' `^
       -replace '{CPS.2}', '%CPS.2%' `^
       -replace '{explicitText}', '%explicitText%' `^
       -replace '{organization}', '%organization%' `^
       -replace '{businessCategory}', '%businessCategory%' `^
       -replace '{serialNumber}', '%serialNumber%' `^
       -replace '{jurisdictionCountryName}', '%jurisdictionCountryName%' `^
       -replace '{authorityInfoAccessOCSP}', '%authorityInfoAccessOCSP%' `^
       -replace '{authorityInfoAccessCaIssuers}', '%authorityInfoAccessCaIssuers%' `^
       -replace '{crlDistributionPoints.1}', '%crlDistributionPoints.1%'^
    } ^| Set-Content %2

:: special case for altnames:
for /f "tokens=1,2 delims==" %%V in ('set DNS.') DO echo %%V=%%W>>%2
for /f "tokens=1,2 delims==" %%V in ('set IP.') DO echo %%V=%%W>>%2

goto :EOF

:O---------O
:Root
:O---------O

:create_KEY_Root_RSA
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl rsa -batch -config %cfgCARoot%.cfg -noout -text -passin pass:%PASSWORD_Root% -in %CARoot%.key %END%

IF EXIST %CARoot%.key exit /b 0

:: 2-steps:
:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl genrsa -batch -config %cfgCARoot% -aes-256-cbc -passout pass:%PASSWORD_Root% -out %CARoot%.key
:: deprecation: https://serverfault.com/questions/590140/openssl-genrsa-vs-genpkey
openssl genpkey -batch -config %cfgCARoot% -algorithm RSA -pkeyopt rsa_keygen_bits:%default_bits_Root% -pass pass:%PASSWORD_Root% -out %CARoot%.key -aes-256-cbc

:: 1-step:
REM openssl req -batch -config %cfgCARoot%.cfg -new -nodes -keyout %CARoot%.key -passout pass:%PASSWORD_Root% -out %CARoot%.csr
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: view it:
REM openssl rsa -noout -text -in %CARoot%.key -passin pass:%PASSWORD_Root%
goto :EOF


:create_KEY_Root_ECC
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl ec -noout -text -passin pass:%PASSWORD_Root% -in %CARoot%.key %END%

IF EXIST %CARoot%.key exit /b 0

:: https://www.ibm.com/support/knowledgecenter/en/SSB27H_6.2.0/fa2ti_openssl_using_ECCdhersa_generate_ECC_key.html
:: https://stackoverflow.com/questions/64961096/what-is-the-suggested-openssl-command-to-generate-ec-key-and-csr-compatible-with
:: https://www.openssl.org/docs/man1.1.0/man1/genpkey.html
:: options 1: why you need to store the params: https://wiki.openssl.org/index.php/Command_Line_Elliptic_Curve_Operations
openssl ecparam -batch -config %cfgCARoot% -out %CARoot%.param.crt -name secp%default_ECC_Root%r1 -param_enc explicit
openssl genpkey -batch -config %cfgCARoot% -paramfile %CARoot%.param.crt -pass pass:%PASSWORD_Root% -out %CARoot%.key

:: options 1b:
REM openssl genpkey -batch -config %cfgCARoot% -algorithm EC -out %CARoot%.key -pkeyopt ec_paramgen_curve:P-%default_ECC_Root% -pkeyopt ec_param_enc:named_curve

:: options 2:
REM openssl x509 -batch -config %cfgCARoot% -req -%default_md% -days %default_days_Root% -extensions v3_ca -in %CARoot%.csr -signkey %CARoot%.key -passout pass:%PASSWORD_Root% -out %CARoot%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: view it:
REM openssl ec -noout -text -passin pass:%PASSWORD_Root% -in %CARoot%.key
goto :EOF


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: -extensions val     CERT extension section (override value in config file)
:: -reqexts val        REQ  extension section (override value in config file)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


:create_CRT_Root
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl x509 -text -noout -in %CARoot%.crt %END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %CARoot%.crt %END%

IF EXIST %CARoot%.crt IF /I NOT "%FORCE_Root%"=="y" exit /b 0

REM -subj: M$ and gg have same group but M$ also has country -subj "/CN=%ORG_Root% Root/OU=%ORG_Root% CA/O=%ORG_Root%"
openssl req -batch -config %cfgCARoot% -new -x509 -%default_md_Root% -passin pass:%PASSWORD_Root% -extensions v3_ca -key %CARoot%.key -out %CARoot%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

certutil -dump %CARoot%.crt | findstr /b /c:"Cert Hash(sha1)" | for /f "tokens=3" %%t in ('more') do @echo %c%THUMBPRINT =%END% %%t

:: view it:
openssl x509 -text -noout -in %CARoot%.crt

:: verify it:
REM certutil -verify -urlfetch %CARoot%.crt

goto :EOF


:import_CRT_Root_PEM
echo %c%%~0%END%

:: https://medium.com/better-programming/trusted-self-signed-certificate-and-local-domains-for-testing-7c6e6e3f9548
:: no friendly name with PEM
echo certutil -f -addstore "Root" %CARoot%.crt
certutil -f -addstore "Root" %CARoot%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

goto :EOF


:O---------O
:Intermediate
:O---------O

:create_KEY_Intermediate_RSA
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl rsa -noout -text -in %CAIntermediate%.key %END%

IF EXIST %CAIntermediate%.key exit /b 0

:: 2-steps:
:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl genrsa -batch -config %cfgCAIntermediate%.cfg -passout pass:%PASSWORD_Intermediate% -out %CAIntermediate%.key
:: deprecation: https://serverfault.com/questions/590140/openssl-genrsa-vs-genpkey
openssl genpkey -batch -config %cfgCAIntermediate%.cfg -algorithm RSA -pkeyopt rsa_keygen_bits:%default_bits_Intermediate% -pass pass:%PASSWORD_Intermediate% -out %CAIntermediate%.key -aes-256-cbc
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: view it:
REM openssl rsa -noout -text -in %CAIntermediate%.key
goto :EOF


:create_KEY_Intermediate_ECC
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl ec -noout -text -passin pass:%PASSWORD_Intermediate% -in %CAIntermediate%.key %END%

IF EXIST %CAIntermediate%.key exit /b 0

:: https://www.ibm.com/support/knowledgecenter/en/SSB27H_6.2.0/fa2ti_openssl_using_ECCdhersa_generate_ECC_key.html
:: https://stackoverflow.com/questions/64961096/what-is-the-suggested-openssl-command-to-generate-ec-key-and-csr-compatible-with
:: https://www.openssl.org/docs/man1.1.0/man1/genpkey.html
:: options 1: why you need to store the params: https://wiki.openssl.org/index.php/Command_Line_Elliptic_Curve_Operations
openssl ecparam -batch -config %cfgCAIntermediate%.cfg -out %CAIntermediate%.param.crt -name secp%default_ECC_Intermediate%r1
openssl genpkey -batch -config %cfgCAIntermediate%.cfg -paramfile %CAIntermediate%.param.crt -pass pass:%PASSWORD_Intermediate% -out %CAIntermediate%.key

:: options 2:
REM openssl genpkey -batch -config %cfgCAIntermediate%.cfg -algorithm EC -out %CAIntermediate%.key -pkeyopt ec_paramgen_curve:P-%default_ECC_Intermediate% -pkeyopt ec_param_enc:named_curve

IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: view it:
REM openssl ec -noout -text -passin pass:%PASSWORD_Intermediate% -in %CAIntermediate%.key
goto :EOF


:create_CSR_Intermediate
echo %c%%~0%END%
:: verify it:
echo %HIGH%%b%  openssl req -verify -in %CAIntermediate%.csr -text -noout %END%

IF EXIST %CAIntermediate%.crt IF /I NOT "%FORCE_Intermediate%"=="y" exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
:: you don't have to specify rsa keysize here, it's using the private key size
REM -newkey rsa:%default_bits_Intermediate%
:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM M$ and gg both have same group -subj "/CN=%ORG_Intermediate% Root/O=%ORG_Root%/C=%countryName%"
openssl req -batch -config %cfgCAIntermediate%.cfg -new -nodes -key %CAIntermediate%.key -passin pass:%PASSWORD_Intermediate% -out %CAIntermediate%.csr
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: verify it:
REM openssl req -verify -in %CAIntermediate%.csr -text -noout
goto :EOF


:create_CRT_Intermediate
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl x509 -text -noout -in %CAIntermediate%.crt %END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %CAIntermediate%.crt %END%

IF EXIST %CAIntermediate%.crt IF /I NOT "%FORCE_Intermediate%"=="y" exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl x509 -req -%default_md_Intermediate% -days %default_days_Intermediate% -CA %CARoot%.crt -CAkey %CARoot%.key -CAcreateserial -CAserial %CAIntermediate%.srl -extfile openssl.%ORG_Root%.cfg -extensions v3_intermediate_ca -in %CAIntermediate%.csr -out %CAIntermediate%.crt

:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM -startdate val          Cert notBefore, YYMMDDHHMMSSZ
REM -enddate val            YYMMDDHHMMSSZ cert notAfter (overrides -days)
REM -create_serial          will generate serialNumber into serialNumber.pem
REM -rand_serial            will generate serialNumber everytime and not store it, but actually it does
REM -md %default_md_Intermediate%        sha256 sha512
REM -extfile openssl.%ORG_Root%.cfg
REM -updatedb
REM -notext
REM echo|set /p=>%ORG_Root%\index.txt
:: WARNING using cfgCARoot to sign the Intermediate CSR is indeed correct!
:: That is why we cannot let the client regenerate the CAIntermediate themselves: they would need the CARoot password
openssl ca -batch -config %cfgCARoot% -create_serial -passin pass:%PASSWORD_Root% -extensions v3_intermediate_ca -in %CAIntermediate%.csr -out %CAIntermediate%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

certutil -dump %CAIntermediate%.crt | findstr /b /c:"Cert Hash(sha1)" | for /f "tokens=3" %%t in ('more') do @echo %c%THUMBPRINT =%END% %%t

:: view it:
REM openssl x509 -text -noout -in %CAIntermediate%.crt

:: verify it:
REM certutil -verify -urlfetch %CAIntermediate%.crt
REM openssl verify -CAfile %CARoot%.crt %CAIntermediate%.crt

goto :EOF


:create_PFX_IntermediateChain
echo %c%%~0%END%

:: create chain pem for Apache/nginx:
type %CAIntermediate%.crt %CARoot%.crt >%CAIntermediate%.chain.pem

:: convert chain to PFX for Windows:
openssl pkcs12 -export -name "%ORG_Intermediate% RSA TLS CA" -inkey %CAIntermediate%.key -passin pass:%PASSWORD_Intermediate% -in %CAIntermediate%.chain.pem -passout pass:aaaa -out %CAIntermediate%.chain.pfx

:: https://www.phildev.net/ssl/creating_ca.html
REM openssl pkcs12 -export -name "%ORG_Intermediate% RSA TLS CA" -inkey %CAIntermediate%.key -passin pass:%PASSWORD_Intermediate% -in %CAIntermediate%.crt -chain -CAfile %CARoot%.crt -passout pass:%PASSWORD_PFX_Intermediate% -out %CAIntermediate%.pfx
IF %ERRORLEVEL% NEQ 0 pause & exit 1

echo %b% certutil -importPFX -f -p %PASSWORD_PFX_Intermediate% %CAIntermediate%.pfx %END%
echo certutil -importPFX -f -p %PASSWORD_PFX_Intermediate% %CAIntermediate%.pfx >%CAIntermediate%.pfx.cmd

goto :EOF


:create_CRL_Intermediate
echo %c%%~0%END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %CAIntermediate%.crt %END%

:: https://blog.didierstevens.com/2013/05/08/howto-make-your-own-cert-and-revocation-list-with-openssl/
:: Generate an empty CRL (both in PEM and DER):
openssl ca -batch -config %cfgCAIntermediate%.cfg -gencrl -keyfile %CAIntermediate%.key -cert %CAIntermediate%.crt -out %CAIntermediate%.crl.crt
openssl crl -batch -config %cfgCAIntermediate%.cfg -inform PEM -in %CAIntermediate%.crl.crt -outform DER -out %CAIntermediate%.crl

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %CAIntermediate%.crt %END%
:: verify it:
REM certutil -verify -urlfetch %CAIntermediate%.crt

:: a Windows Server 2003 CA will always check revocation on all certificates in the PKI hierarchy (except the root CA certificate) before issuing an end-entity certificate. However in this situation, a valid Certificate Revocation List (CRL) for one or more of the intermediate certification authority (CA) certificates was not be found since the root CA was offline. This issue may occur if the CRL is not available to the certificate server, or if the CRL has expired.
:: You may disabled the feature that checks revocation on all certificates in the PKI hierarchy with the following command on the CA:

REM certutil –setreg ca\CRLFlags +CRLF_REVCHECK_IGNORE_OFFLINE
goto :EOF


:O---------O
:Server
:O---------O

:create_KEY_Server_RSA
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl rsa -batch -noout -text -in %CAServer%.key %END%

IF EXIST %CAServer%.key exit /b 0

:: 2-steps:
:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl genrsa -batch -config %cfgCAServer%.cfg -passout pass:%PASSWORD_Intermediate% -out %CAServer%.key
:: deprecation: https://serverfault.com/questions/590140/openssl-genrsa-vs-genpkey
openssl genpkey -batch -config %cfgCAServer%.cfg -algorithm RSA -pkeyopt rsa_keygen_bits:%default_bits_Root% -pass pass:%PASSWORD_Server% -out %CAServer%.key -aes-256-cbc

IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: view it:
REM openssl rsa -noout -text -in %CAServer%.key
goto :EOF


:create_KEY_Server_ECC
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl ec -noout -text -passin pass:%PASSWORD_Server% -in %CAServer%.key %END%

IF EXIST %CAServer%.key exit /b 0

:: https://www.ibm.com/support/knowledgecenter/en/SSB27H_6.2.0/fa2ti_openssl_using_ECCdhersa_generate_ECC_key.html
:: https://stackoverflow.com/questions/64961096/what-is-the-suggested-openssl-command-to-generate-ec-key-and-csr-compatible-with
:: https://www.openssl.org/docs/man1.1.0/man1/genpkey.html
:: options 1: why you need to store the params: https://wiki.openssl.org/index.php/Command_Line_Elliptic_Curve_Operations
openssl ecparam -batch -config %cfgCAServer%.cfg -out %CAServer%.param.crt -name secp%default_ECC_Server%r1
openssl genpkey -batch -config %cfgCAServer%.cfg -paramfile %CAServer%.param.crt -pass pass:%PASSWORD_Server% -out %CAServer%.key

:: options 2:
REM openssl genpkey -batch -config %cfgCAServer%.cfg -algorithm EC -out %CAServer%.key -pkeyopt ec_paramgen_curve:P-%default_ECC_Intermediate% -pkeyopt ec_param_enc:named_curve

IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: view it:
REM openssl ec -noout -text -passin pass:%PASSWORD_Server% -in %CAServer%.key
goto :EOF


:create_CSR_Server
echo %c%%~0%END%
:: verify it:
echo %HIGH%%b%  openssl req -verify -in %CAServer%.csr -text -noout %END%

IF EXIST %CAServer%.crt IF /I NOT "%FORCE_Server%"=="y" exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
:: you don't have to specify rsa keysize here, it's using the private key size
REM -newkey rsa:%default_bits_Server%
:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM M$ and gg both have same group -subj "/CN=%ORG_Server% Root/O=%ORG_Root%/C=%countryName%"
openssl req -batch -config %cfgCAServer%.cfg -new -nodes -key %CAServer%.key -passin pass:%PASSWORD_Server% -out %CAServer%.csr
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: verify it:
REM openssl req -verify -in %CAServer%.csr -text -noout
goto :EOF


:create_CRT_Server
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl x509 -text -noout -in %CAServer%.crt %END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %CAServer%.crt %END%

IF EXIST %CAServer%.crt IF /I NOT "%FORCE_Server%"=="y" exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl x509 -req -%default_md_Server% -days %default_days_Server% -CA %CARoot%.crt -CAkey %CARoot%.key -CAcreateserial -CAserial %CAServer%.srl -extfile openssl.%ORG_Root%.cfg -extensions v3_Server_ca -in %CAServer%.csr -out %CAServer%.crt

:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM -startdate val          Cert notBefore, YYMMDDHHMMSSZ
REM -enddate val            YYMMDDHHMMSSZ cert notAfter (overrides -days)
REM -create_serial          will generate serialNumber into serialNumber.pem
REM -rand_serial            will generate serialNumber everytime and not store it, but actually it does
REM -md %default_md_Server%        sha256 sha512
REM -extfile openssl.%ORG_Root%.cfg
REM -updatedb
REM -notext
REM echo|set /p=>%ORG_Root%\index.txt
:: WARNING using cfgCAIntermediate to sign the Server CSR is indeed correct!
:: That is why we cannot let the client regenerate the CAServer themselves: they would need the CARoot password
openssl ca -batch -config %cfgCAIntermediate% -create_serial -passin pass:%PASSWORD_Intermediate% -extensions v3_Server_ca -in %CAServer%.csr -out %CAServer%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

certutil -dump %CAServer%.crt | findstr /b /c:"Cert Hash(sha1)" | for /f "tokens=3" %%t in ('more') do @echo %c%THUMBPRINT =%END% %%t

:: view it:
REM openssl x509 -text -noout -in %CAServer%.crt

:: verify it:
REM certutil -verify -urlfetch %CAServer%.crt
REM openssl verify -CAfile %CARoot%.crt %CAServer%.crt

goto :EOF


:create_PFX_ServerChain
echo %c%%~0%END%

:: create chain pem for Apache/nginx:
type %CAServer%.crt %CAIntermediate%.crt %CARoot%.crt >%CAServer%.chain.pem

:: convert chain to PFX for Windows:
openssl pkcs12 -export -name "*.%DOMAIN%" -inkey %CAServer%.key -passin pass:%PASSWORD_Server% -in %CAServer%.chain.pem -passout pass:aaaa -out %CAServer%.chain.pfx

:: https://stackoverflow.com/questions/9971464/how-to-convert-crt-cetificate-file-to-pfx
:: CRT + CA: all in one
REM openssl pkcs12 -export -name "*.%DOMAIN%" -inkey %CARoot%.key -passin pass:%PASSWORD_Root% -in %CAServer%.crt -certfile %CARoot%.crt -passout pass:%PASSWORD_PFX_Server% -out %CAServer%.pfx

:: https://www.phildev.net/ssl/creating_ca.html
REM openssl pkcs12 -export -name "*.%DOMAIN%" -inkey %CAServer%.key -passin pass:%PASSWORD_Intermediate% -in %CAServer%.crt -chain -CAfile %CARoot%.crt -passout pass:%PASSWORD_PFX_Server% -out %CAServer%.pfx
IF %ERRORLEVEL% NEQ 0 pause & exit 1

echo %b% certutil -importPFX -f -p %PASSWORD_PFX_Server% %CAServer%.pfx %END%
echo certutil -importPFX -f -p %PASSWORD_PFX_Server% %CAServer%.pfx >%CAServer%.pfx.cmd
echo certutil -verify -urlfetch %CAServer%.crt >>%CAServer%.pfx.cmd

echo echo How to revoque IR5 certificates:
echo echo netsh http delete sslcert ipport=0.0.0.0:8085
echo echo netsh http delete sslcert ipport=0.0.0.0:8086

goto :EOF


:create_CRL_Server
echo %c%%~0%END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %CAServer%.crt %END%

:: https://blog.didierstevens.com/2013/05/08/howto-make-your-own-cert-and-revocation-list-with-openssl/
:: Generate an empty CRL (both in PEM and DER):
openssl ca -batch -config %cfgCAServer% -gencrl -keyfile %CAServer%.key -cert %CAServer%.crt -out %CAServer%.crl.crt
openssl crl -batch -config %cfgCAServer% -inform PEM -in %CAServer%.crl.crt -outform DER -out %CAServer%.crl

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %CAServer%.crt %END%
:: verify it:
REM certutil -verify -urlfetch %CAServer%.crt

:: a Windows Server 2003 CA will always check revocation on all certificates in the PKI hierarchy (except the root CA certificate) before issuing an end-entity certificate. However in this situation, a valid Certificate Revocation List (CRL) for one or more of the intermediate certification authority (CA) certificates was not be found since the root CA was offline. This issue may occur if the CRL is not available to the certificate server, or if the CRL has expired.
:: You may disabled the feature that checks revocation on all certificates in the PKI hierarchy with the following command on the CA:

REM certutil –setreg ca\CRLFlags +CRLF_REVCHECK_IGNORE_OFFLINE
goto :EOF


:O---------O

:revoke_CRT
echo %c%%~0%END%

:: https://blog.didierstevens.com/2013/05/08/howto-make-your-own-cert-and-revocation-list-with-openssl/
echo:
echo To revoke the current certificate:
echo %c%  openssl ca -revoke %CAServer%.crt -keyfile %CAIntermediate%.key -cert %CAIntermediate%.crt %END%

exit /b 0
call :create_CRL

goto :EOF


:create_chain_PEM
echo %c%%~0%END%
type %CAServer%.crt %CAIntermediate%.crt %CARoot%.crt >%ORG_Root%\ca-chain-bundle.%ORG_Root%.pem 2>NUL
openssl verify -purpose sslclient -untrusted %ORG_Root%\ca-chain-bundle.%ORG_Root%.pem %CAServer%.crt

openssl x509 -noout -subject -issuer -in %CARoot%.crt
openssl x509 -noout -subject -issuer -in %CAIntermediate%.crt
openssl x509 -noout -subject -issuer -in %CAServer%.crt

goto :EOF


:import_PFX_Server
echo %c%%~0%END%

echo %HIGH%%b%  certutil -importPFX -f -p "%PASSWORD_PFX_Server%" %CAServer%.pfx %END%

set /p IMPORT=Import PFX? [%IMPORT_PFX%] 
IF /I "%IMPORT_PFX%"=="y" certutil -importPFX -f -p "%PASSWORD_PFX_Server%" %CAServer%.pfx || pause
goto :EOF


:set_colors
IF DEFINED END goto :EOF
set END=[0m
set HIGH=[1m
set Underline=[4m
set REVERSE=[7m

set k=[30m
set r=[31m
set g=[32m
set y=[33m
set b=[34m
set m=[35m
set c=[36m
set w=[37m

goto :EOF
:: BUG: some space are needed after :set_colors


:detect_admin_mode [num]
IF DEFINED DEBUG echo DEBUG: %m%%~n0 %~0 %HIGH%%*%END% 1>&2
:: https://stackoverflow.com/questions/1894967/how-to-request-administrator-access-inside-a-batch-file

set req=%1
set bits=32
set bitx=x86
IF DEFINED PROCESSOR_ARCHITEW6432 echo WARNING: running 32bit cmd on 64bit system 1>&2
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
  set arch=-x64
  set bits=64
  set bitx=x64
)
REM %SystemRoot%\system32\whoami /groups | findstr "12288" >NUL && set "ADMIN=0" || set "ADMIN=1"
net session  >NUL 2>&1 && set "ADMIN=0" || set "ADMIN=1"
IF %ADMIN% EQU 0 (
  echo Batch started with %HIGH%%y%ADMIN%END% rights 1>&2
) ELSE (
  echo Batch started with %y%USER%END% rights 1>&2
)

IF DEFINED req (
  IF NOT "%ADMIN%" EQU "%req%" (
    IF "%ADMIN%" GTR "%req%" (
      echo %y%Batch started with USER privileges, when ADMIN was needed.%END% 1>&2
      IF DEFINED AUTOMATED exit
      REM :UACPrompt
      REM net localgroup administrators | findstr "%USERNAME%" >NUL || call :error %~0: User %USERNAME% is NOT localadmin
      gpresult /R | findstr BUILTIN\Administrators >NUL || call :error %~0: User %USERNAME% is NOT localadmin
      echo Set UAC = CreateObject^("Shell.Application"^) >"%TMP%\getadmin.vbs"
      REM :: WARNING: cannot use escaped parameters with this one:
      IF DEFINED params (
      echo UAC.ShellExecute "cmd.exe", "/c %~s0 %params:"=""%", "", "runas", 1 >>"%TMP%\getadmin.vbs"
      ) ELSE echo UAC.ShellExecute "cmd.exe", "/c %~s0", "", "runas", 1 >>"%TMP%\getadmin.vbs"
      CScript //B "%TMP%\getadmin.vbs"
      del /q "%TMP%\getadmin.vbs"
    ) ELSE (
      echo %r%Batch started with ADMIN privileges, when USER was needed. EXIT%END% 1>&2
      IF NOT DEFINED AUTOMATED pause 1>&2
    )
    exit 1
  )
)

set osType=workstation
md %TMP% 2>NUL
%SystemRoot%\System32\wbem\wmic.exe os get Caption /value | findstr Server >%TMP%\wmic.tmp.txt && set "osType=server" || ver >%TMP%\ver.tmp.txt

:: https://www.lifewire.com/windows-version-numbers-2625171
:: Microsoft Windows [Version 10.0.17763.615]
IF "%osType%"=="workstation" (
  findstr /C:"Version 10.0" %TMP%\ver.tmp.txt >NUL && set "WindowsVersion=10"    && exit /b 0
  findstr /C:"Version 6.3"  %TMP%\ver.tmp.txt >NUL && set "WindowsVersion=8.1"   && exit /b 0
  findstr /C:"Version 6.2"  %TMP%\ver.tmp.txt >NUL && set "WindowsVersion=8"     && exit /b 0
  findstr /C:"Version 6.1"  %TMP%\ver.tmp.txt >NUL && set "WindowsVersion=7"     && exit /b 0
  findstr /C:"Version 6.0"  %TMP%\ver.tmp.txt >NUL && set "WindowsVersion=Vista" && exit /b 0
  findstr /C:"Version 5.1"  %TMP%\ver.tmp.txt >NUL && set "WindowsVersion=XP"    && exit /b 0
) ELSE (
  for /f "tokens=4" %%a in (%TMP%\wmic.tmp.txt) do    set "WindowsVersion=%%a"   && exit /b 0
)
goto :EOF

:check_exist_exit
IF DEFINED DEBUG echo DEBUG: %m%%~n0 %~0 %HIGH%%*%END% 1>&2
IF NOT EXIST %1 (
  echo %HIGH%%r% IF EXIST KO%END%: %1 not found... EXIT 1>&2
  pause
  exit 1
)
echo %HIGH%%g% IF EXIST OK%END%: %1 1>&2
goto :EOF

:error "msg"
echo:%r% 1>&2
echo ============================================================== 1>&2
echo %HIGH%%r%  ERROR:%END%%r% %* 1>&2
IF /I [%2]==[powershell] echo %y%Consider install Management Framework at http://aka.ms/wmf5download %r% 1>&2
echo ============================================================== 1>&2
echo:%END% 1>&2
IF NOT DEFINED AUTOMATED pause 1>&2
exit 1
goto :EOF

:end
pause
