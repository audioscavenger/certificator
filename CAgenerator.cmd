@echo OFF
pushd %~dp0

:: Certificate output breakdown: https://www.misterpki.com/openssl-view-certificate/
REM openssl x509 -text -noout -in 
REM openssl s_client -showcerts -connect https://www.nqzw.com
REM openssl s_client -servername  www.nqzw.com -connect www.nqzw.com:443 | sed -ne "/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p" > www.nqzw.com.crt
REM openssl x509 -text -noout -in www.nqzw.com.crt

:: //TODO: install Microsoft Online Responder Service
:: https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/cc770413(v=ws.10)?redirectedfrom=MSDN
:: Create/delete web virtual roots for OCSP web proxy:
REM certutil -vocsproot delete
REM certutil -vocsproot
REM net stop certsvc && net start certsvc && iisreset
:: CertUtil: -vocsproot command FAILED: 0x80070002 (WIN32: 2 ERROR_FILE_NOT_FOUND)
:: During Online Responder installation an OCSP virtual directory is created under the Default Web Site in Internet Information Service (IIS), by the command certutil -vocsproot. However, the command will fail if the Default Web Site is missing or has otherwise been reconfigured.
:: Test ocsp: https://social.technet.microsoft.com/Forums/en-US/25d15b66-d32a-414d-8154-14662d66bdca/urgent-help-needed-about-online-responder?forum=winserversecurity
REM certutil -url %DOMAIN%.crt

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
::  1.3.6   added @alt_names_server
::  1.3.7   added @ocsp_section
::  1.3.8   added working AIA: caIssuers + OCSP
::  1.3.9   added correct policyIdentifier
::  1.4.0   separated Root csr from key; can regenerate csr
::  1.5.0   following guidelines from 3 websites, separating root/subordinate/server/user cfg
::  1.5.1   renamed subordinate->intermediate because, people
::  1.5.2   added RSA vs ECC option
::  1.5.3   moved cmd/cfg around
::  1.5.4   TESTED WORKING
::  1.5.5   duped ocsp_section ia/server
::  1.5.6   duped crl_section ia/server
::  1.5.7   cosmetics and bugfixes
::  1.5.8   bugfixes
::  1.5.9   include openssl 1.1.1i
::  1.6.0   now delete the CA before import!
::  1.6.1   PFX password cannot be blank because of java\keytool
::  1.6.2   admin detection changed
::  1.6.3   also produces passwordless server key because of opensource software

REM call YOURORG\openssl.YOURORG.cmd
REM call YOURORG\openssl.YOURDOMAIN.cmd
REM call YOURORG\YOURDOMAIN\openssl.INTERNAL.YOURDOMAIN.LOCAL.cmd
REM set cfgCARoot=%ORG_Root%\openssl.%ORG_Root%
REM set cfgCAIntermediate=%ORG_Root%\openssl.%ORG_Intermediate%
REM set cfgCAServer=%ORG_Root%\%ORG_Intermediate%\openssl.%DOMAIN%
REM set CARoot=%ORG_Root%\ca.%ORG_Root%
REM set CAIntermediate=%ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%
REM set CAServer=%ORG_Root%\%ORG_Intermediate%\%DOMAIN%


:init
set version=1.6.3
set author=lderewonko
title %~n0 %version% - %USERDOMAIN%\%USERNAME%@%USERDNSDOMAIN% - %COMPUTERNAME%.%USERDNSDOMAIN%

call :detect_admin_mode
call :set_colors

set PAUSE=echo:
REM set PAUSE=pause
REM set DEMO=true
set RESET=n
set FORCE_Root=n
set FORCE_Intermediate=n
set FORCE_Server=y
set IMPORT_PFX=n


:prechecks
for %%x in (powershell.exe) do (set "powershell=%%~$PATH:x")
IF NOT DEFINED powershell call :error %~0: powershell NOT FOUND

where openssl >NUL 2>&1 || set "PATH=%~dp0bin;%PATH%"

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
IF /I "%DEMO%"=="y" goto :main

