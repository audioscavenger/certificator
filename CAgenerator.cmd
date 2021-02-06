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
::  1.3.6   added @alt_names_Subscriber
::  1.3.7   added @ocsp_section
::  1.3.8   added working AIA: caIssuers + OCSP
::  1.3.9   added correct policyIdentifier
::  1.4.0   separated Root csr from key; can regenerate csr
::  1.5.0   following guidelines from 3 websites, separating root/subordinate/server/user cfg
::  1.5.1   renamed subordinate->intermediate because people

:init
set version=1.3.9
set author=lderewonko

call :detect_admin_mode
call :set_colors

set ORG_Root=
set ORG_Intermediate=%USERDOMAIN%
REM set PAUSE=echo:
set PAUSE=pause
set RESET=n
set FORCE_Root=n
set FORCE_Intermediate=y
set FORCE_Subscriber=y
set DEMO=YOURORG
set IMPORT_PFX=n


:prechecks
for %%x in (powershell.exe) do (set "powershell=%%~$PATH:x")
IF NOT DEFINED powershell call :error %~0: powershell NOT FOUND

call :check_exist_exit openssl.TEMPLATE.cfg
call :check_exist_exit openssl.TEMPLATE.cmd



:defaults
IF DEFINED DEMO (
  set ORG_Root=%DEMO%
  set /P ORG_Root=Organisation? [%DEMO%] 
) ELSE (
  set /P        ORG_Root=Organisation? [%ORG_Root%] 
  set /P ORG_Intermediate=Intermediate?   [%ORG_Intermediate%] 
)
IF /I "%ORG_Root%"=="ORG_Root" call :error Using ORG_Root as Organisation name is forbidden.

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:main
call :ask_for_values
call :create_cfg openssl.TEMPLATE.cfg openssl.%ORG_Root%.cfg
call :reset
call :create_folders

IF EXIST %ORG_Root%\ca.%ORG_Root%.crt         set /P       FORCE_Root=Regenerate Root cert?        [%FORCE_Root%] 
IF EXIST %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt   set /P FORCE_Intermediate=Regenerate Intermediate cert? [%FORCE_Intermediate%] 
IF EXIST %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt  set /P FORCE_Subscriber=Regenerate Server cert?  [%FORCE_Subscriber%] 

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

REM set OPENSSL_CONF=S:\BOULOT\nQ-Documents\ConnectWiseControl\Toolbox\tools\certificator\openssl.%ORG_Root%.cfg
set OPENSSL_CONF=%~dp0\openssl.%ORG_Root%.cfg
REM call :create_KEY_Root_RSA
call :create_KEY_Root_ECC
%PAUSE%
call :create_CRT_Root
%PAUSE%
REM call :create_PFX_Root // this makes no sense with Intermediate CA

REM set OPENSSL_CONF=%~dp0\openssl.%ORG_Intermediate%.cfg
REM call :create_KEY_Intermediate_RSA
call :create_KEY_Intermediate_ECC
%PAUSE%
call :create_CSR_Intermediate
%PAUSE%
call :create_CRT_Intermediate
%PAUSE%
call :create_PFX_Root_Intermediate
%PAUSE%

REM set OPENSSL_CONF=%~dp0\openssl.%ORG_Subscriber%.cfg
call :create_KEY_Subscriber
%PAUSE%
call :create_CSR_Subscriber
%PAUSE%
call :create_CRT_Subscriber
%PAUSE%
call :create_PFX_Root_Intermediate_Subscriber
%PAUSE%
call :create_CRL
%PAUSE%

call :convert_chain_PFX
call :import_chain_CRT

call :revoke_CRT

goto :end
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:ask_for_values
echo %c%%~0%END%

IF EXIST openssl.%ORG_Root%.cmd exit /b 0

echo:
echo   %HIGH%Please copy %c%openssl.ORG_Root.cmd%w% into %g%openssl.%ORG_Root%.cmd%w% and set the values inside.
echo                            Then restart this batch%END%
echo                                   Thank you
echo:
pause
exit 0
goto :EOF