set ORG_Root=
set ORG_Intermediate=%USERDOMAIN%
set DOMAIN=%USERDNSDOMAIN%
set /P         ORG_Root=Organisation?  [%ORG_Root%] 
call %ORG_Root%\openssl.%ORG_Root%.cmd >NUL 2>&1
set /P ORG_Intermediate=Intermediate?  [%ORG_Intermediate%] 
call %ORG_Root%\openssl.%ORG_Intermediate%.cmd >NUL 2>&1
set /P           DOMAIN=Server DOMAIN? [%DOMAIN%] 
call %ORG_Root%\%ORG_Intermediate%\openssl.%DOMAIN%.cmd >NUL 2>&1

:: ENCRYPTION can be different for each section
REM set /P       ENCRYPTION=RSA or ECC?    [%ENCRYPTION%] 

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
:: => in practice, average clients only support two curves, the ones which are designated in so-called NSA Suite B: 
:: these are NIST curves P-256 and P-384 (in OpenSSL, they are designated as, respectively, "prime256v1" and "secp384r1"). 
:: If you use any other curve, then some widespread Web browsers (e.g. Internet Explorer, Firefox...) will be unable to talk to your server.
:: => FYI www.google.com uses secp384r1; if your browser cannot access google, consider upgrading.
:: ASN1 OID: secp384r1 == NIST CURVE: P-384 = NIST/SECG curve over a 384 bit prime field
::      NIST-P: https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.186-4.pdf
::      SECG  : https://www.secg.org/sec2-v2.pdf
:: prime256v1                               = X9.62/SECG curve over a 256 bit prime field
:: containder, without participation of the NSA: Curve25519 - UMAC is much faster than HMAC for message authentication in TLS. see RFC http://www.ietf.org/rfc/rfc4418.txt or http://fastcrypto.org/umac/

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

call :create_KEY_Server_%ENCRYPTION%
%PAUSE%
call :create_CSR_Server
%PAUSE%
call :create_CRT_Server
%PAUSE%
call :create_PFX_ServerChain
%PAUSE%
call :create_CRL_Server
%PAUSE%

call :import_PFX_Server
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
  for %%e in (cfg txt old key csr crt pem pfx) DO (
    del /f /q /s %ORG_Root%\*.%%e >NUL 2>&1
    del /f /q /s %ORG_Root%\%ORG_Intermediate%\*.%%e >NUL 2>&1
  )
  del /f /q /s %ORG_Root%\crlnumber >NUL 2>&1
  del /f /q /s %ORG_Root%\serial >NUL 2>&1
  del /f /q /s %ORG_Root%\%ORG_Intermediate%\crlnumber >NUL 2>&1
  del /f /q /s %ORG_Root%\%ORG_Intermediate%\serial >NUL 2>&1
)

IF EXIST %CARoot%.crt         set /P          FORCE_Root=Regenerate Root cert?         [%FORCE_Root%] 
IF EXIST %CAIntermediate%.crt set /P  FORCE_Intermediate=Regenerate Intermediate cert? [%FORCE_Intermediate%] 
IF EXIST %CAServer%.crt       set /P    FORCE_Server=Regenerate Server cert?       [%FORCE_Server%] 

:: https://serverfault.com/questions/857131/odd-error-while-using-openssl
:: https://www.linuxquestions.org/questions/linux-security-4/why-can%27t-i-generate-a-new-certificate-with-openssl-312716/
IF NOT EXIST %ORG_Root%\index.txt echo|set /p=>%ORG_Root%\index.txt
IF NOT EXIST %ORG_Root%\index.txt.attr echo|set /p="unique_subject = yes">%ORG_Root%\index.txt.attr
IF NOT EXIST %ORG_Root%\%ORG_Intermediate%\index.txt echo|set /p=>%ORG_Root%\%ORG_Intermediate%\index.txt
IF NOT EXIST %ORG_Root%\%ORG_Intermediate%\index.txt.attr echo|set /p="unique_subject = yes">%ORG_Root%\%ORG_Intermediate%\index.txt.attr

:: https://serverfault.com/questions/823679/openssl-error-while-loading-crlnumber
IF NOT EXIST %ORG_Root%\crlnumber echo|set /p="01">%ORG_Root%\crlnumber
IF NOT EXIST %ORG_Root%\serial echo|set /p="1000">%ORG_Root%\serial
IF NOT EXIST %ORG_Root%\%ORG_Intermediate%\crlnumber echo|set /p="01">%ORG_Root%\%ORG_Intermediate%\crlnumber
IF NOT EXIST %ORG_Root%\%ORG_Intermediate%\serial echo|set /p="1000">%ORG_Root%\%ORG_Intermediate%\serial