:reset
echo %c%%~0%END%
IF /I "%RESET%"=="y" (
  del /f /q /s %ORG_Root%\*.crt 2>NUL
  del /f /q /s %ORG_Root%\*.csr 2>NUL
)
goto :EOF


:create_folders
echo %c%%~0%END%

md %ORG_Root%\ 2>NUL
md %ORG_Root%\%ORG_Intermediate% 2>NUL
REM md %ORG_Root%\certs 2>NUL
REM md %ORG_Root%\crl 2>NUL
REM md %ORG_Root%\newcerts 2>NUL
REM md %ORG_Root%\private 2>NUL
REM md %ORG_Root%\req 2>NUL

:: https://serverfault.com/questions/857131/odd-error-while-using-openssl
:: https://www.linuxquestions.org/questions/linux-security-4/why-can%27t-i-generate-a-new-certificate-with-openssl-312716/
echo|set /p=>%ORG_Root%\index.txt
echo|set /p="unique_subject = yes">%ORG_Root%\index.txt.attr

:: https://serverfault.com/questions/823679/openssl-error-while-loading-crlnumber
echo|set /p="01">%ORG_Root%\crlnumber
echo|set /p="1000">%ORG_Root%\serial

goto :EOF

:create_cfg in out
echo %c%%~0%END%

call openssl.%ORG_Root%.cmd

:: too slow:
copy /y %1 %2
REM for /f "eol=: tokens=1,2 delims==" %%V in (openssl.ORG_Root.cmd) DO (
  REM powershell -executionPolicy bypass -Command "(Get-Content -Path '%~2') -replace '{%%V}', '%%W' | Set-Content -Path '%~2'"
REM )