goto :EOF


:init_cmd
echo %c%%~0%END%

IF EXIST %cfgCARoot%.cmd IF EXIST %cfgCAIntermediate%.cmd IF EXIST %cfgCAServer%.cmd exit /b 0
IF NOT EXIST %cfgCARoot%.cmd          copy openssl.TEMPLATE.Root.cmd          %cfgCARoot%.cmd
IF NOT EXIST %cfgCAIntermediate%.cmd  copy openssl.TEMPLATE.Intermediate.cmd  %cfgCAIntermediate%.cmd
IF NOT EXIST %cfgCAServer%.cmd        copy openssl.TEMPLATE.Server.cmd        %cfgCAServer%.cmd

echo:
echo   %HIGH%Please edit all the %c%%ORG_Root%\*\openssl.*.cmd%w%
echo          Then restart this batch%END%
echo                 Thank you
echo:
pause
exit 99
goto :EOF


:init_cfg
echo %c%%~0%END%

call %cfgCARoot%.cmd
call :create_cfg openssl.TEMPLATE.Root.cfg %cfgCARoot%.cfg
call %cfgCAIntermediate%.cmd
call :create_cfg openssl.TEMPLATE.Intermediate.cfg %cfgCAIntermediate%.cfg
call %cfgCAServer%.cmd
call :create_cfg openssl.TEMPLATE.Server.cfg %cfgCAServer%.cfg

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
       -replace '{challengePassword}', '%challengePassword%' `^
       -replace '{permittedEmailDomain}', '%permittedEmailDomain%' `^
       -replace '{countryName_Server}', '%countryName_Server%' `^
       -replace '{organizationName_Server}', '%organizationName_Server%' `^
       -replace '{organizationalUnitName_Server}', '%organizationalUnitName_Server%' `^
       -replace '{commonName_Server}', '%commonName_Server%' `^
       -replace '{stateOrProvinceName_Server}', '%stateOrProvinceName_Server%' `^
       -replace '{localityName_Server}', '%localityName_Server%' `^
       -replace '{emailAddress_Server}', '%emailAddress_Server%' `^
       -replace '{postalCode_Server}', '%postalCode_Server%' `^
       -replace '{streetAddress_Server}', '%streetAddress_Server%' `^
       -replace '{businessCategory_Server}', '%businessCategory_Server%' `^
       -replace '{jurisdictionCountryName_Server}', '%jurisdictionCountryName_Server%' `^
       -replace '{serialNumber_Server}', '%serialNumber_Server%' `^
       -replace '{countryName_Root}', '%countryName_Root%' `^
       -replace '{organizationName_Root}', '%organizationName_Root%' `^
       -replace '{organizationalUnitName_Root}', '%organizationalUnitName_Root%' `^
       -replace '{commonName_Root}', '%commonName_Root%' `^
       -replace '{stateOrProvinceName_Root}', '%stateOrProvinceName_Root%' `^
       -replace '{localityName_Root}', '%localityName_Root%' `^
       -replace '{emailAddress_Root}', '%emailAddress_Root%' `^
       -replace '{postalCode_Root}', '%postalCode_Root%' `^
       -replace '{streetAddress_Root}', '%streetAddress_Root%' `^
       -replace '{businessCategory_Root}', '%businessCategory_Root%' `^
       -replace '{jurisdictionCountryName_Root}', '%jurisdictionCountryName_Root%' `^
       -replace '{serialNumber_Root}', '%serialNumber_Root%' `^
       -replace '{countryName_Intermediate}', '%countryName_Intermediate%' `^
       -replace '{organizationName_Intermediate}', '%organizationName_Intermediate%' `^
       -replace '{organizationalUnitName_Intermediate}', '%organizationalUnitName_Intermediate%' `^
       -replace '{commonName_Intermediate}', '%commonName_Intermediate%' `^
       -replace '{stateOrProvinceName_Intermediate}', '%stateOrProvinceName_Intermediate%' `^
       -replace '{localityName_Intermediate}', '%localityName_Intermediate%' `^
       -replace '{emailAddress_Intermediate}', '%emailAddress_Intermediate%' `^
       -replace '{postalCode_Intermediate}', '%postalCode_Intermediate%' `^
       -replace '{streetAddress_Intermediate}', '%streetAddress_Intermediate%' `^
       -replace '{businessCategory_Intermediate}', '%businessCategory_Intermediate%' `^
       -replace '{jurisdictionCountryName_Intermediate}', '%jurisdictionCountryName_Intermediate%' `^
       -replace '{serialNumber_Intermediate}', '%serialNumber_Intermediate%' `^
       -replace '{unstructuredName}', '%unstructuredName%' `^
       -replace '{policiesOIDs_Intermediate}', '%policiesOIDs_Intermediate%' `^
       -replace '{policiesOIDs_Server}', '%policiesOIDs_Server%' `^
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
for /f "tokens=1,2 delims==" %%V in ('set DNS. 2^>NUL') DO echo %%V=%%W>>%2
for /f "tokens=1,2 delims==" %%V in ('set IP. 2^>NUL') DO echo %%V=%%W>>%2

goto :EOF

:O---------O
:Root
:O---------O

:create_KEY_Root_RSA
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl rsa -noout -text -passin pass:%PASSWORD_Root% -in %CARoot%.key %END%

IF EXIST %CARoot%.key exit /b 0

:: 2-steps:
:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl genrsa -batch -config %cfgCARoot%.cfg -aes-256-cbc -passout pass:%PASSWORD_Root% -out %CARoot%.key
:: deprecation: https://serverfault.com/questions/590140/openssl-genrsa-vs-genpkey
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:%default_bits_Root% -pass pass:%PASSWORD_Root% -out %CARoot%.key -aes-256-cbc

:: 1-step:
REM openssl req -batch -config %cfgCARoot%.cfg -new -nodes -keyout %CARoot%.key -passout pass:%PASSWORD_Root% -out %CARoot%.csr
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

:: view it:
REM openssl rsa -noout -text -passin pass:%PASSWORD_Root% -in %CARoot%.key
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
echo %b%  openssl ecparam -out %CARoot%.param.crt -name %default_ECC_Root% -param_enc explicit %END%
openssl ecparam -out %CARoot%.param.crt -name %default_ECC_Root% -param_enc explicit 
echo %b%  openssl genpkey -paramfile %CARoot%.param.crt -pass pass:%PASSWORD_Root% -out %CARoot%.key %END%
openssl genpkey -paramfile %CARoot%.param.crt -pass pass:%PASSWORD_Root% -out %CARoot%.key 

:: options 1b:
REM openssl genpkey -algorithm EC -out %CARoot%.key -pkeyopt ec_paramgen_curve:P-%default_ECC_Root% -pkeyopt ec_param_enc:named_curve

:: options 2:
REM openssl x509 -batch -config %cfgCARoot%.cfg -req -%default_md% -days %default_days_Root% -extensions v3_ca -in %CARoot%.csr -signkey %CARoot%.key -passout pass:%PASSWORD_Root% -out %CARoot%.crt
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

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
echo %b%  openssl req -batch -config %cfgCARoot%.cfg -new -x509 -%default_md_Root% -extensions v3_ca -passin pass:%PASSWORD_Root% -key %CARoot%.key -out %CARoot%.crt -set_serial 0 -days %default_days_Root% %END%
openssl req -batch -config %cfgCARoot%.cfg -new -x509 -%default_md_Root% -extensions v3_ca -passin pass:%PASSWORD_Root% -key %CARoot%.key -out %CARoot%.crt -set_serial 0 -days %default_days_Root% 

IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

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
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

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
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:%default_bits_Intermediate% -pass pass:%PASSWORD_Intermediate% -out %CAIntermediate%.key -aes-256-cbc
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

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
openssl ecparam -out %CAIntermediate%.param.crt -name %default_ECC_Intermediate% -param_enc explicit
openssl genpkey -paramfile %CAIntermediate%.param.crt -pass pass:%PASSWORD_Intermediate% -out %CAIntermediate%.key

:: options 2:
REM openssl genpkey -algorithm EC -out %CAIntermediate%.key -pkeyopt ec_paramgen_curve:P-%default_ECC_Intermediate% -pkeyopt ec_param_enc:named_curve

IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

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
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

:: verify it:
REM openssl req -verify -in %CAIntermediate%.csr -text -noout
goto :EOF


:create_CRT_Intermediate
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl x509 -text -noout -in %CAIntermediate%.crt %END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %CAIntermediate%.crt %END%

IF EXIST %CAIntermediate%.crt IF /I NOT "%FORCE_Intermediate%"=="y" (exit /b 0) ELSE echo|set /p=>%ORG_Root%\index.txt

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
openssl ca -batch -config %cfgCARoot%.cfg -create_serial -rand_serial -updatedb -passin pass:%PASSWORD_Root% -extensions v3_intermediate_ca -in %CAIntermediate%.csr -out %CAIntermediate%.crt
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

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
openssl pkcs12 -export -name "%ORG_Intermediate% RSA TLS CA" -inkey %CAIntermediate%.key -passin pass:%PASSWORD_Intermediate% -in %CAIntermediate%.chain.pem -passout pass:%PASSWORD_PFX_Intermediate% -out %CAIntermediate%.chain.pfx

:: https://www.phildev.net/ssl/creating_ca.html
REM openssl pkcs12 -export -name "%ORG_Intermediate% RSA TLS CA" -inkey %CAIntermediate%.key -passin pass:%PASSWORD_Intermediate% -in %CAIntermediate%.crt -chain -CAfile %CARoot%.crt -passout pass:%PASSWORD_PFX_Intermediate% -out %CAIntermediate%.chain.pfx
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

:: list them:
REM powershell -executionPolicy bypass -Command Get-ChildItem -path Cert:\LocalMachine\My -Recurse ^| Format-Table Thumbprint, Subject ^| 

echo %b% certutil -importPFX -f -p "%PASSWORD_PFX_Intermediate%" %CAIntermediate%.chain.pfx %END%
echo @pushd %%~dp0 >%CAIntermediate%.chain.pfx.cmd
echo powershell -executionPolicy bypass -Command Get-ChildItem -path Cert:\LocalMachine\Root -Recurse ^^^| Get-ChildItem ^^^| where {$_.Subject -like 'CN=%commonName_Root%*'} ^^^| Remove-Item  >>%CAIntermediate%.chain.pfx.cmd
echo powershell -executionPolicy bypass -Command Get-ChildItem -path Cert:\LocalMachine\CA -Recurse ^^^| Get-ChildItem ^^^| where {$_.Subject -like 'CN=%commonName_Intermediate%*'} ^^^| Remove-Item  >>%CAIntermediate%.chain.pfx.cmd
echo certutil -importPFX -f -p "%PASSWORD_PFX_Intermediate%" ca.%ORG_Intermediate%.chain.pfx >>%CAIntermediate%.chain.pfx.cmd

goto :EOF


:create_CRL_Intermediate
echo %c%%~0%END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %CAIntermediate%.crt %END%

:: https://blog.didierstevens.com/2013/05/08/howto-make-your-own-cert-and-revocation-list-with-openssl/
:: Generate an empty CRL (both in PEM and DER):
openssl ca -batch -config %cfgCAIntermediate%.cfg -gencrl -passin pass:%PASSWORD_Intermediate% -keyfile %CAIntermediate%.key -cert %CAIntermediate%.crt -out %CAIntermediate%.crl.crt
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1
openssl crl -inform PEM -in %CAIntermediate%.crl.crt -outform DER -out %CAIntermediate%.crl
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

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
echo %HIGH%%b%  openssl rsa -noout -text -in %CAServer%.key %END%

IF EXIST %CAServer%.key exit /b 0

:: 2-steps:
:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl genrsa -batch -config %cfgCAServer%.cfg -passout pass:%PASSWORD_Intermediate% -out %CAServer%.key
:: deprecation: https://serverfault.com/questions/590140/openssl-genrsa-vs-genpkey
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:%default_bits_Root% -pass pass:%PASSWORD_Server% -out %CAServer%.key -aes-256-cbc

IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

:: passwordless key is needed for 99% of opensource software including nginx, prometheux, grafana...
openssl rsa -in %CAServer%.key -passin pass:%PASSWORD_Server% -out %CAServer%.nopass.key

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
openssl ecparam -out %CAServer%.param.crt -name %default_ECC_Server% -param_enc explicit
openssl genpkey -paramfile %CAServer%.param.crt -pass pass:%PASSWORD_Server% -out %CAServer%.key

:: options 2:
REM openssl genpkey -algorithm EC -out %CAServer%.key -pkeyopt ec_paramgen_curve:P-%default_ECC_Intermediate% -pkeyopt ec_param_enc:named_curve

IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

:: passwordless key is needed for 99% of opensource software including nginx, prometheux, grafana...
openssl rsa -in %CAServer%.key -passin pass:%PASSWORD_Server% -out %CAServer%.nopass.key

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
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

:: verify it:
REM openssl req -verify -in %CAServer%.csr -text -noout
goto :EOF


:create_CRT_Server
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl x509 -text -noout -in %CAServer%.crt %END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %CAServer%.crt %END%

IF EXIST %CAServer%.crt IF /I NOT "%FORCE_Server%"=="y" (exit /b 0) ELSE echo|set /p=>%ORG_Root%\%ORG_Intermediate%\index.txt

:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl x509 -req -%default_md_Server% -days %default_days_Server% -CA %CARoot%.crt -CAkey %CARoot%.key -CAcreateserial -CAserial %CAServer%.srl -extfile openssl.%ORG_Root%.cfg -extensions v3_server_ca -in %CAServer%.csr -out %CAServer%.crt

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
openssl ca -batch -config %cfgCAIntermediate%.cfg -create_serial -rand_serial -updatedb -passin pass:%PASSWORD_Intermediate% -extensions v3_server_ca -in %CAServer%.csr -out %CAServer%.crt
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

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
openssl pkcs12 -export -name "*.%DOMAIN%" -inkey %CAServer%.key -passin pass:%PASSWORD_Server% -in %CAServer%.chain.pem -passout pass:%PASSWORD_PFX_Server% -out %CAServer%.chain.pfx

:: https://stackoverflow.com/questions/9971464/how-to-convert-crt-cetificate-file-to-pfx
:: CRT + CA: all in one
REM openssl pkcs12 -export -name "*.%DOMAIN%" -inkey %CARoot%.key -passin pass:%PASSWORD_Root% -in %CAServer%.crt -certfile %CARoot%.crt -passout pass:%PASSWORD_PFX_Server% -out %CAServer%.pfx

:: https://www.phildev.net/ssl/creating_ca.html
REM openssl pkcs12 -export -name "*.%DOMAIN%" -inkey %CAServer%.key -passin pass:%PASSWORD_Intermediate% -in %CAServer%.crt -chain -CAfile %CARoot%.crt -passout pass:%PASSWORD_PFX_Server% -out %CAServer%.pfx
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

:: list them:
REM powershell -executionPolicy bypass -Command Get-ChildItem -path Cert:\LocalMachine\My -Recurse ^| Format-Table Thumbprint, FriendlyName

echo %b% certutil -importPFX -f -p "%PASSWORD_PFX_Server%" %CAServer%.chain.pfx %END%
echo @pushd %%~dp0 >%CAServer%.chain.pfx.cmd
echo powershell -executionPolicy bypass -Command Get-ChildItem -path Cert:\LocalMachine\Root -Recurse ^^^| Get-ChildItem ^^^| where {$_.Subject -like 'CN=%commonName_Root%*'} ^^^| Remove-Item  >>%CAServer%.chain.pfx.cmd
echo powershell -executionPolicy bypass -Command Get-ChildItem -path Cert:\LocalMachine\CA -Recurse ^^^| Get-ChildItem ^^^| where {$_.Subject -like 'CN=%commonName_Intermediate%*'} ^^^| Remove-Item  >>%CAServer%.chain.pfx.cmd
echo powershell -executionPolicy bypass -Command Get-ChildItem -path Cert:\LocalMachine\My -Recurse ^^^| Get-ChildItem ^^^| where {$_.FriendlyName -like '*.%DOMAIN%'} ^^^| Remove-Item  >>%CAServer%.chain.pfx.cmd
echo certutil -importPFX -f -p "%PASSWORD_PFX_Server%" %DOMAIN%.chain.pfx >>%CAServer%.chain.pfx.cmd
echo certutil -verify -urlfetch %DOMAIN%.crt >>%CAServer%.chain.pfx.cmd
echo: >>%CAServer%.chain.pfx.cmd
echo certutil -dump %DOMAIN%.crt ^| findstr /b /c:"Cert Hash(sha1)" ^| for /f "tokens=3" %%%%t in ('more') do for /f "usebackq delims=" %%%%I in (`powershell "\"%%%%t\".toUpper()"`) do @echo %c%THUMBPRINT =%END% %%%%~I >>%CAServer%.chain.pfx.cmd
echo: >>%CAServer%.chain.pfx.cmd
echo echo How to revoque IR5 certificates: >>%CAServer%.chain.pfx.cmd
echo echo netsh http delete sslcert ipport=0.0.0.0:8085 >>%CAServer%.chain.pfx.cmd
echo echo netsh http delete sslcert ipport=0.0.0.0:8086 >>%CAServer%.chain.pfx.cmd
echo pause >>%CAServer%.chain.pfx.cmd

:: https://stackoverflow.com/questions/10338543/what-causes-keytool-error-failed-to-decrypt-safe-contents-entry/10338940#10338940
:: Question: How do I move a certificate from IIS / PFX (.p12 file) to a JKS (Java KeyStore)?
REM %JDK_HOME%\bin\keytool -importkeystore -srckeystore PFX_P12_FILE_NAME -srcstoretype pkcs12 -srcstorepass PFX_P12_FILE -srcalias SOURCE_ALIAS -destkeystore KEYSTORE_FILE -deststoretype jks -deststorepass PASSWORD -destalias ALIAS_NAME
:: Note: To find the srcalias, list the contents of the PFX/P12 file:
REM %JDK_HOME%\bin\keytool -v -list -storetype pkcs12 -keystore \\sales-cc\cert\INTERNAL.NQSALES.COM.chain.pfx

:: delete them:
REM powershell -executionPolicy bypass -Command Get-ChildItem -path Cert:\LocalMachine\My -Recurse ^| Get-ChildItem ^| where {$_.FriendlyName -like '*.INTERNAL.NQSALES.COM'} ^| Remove-Item

goto :EOF


:: not sure it's needed, many issuers have only one url anyway
:create_CRL_Server
echo %c%%~0%END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %CAServer%.crt %END%

:: https://blog.didierstevens.com/2013/05/08/howto-make-your-own-cert-and-revocation-list-with-openssl/
:: Generate an empty CRL (both in PEM and DER):
openssl ca -batch -config %cfgCAServer%.cfg -gencrl -passin pass:%PASSWORD_Server% -keyfile %CAServer%.key -cert %CAServer%.crt -out %CAServer%.crl.crt
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1
openssl crl -inform PEM -in %CAServer%.crl.crt -outform DER -out %CAServer%.crl
IF %ERRORLEVEL% NEQ 0 echo %r%      ---error---%END% & pause & exit 1

:: verify it:
REM certutil -verify -urlfetch %CAServer%.crt

:: a Windows Server 2003 CA will always check revocation on all certificates in the PKI hierarchy (except the root CA certificate) before issuing an end-entity certificate. However in this situation, a valid Certificate Revocation List (CRL) for one or more of the intermediate certification authority (CA) certificates was not be found since the root CA was offline. This issue may occur if the CRL is not available to the certificate server, or if the CRL has expired.
:: You may disabled the feature that checks revocation on all certificates in the PKI hierarchy with the following command on the CA:

REM certutil –setreg ca\CRLFlags +CRLF_REVCHECK_IGNORE_OFFLINE
goto :EOF


:O---------O

:revoke_CRT-TODO
echo %c%%~0%END%

:: https://blog.didierstevens.com/2013/05/08/howto-make-your-own-cert-and-revocation-list-with-openssl/
echo:
echo To revoke CAServer certificate:
echo %c%  openssl ca -revoke %CAServer%.crt -updatedb -keyfile %CAIntermediate%.key -cert %CAIntermediate%.crt %END%
echo To revoke CAIntermediate certificate:
echo %c%  openssl ca -revoke %CAIntermediate%.crt -updatedb -keyfile %CARoot%.key -cert %CARoot%.crt %END%

exit /b 0
call :create_CRL

goto :EOF


:import_PFX_Server
echo %c%%~0%END%

echo %HIGH%%b%  certutil -importPFX -f -p "%PASSWORD_PFX_Server%" %CAServer%.chain.pfx %END%

set /p IMPORT=Import PFX? [%IMPORT_PFX%] 
IF /I "%IMPORT_PFX%"=="y" certutil -importPFX -f -p "%PASSWORD_PFX_Server%" %CAServer%.chain.pfx || pause
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
      gpresult /R | findstr BUILTIN\Administrators >NUL || net session >NUL 2>&1 || call :error %~0: User %USERNAME% is NOT localadmin
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
echo ----------------------------- THE END -----------------------------
pause