powershell -executionPolicy bypass -Command ^(Get-Content %1^) ^| Foreach-Object { ^
    $_ -replace '{CADOMAIN}', '%CADOMAIN%' `^
       -replace '{ORG_Root}', '%ORG_Root%' `^
       -replace '{ORG_Intermediate}', '%ORG_Intermediate%' `^
       -replace '{ORG_Subscriber}', '%ORG_Subscriber%' `^
       -replace '{default_days}', '%default_days%' `^
       -replace '{default_days_Root}', '%default_days_Root%' `^
       -replace '{default_days_Intermediate}', '%default_days_Intermediate%' `^
       -replace '{default_days_Subscriber}', '%default_days_Subscriber%' `^
       -replace '{default_md}', '%default_md%' `^
       -replace '{default_md_Root}', '%default_md_Root%' `^
       -replace '{default_md_Intermediate}', '%default_md_Intermediate%' `^
       -replace '{default_md_Subscriber}', '%default_md_Subscriber%' `^
       -replace '{default_bits}', '%default_bits%' `^
       -replace '{default_bits_Root}', '%default_bits_Root%' `^
       -replace '{default_bits_Intermediate}', '%default_bits_Intermediate%' `^
       -replace '{default_bits_Subscriber}', '%default_bits_Subscriber%' `^
       -replace '{default_ECC}', '%default_ECC%' `^
       -replace '{default_ECC_Root}', '%default_ECC_Root%' `^
       -replace '{default_ECC_Intermediate}', '%default_ECC_Intermediate%' `^
       -replace '{default_ECC_Subscriber}', '%default_ECC_Subscriber%' `^
       -replace '{PASSWORD_Root}', '%PASSWORD_Root%' `^
       -replace '{PASSWORD_Intermediate}', '%PASSWORD_Intermediate%' `^
       -replace '{PASSWORD_Subscriber}', '%PASSWORD_Subscriber%' `^
       -replace '{PASSWORD_PFX}', '%PASSWORD_PFX%' `^
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

:: OPENSSL_CONF must have full path, and extension cfg on Windows. don't ask me why.
REM set OPENSSL_CONF=%~dp0\openssl.github.cfg
REM set OPENSSL_CONF=%~dp0\openssl.cfg
REM set OPENSSL_CONF=%~dp0\openssl.MIT.cfg
REM set OPENSSL_CONF=%~dp0\openssl.pki-tutorial.cfg
REM set OPENSSL_CONF=%~dp0\openssl.%ORG_Root%.cfg
REM set OPENSSL_CONF=%~dp0\openssl.%ORG_Root%.cfg

goto :EOF

:O---------O
:Root
:O---------O

:create_KEY_Root_RSA
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl rsa -noout -text -in %ORG_Root%\ca.%ORG_Root%.key -passin pass:%PASSWORD_Root% %END%

IF EXIST %ORG_Root%\ca.%ORG_Root%.key exit /b 0

:: options 1:
:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl genrsa -aes-256-cbc -passout pass:%PASSWORD_Root% -out %ORG_Root%\ca.%ORG_Root%.key
:: deprecation: https://serverfault.com/questions/590140/openssl-genrsa-vs-genpkey
REM openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:%default_bits_Root% -out %ORG_Root%\ca.%ORG_Root%.key -aes-256-cbc -pass pass:%PASSWORD_Root%

:: options 2:
openssl req -batch -new -nodes -keyout %ORG_Root%\ca.%ORG_Root%.key -out %ORG_Root%\ca.%ORG_Root%.csr
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: view it:
REM openssl rsa -noout -text -in %ORG_Root%\ca.%ORG_Root%.key -passin pass:%PASSWORD_Root%
goto :EOF


:create_KEY_Root_ECC
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl ec -noout -text -in %ORG_Root%\ca.%ORG_Root%.key -passin pass:%PASSWORD_Root% %END%

IF EXIST %ORG_Root%\ca.%ORG_Root%.key exit /b 0

:: https://www.ibm.com/support/knowledgecenter/en/SSB27H_6.2.0/fa2ti_openssl_using_ECCdhersa_generate_ECC_key.html
:: https://stackoverflow.com/questions/64961096/what-is-the-suggested-openssl-command-to-generate-ec-key-and-csr-compatible-with
:: https://www.openssl.org/docs/man1.1.0/man1/genpkey.html
:: options 1: why you need to store the params: https://wiki.openssl.org/index.php/Command_Line_Elliptic_Curve_Operations
REM openssl ecparam -out %ORG_Root%\ca.%ORG_Root%.param.crt -name secp%default_ECC_Root%r1 -param_enc explicit
REM openssl genpkey -paramfile %ORG_Root%\ca.%ORG_Root%.param.crt -out %ORG_Root%\ca.%ORG_Root%.key -pass pass:%PASSWORD_Root%

:: options 1b:
REM openssl genpkey -algorithm EC -out %ORG_Root%\ca.%ORG_Root%.key -pkeyopt ec_paramgen_curve:P-%default_ECC_Root% -pkeyopt ec_param_enc:named_curve

:: options 2:
openssl x509 -req -%default_md% -days %default_days_Root% -extensions v3_ca -in %ORG_Root%\ca.%ORG_Root%.csr -signkey %ORG_Root%\ca.%ORG_Root%.key -out %ORG_Root%\ca.%ORG_Root%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: view it:
REM openssl ec -noout -text -in %ORG_Root%\ca.%ORG_Root%.key -passin pass:%PASSWORD_Root%
goto :EOF


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: -extensions val     CERT extension section (override value in config file)
:: -reqexts val        REQ  extension section (override value in config file)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


:create_CRT_Root
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl x509 -text -noout -in %ORG_Root%\ca.%ORG_Root%.crt %END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %ORG_Root%\ca.%ORG_Root%.crt %END%

IF EXIST %ORG_Root%\ca.%ORG_Root%.crt IF /I NOT "%FORCE_Root%"=="y" exit /b 0

REM v3_ca v3_ca
REM M$ and gg have same group but M$ also has country -subj "/CN=%ORG_Root% Root/OU=%ORG_Root% CA/O=%ORG_Root%"
openssl req -batch -new -x509 -%default_md_Intermediate% -days %default_days_Root% -subj "/CN=%ORG_Root% Root/OU=%ORG_Root% CA/O=%ORG_Root%" -passin pass:%PASSWORD_Root% -extensions v3_ca -key %ORG_Root%\ca.%ORG_Root%.key -out %ORG_Root%\ca.%ORG_Root%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

certutil -dump %ORG_Root%\ca.%ORG_Root%.crt | findstr /b /c:"Cert Hash(sha1)" | for /f "tokens=3" %%t in ('more') do @echo %c%THUMBPRINT =%END% %%t

:: view it:
openssl x509 -text -noout -in %ORG_Root%\ca.%ORG_Root%.crt

:: verify it:
REM certutil -verify -urlfetch %ORG_Root%\ca.%ORG_Root%.crt

goto :EOF

:create_PFX_Root
echo %c%%~0%END%

:: https://www.phildev.net/ssl/creating_ca.html
openssl pkcs12 -export -name "%ORG_Intermediate% RSA TLS CA" -inkey %ORG_Root%\ca.%ORG_Root%.key -passin pass:%PASSWORD_Root% -in %ORG_Root%\ca.%ORG_Root%.crt -passout pass:%PASSWORD_PFX% -out %ORG_Root%\ca.%ORG_Root%.pfx
IF %ERRORLEVEL% NEQ 0 pause & exit 1

echo %b% certutil -f -p %PASSWORD_PFX% %%~dp0\ca.%ORG_Root%.pfx %END%
echo certutil -f -p %PASSWORD_PFX% %%~dp0\ca.%ORG_Root%.pfx >%ORG_Root%\ca.%ORG_Root%.pfx.cmd

goto :EOF

:import_CRT_Root_PEM
echo %c%%~0%END%

:: https://medium.com/better-programming/trusted-self-signed-certificate-and-local-domains-for-testing-7c6e6e3f9548
:: no friendly name with PEM
echo certutil -f -addstore "Root" %ORG_Root%\ca.%ORG_Root%.crt
certutil -f -addstore "Root" %ORG_Root%\ca.%ORG_Root%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

goto :EOF

:O---------O
:Intermediate
:O---------O

:create_KEY_Intermediate_RSA
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl rsa -noout -text -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key %END%

IF EXIST %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
openssl genrsa -passout pass:%PASSWORD_Intermediate% -out %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: view it:
REM openssl rsa -noout -text -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key
goto :EOF

:create_KEY_Intermediate_ECC
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl ec -noout -text -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key -passin pass:%PASSWORD_Intermediate% %END%

IF EXIST %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key exit /b 0

:: https://www.ibm.com/support/knowledgecenter/en/SSB27H_6.2.0/fa2ti_openssl_using_ECCdhersa_generate_ECC_key.html
:: https://stackoverflow.com/questions/64961096/what-is-the-suggested-openssl-command-to-generate-ec-key-and-csr-compatible-with
:: https://www.openssl.org/docs/man1.1.0/man1/genpkey.html
:: options 1: why you need to store the params: https://wiki.openssl.org/index.php/Command_Line_Elliptic_Curve_Operations
openssl ecparam -out %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.param.crt -name secp%default_ECC_Intermediate%r1
openssl genpkey -paramfile %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.param.crt -out %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key -pass pass:%PASSWORD_Intermediate%

:: options 2:
REM openssl genpkey -algorithm EC -out %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key -pkeyopt ec_paramgen_curve:P-%default_ECC_Intermediate% -pkeyopt ec_param_enc:named_curve

IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: view it:
REM openssl ec -noout -text -in %ORG_Root%\ca.%ORG_Root%.key -passin pass:%PASSWORD_Root%
goto :EOF

:create_CSR_Intermediate
echo %c%%~0%END%
:: verify it:
echo %HIGH%%b%  openssl req -verify -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.csr -text -noout %END%

IF EXIST %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt IF /I NOT "%FORCE_Intermediate%"=="y" exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
:: you don't have to specify rsa keysize here, it's using the private key size
REM -newkey rsa:%default_bits_Intermediate%
:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM M$ and gg both have same group -subj "/CN=%ORG_Intermediate% Root/O=%ORG_Root%/C=%countryName%"
openssl req -new -%default_md_Intermediate% -nodes -subj "/CN=%ORG_Intermediate% RSA TLS CA/O=%ORG_Root%/C=%countryName%" -key %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key -passin pass:%PASSWORD_Intermediate% -out %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.csr
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: verify it:
REM openssl req -verify -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.csr -text -noout
goto :EOF

:create_CRT_Intermediate
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl x509 -text -noout -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt %END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt %END%

IF EXIST %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt IF /I NOT "%FORCE_Intermediate%"=="y" exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl x509 -req -%default_md_Intermediate% -days %default_days_Intermediate% -CA %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Root%.crt -CAkey %ORG_Root%\ca.%ORG_Root%.key -CAcreateserial -CAserial %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.srl -extfile openssl.%ORG_Root%.cfg -extensions v3_intermediate_ca -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.csr -out %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt

:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM -startdate val          Cert notBefore, YYMMDDHHMMSSZ
REM -enddate val            YYMMDDHHMMSSZ cert notAfter (overrides -days)
REM -create_serial          will generate serialNumber into serialNumber.pem
REM -rand_serial            will generate serialNumber everytime and not store it, but actually it does
REM -md %default_md_Intermediate%        sha256 sha512
REM -extfile openssl.%ORG_Root%.cfg
REM -updatedb
REM echo|set /p=>%ORG_Root%\index.txt
openssl ca -batch -create_serial -days %default_days_Intermediate% -passin pass:%PASSWORD_Root% -extfile openssl.%ORG_Root%.cfg -extensions v3_intermediate_ca -keyfile %ORG_Root%\ca.%ORG_Root%.key -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.csr -out %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt
openssl ca -batch -create_serial -days %default_days_Intermediate% -passin pass:%PASSWORD_Root% -extensions v3_intermediate_ca -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.csr -out %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt
openssl ca -batch -create_serial -days %default_days_Intermediate% -passin pass:%PASSWORD_Root% -extfile openssl.%ORG_Root%.cfg -extensions v3_intermediate_ca -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.csr -out %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

certutil -dump %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt | findstr /b /c:"Cert Hash(sha1)" | for /f "tokens=3" %%t in ('more') do @echo %c%THUMBPRINT =%END% %%t

:: view it:
REM openssl x509 -text -noout -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt

:: verify it:
REM certutil -verify -urlfetch %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt
REM openssl verify -CAfile %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Root%.crt %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt

goto :EOF

:create_PFX_Root_Intermediate
echo %c%%~0%END%

:: https://www.phildev.net/ssl/creating_ca.html
openssl pkcs12 -export -name "%ORG_Intermediate% RSA TLS CA" -inkey %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key -passin pass:%PASSWORD_Intermediate% -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt -chain -CAfile %ORG_Root%\ca.%ORG_Root%.crt -passout pass:%PASSWORD_PFX% -out %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.pfx
IF %ERRORLEVEL% NEQ 0 pause & exit 1

echo %b% certutil -importPFX -f -p %PASSWORD_PFX% %%~dp0\%ORG_Intermediate%\ca.%ORG_Intermediate%.pfx %END%
echo certutil -importPFX -f -p %PASSWORD_PFX% %%~dp0\%ORG_Intermediate%\ca.%ORG_Intermediate%.pfx >%ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.pfx.cmd

goto :EOF



:O---------O
:Server
:O---------O

:create_KEY_Subscriber
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl rsa -noout -text -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.key %END%

IF EXIST %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.key exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl genrsa -passout pass:%PASSWORD_Subscriber% -out %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.key

::http://dadhacks.org/2017/12/27/building-a-root-ca-and-an-intermediate-ca-using-openssl-and-debian-stretch/
openssl req -out %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.csr -newkey rsa:%default_bits_Subscriber% -subj "/CN=*.%CADOMAIN%/O=%organizationName%/OU=%ORG_Intermediate%/L=%localityName%/ST=%stateOrProvinceName%/C=%countryName%" -nodes -passout pass:%PASSWORD_Subscriber% -keyout %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.key
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: view it:
REM openssl rsa -noout -text -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.key
goto :EOF

:create_CSR_Subscriber
echo %c%%~0%END%
:: verify it:
echo %HIGH%%b%  openssl req -verify -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.csr -text -noout %END%

IF EXIST %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt IF /I NOT "%FORCE_Subscriber%"=="y" exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM openssl req -new -%default_md_Subscriber% -newkey rsa:%default_bits_Subscriber% -nodes -subj "/CN=*.%CADOMAIN%/O=%organizationName%/OU=%ORG_Intermediate%/L=%localityName%/ST=%stateOrProvinceName%/C=%countryName%" -key %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.key -passin pass:%PASSWORD_Subscriber% -out %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.csr

:: http://dadhacks.org/2017/12/27/building-a-root-ca-and-an-intermediate-ca-using-openssl-and-debian-stretch/
openssl ca -batch -extensions v3_server_cert -days %default_days_Subscriber% -md %default_md_Subscriber% -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.csr -out %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: verify it:
REM openssl req -verify -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.csr -text -noout
goto :EOF

:create_CRT_Subscriber
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl x509 -text -noout -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt %END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt %END%
echo %HIGH%%b%  openssl verify -CAfile %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt %END%

IF EXIST %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt IF /I NOT "%FORCE_Subscriber%"=="y" exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl x509 -req -%default_md_Subscriber% -days %default_days_Subscriber% -CA %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Root%.crt -CAkey %ORG_Root%\ca.%ORG_Root%.key -CAcreateserial -CAserial %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.srl -extfile openssl.%ORG_Root%.cfg -extensions v3_server_cert -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.csr -out %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt

:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM -startdate val          Cert notBefore, YYMMDDHHMMSSZ
REM -enddate val            YYMMDDHHMMSSZ cert notAfter (overrides -days)
REM -create_serial          will generate serialNumber into serialNumber.pem
REM -rand_serial            will generate serialNumber everytime and not store it, but actually it does
REM -md %default_md_Subscriber%        sha256 sha512
REM -keyfile %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key 
REM echo|set /p=>%ORG_Root%\index.txt
REM openssl ca -batch -create_serial -updatedb -days %default_days_Subscriber% -passin pass:%PASSWORD_Intermediate% -extfile openssl.%ORG_Root%.cfg -extensions v3_server_cert -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.csr -out %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt
openssl ca -batch -create_serial -days %default_days_Subscriber% -md %default_md_Subscriber% -extfile openssl.%ORG_Root%.cfg -extensions v3_server_cert -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.csr -out %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

certutil -dump %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt | findstr /b /c:"Cert Hash(sha1)" | for /f "tokens=3" %%t in ('more') do @echo %c%THUMBPRINT =%END% %%t

:: view it:
REM openssl x509 -text -noout -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt

:: verify it:
REM certutil -verify -urlfetch %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt
REM openssl verify -CAfile %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt

goto :EOF


:O---------O

:revoke_CRT
echo %c%%~0%END%

:: https://blog.didierstevens.com/2013/05/08/howto-make-your-own-cert-and-revocation-list-with-openssl/
echo:
echo To revoke the current certificate:
echo %c%  openssl ca -revoke %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt -keyfile %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key -cert %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt %END%

exit /b 0
call :create_CRL

goto :EOF


:create_CRL
echo %c%%~0%END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt %END%

:: https://blog.didierstevens.com/2013/05/08/howto-make-your-own-cert-and-revocation-list-with-openssl/
:: Generate an empty CRL (both in PEM and DER):
openssl ca -gencrl -keyfile %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.key -cert %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt -out %ORG_Root%\%ORG_Intermediate%\root.crl.crt
openssl crl -inform PEM -in %ORG_Root%\%ORG_Intermediate%\root.crl.crt -outform DER -out %ORG_Root%\%ORG_Intermediate%\root.crl

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt %END%
:: verify it:
REM certutil -verify -urlfetch %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt

:: a Windows Server 2003 CA will always check revocation on all certificates in the PKI hierarchy (except the root CA certificate) before issuing an end-entity certificate. However in this situation, a valid Certificate Revocation List (CRL) for one or more of the intermediate certification authority (CA) certificates was not be found since the root CA was offline. This issue may occur if the CRL is not available to the certificate server, or if the CRL has expired.

:: You may disabled the feature that checks revocation on all certificates in the PKI hierarchy with the following command on the CA:

REM certutil –setreg ca\CRLFlags +CRLF_REVCHECK_IGNORE_OFFLINE
goto :EOF


:create_chain_PEM
echo %c%%~0%END%
type %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt %ORG_Root%\ca.%ORG_Root%.crt >%ORG_Root%\ca-chain-bundle.%ORG_Root%.pem 2>NUL
openssl verify -purpose sslclient -untrusted %ORG_Root%\ca-chain-bundle.%ORG_Root%.pem %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt

openssl x509 -noout -subject -issuer -in %ORG_Root%\ca.%ORG_Root%.crt
openssl x509 -noout -subject -issuer -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt
openssl x509 -noout -subject -issuer -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt

goto :EOF


:create_PFX_Root_Intermediate_Subscriber
echo %c%%~0%END%

:: https://stackoverflow.com/questions/9971464/how-to-convert-crt-cetificate-file-to-pfx
:: CRT + CA: all in one
REM openssl pkcs12 -export -name "*.%CADOMAIN%" -inkey %ORG_Root%\ca.%ORG_Root%.key -passin pass:%PASSWORD_Root% -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt -certfile %ORG_Root%\ca.%ORG_Root%.crt -passout pass:%PASSWORD_PFX% -out %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.pfx

:: certfile and CAfile seem identical
openssl pkcs12 -export -name "*.%CADOMAIN%" -out %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.pfx -passout pass:%PASSWORD_PFX% -inkey %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.key -passin pass:%PASSWORD_Subscriber% -chain -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt -in %ORG_Root%\ca.%ORG_Root%.crt 
openssl pkcs12 -export -name "*.%CADOMAIN%" -inkey %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.key -passin pass:%PASSWORD_Subscriber% -in %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.crt  -in %ORG_Root%\%ORG_Intermediate%\ca.%ORG_Intermediate%.crt  -CAfile %ORG_Root%\ca.%ORG_Intermediate%\%ORG_Intermediate%.crt -passout pass:%PASSWORD_PFX% -out %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.pfx 

IF %ERRORLEVEL% NEQ 0 pause & exit 1

echo %b% certutil -importPFX -f -p "%PASSWORD_PFX%" %%~dp0\%CADOMAIN%.pfx %END%
echo certutil -importPFX -f -p "%PASSWORD_PFX%" %%~dp0\%CADOMAIN%.pfx >%ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.pfx.cmd
echo certutil -verify -urlfetch %%~dp0\%CADOMAIN%.crt >>%ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.pfx.cmd

echo: >>%ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.pfx.cmd
echo echo How to revoque IR5 certificates: >>%ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.pfx.cmd
echo echo netsh http delete sslcert ipport=0.0.0.0:8085 >>%ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.pfx.cmd
echo echo netsh http delete sslcert ipport=0.0.0.0:8086 >>%ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.pfx.cmd
echo timeout /t 5 >>%ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.pfx.cmd

goto :EOF


:import_chain_CRT
echo %c%%~0%END%

echo %HIGH%%b%  certutil -importPFX -f -p "%PASSWORD_PFX%" %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.pfx %END%

set /p IMPORT=Import PFX? [%IMPORT_PFX%] 
IF /I "%IMPORT_PFX%"=="y" certutil -importPFX -f -p "%PASSWORD_PFX%" %ORG_Root%\%ORG_Intermediate%\%CADOMAIN%.pfx || pause
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
