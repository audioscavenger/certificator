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

:: CURRENT: 2-step Ca + *.domain / separate CRT key     https://adfinis.com/en/blog/openssl-x509-certificates/
:: TOTEST:  2-step Ca + *.domain / separate CA/CRT keys https://gist.github.com/Dan-Q/4c7108f1e539ee5aefbb53a334320b27
:: TOTEST:  3-step complete CA/IA/server https://raymii.org/s/tutorials/OpenSSL_command_line_Root_and_Intermediate_CA_including_OCSP_CRL%20and_revocation.html
:: TOTEST:  3-step complete CA + inter + *.domain + client https://blog.behrang.org/articles/creating-a-ca-with-openssl.html

::  1.1.0   separated server csr from key; can regenerate csr
::  1.1.1   renamed root folder to just ORG
::  1.1.2   using RSA keysize from cfg only
::  1.2.0   added CRL list generation
::  1.2.1   added questions to renew certificates
::  1.2.2   switched back to 3-step KEY+CSR+CRT generation
::  1.3.0   CA Browser EV Guidelines
::  1.3.1   added policiesOIDs
::  1.3.2   separated Root/Subordinate/Subscriber for CA sections and altNames
::  1.3.3   added policy_match / policy_amything fields for EV
::  1.3.4   added permitted_subordinate_section
::  1.3.5   added @crl_section
::  1.3.6   added @alt_names_Subscriber
::  1.3.7   added @ocsp_section
::  1.3.8   added working AIA: caIssuers + OCSP
::  1.3.9   added correct policyIdentifier

:init
set version=1.3.9
set author=lderewonko

call :detect_admin_mode
call :set_colors

set ORG=%USERDOMAIN%
REM set PAUSE=echo:
set PAUSE=pause
set RESET=n
set FORCE_CA=n
set FORCE_CRT=y
set DEMO=YOURDOMAIN
set IMPORT_PFX=n


:prechecks
for %%x in (powershell.exe) do (set "powershell=%%~$PATH:x")
IF NOT DEFINED powershell call :error %~0: powershell NOT FOUND

call :check_exist_exit openssl.ORG.cfg
call :check_exist_exit openssl.ORG.cmd



:defaults
IF DEFINED DEMO (
  set ORG=%DEMO%
  set /P ORG=Organisation? [%DEMO%] 
) ELSE (
  set /P ORG=Organisation? [%ORG%] 
)
IF /I "%ORG%"=="ORG" call :error Using ORG as Organisation name is forbidden.

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:main


call :ask_for_values
call :create_cfg openssl.ORG.cfg openssl.%ORG%.cfg
call :reset
call :create_folders

IF EXIST %ORG%\ca.%ORG%.crt         set /P  FORCE_CA=Regenerate CA cert?     [%FORCE_CA%] 
IF EXIST %ORG%\star.%CADOMAIN%.crt  set /P FORCE_CRT=Regenerate Server cert? [%FORCE_CRT%] 

REM set OPENSSL_CONF=%~dp0openssl.%ORG%.cfg
call :create_KEY
%PAUSE%
call :create_CA
%PAUSE%
call :convert_CA_PFX
%PAUSE%

REM set OPENSSL_CONF=%~dp0openssl.%CADOMAIN%.cfg
call :create_server_KEY
%PAUSE%
call :create_server_CSR
%PAUSE%
call :sign_server_CSR
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

IF EXIST openssl.%ORG%.cmd exit /b 0

echo:
echo   %HIGH%Please copy %c%openssl.ORG.cmd%w% into %g%openssl.%ORG%.cmd%w% and set the values inside.
echo                            Then restart this batch%END%
echo                                   Thank you
echo:
pause
exit 0
goto :EOF


:reset
echo %c%%~0%END%
IF /I "%RESET%"=="y" (
  del /f /q %ORG%\*.crt 2>NUL
  del /f /q %ORG%\*.csr 2>NUL
)
goto :EOF


:create_folders
echo %c%%~0%END%

md %ORG%\ 2>NUL
REM md %ORG%\certs 2>NUL
REM md %ORG%\crl 2>NUL
REM md %ORG%\newcerts 2>NUL
REM md %ORG%\private 2>NUL
REM md %ORG%\req 2>NUL

:: https://serverfault.com/questions/857131/odd-error-while-using-openssl
:: https://www.linuxquestions.org/questions/linux-security-4/why-can%27t-i-generate-a-new-certificate-with-openssl-312716/
echo|set /p=>%ORG%\index.txt
echo|set /p="unique_subject = yes">%ORG%\index.txt.attr

:: https://serverfault.com/questions/823679/openssl-error-while-loading-crlnumber
echo|set /p="1000">%ORG%\crlnumber

goto :EOF

:create_cfg in out
echo %c%%~0%END%

call openssl.%ORG%.cmd

:: too slow:
copy /y %1 %2
REM for /f "eol=: tokens=1,2 delims==" %%V in (openssl.ORG.cmd) DO (
  REM powershell -executionPolicy bypass -Command "(Get-Content -Path '%~2') -replace '{%%V}', '%%W' | Set-Content -Path '%~2'"
REM )

powershell -executionPolicy bypass -Command ^(Get-Content %1^) ^| Foreach-Object { ^
    $_ -replace '{CADOMAIN}', '%CADOMAIN%' `^
       -replace '{ORG}', '%ORG%' `^
       -replace '{default_days}', '%default_days%' `^
       -replace '{default_md}', '%default_md%' `^
       -replace '{default_bits}', '%default_bits%' `^
       -replace '{CAPASS}', '%CAPASS%' `^
       -replace '{PFXPASS}', '%PFXPASS%' `^
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
       -replace '{policiesOIDsSubordinate}', '%policiesOIDsSubordinate%' `^
       -replace '{policiesOIDsSubscriber}', '%policiesOIDsSubordinate%' `^
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
REM set OPENSSL_CONF=%~dp0openssl.github.cfg
REM set OPENSSL_CONF=%~dp0openssl.cfg
REM set OPENSSL_CONF=%~dp0openssl.MIT.cfg
REM set OPENSSL_CONF=%~dp0openssl.pki-tutorial.cfg
set OPENSSL_CONF=%~dp0openssl.%ORG%.cfg
REM set OPENSSL_CONF=%~dp0openssl.%ORG%.cfg

goto :EOF

:create_KEY
echo %c%%~0%END%
:: view csr:
echo %HIGH%%b%  openssl req -noout -text -in %ORG%\ca.%ORG%.csr %END%

:: view key:
echo %HIGH%%b%  openssl rsa -noout -text -in %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS% %END%

IF EXIST %ORG%\ca.%ORG%.key.crt IF /I NOT "%FORCE_CA%"=="y" exit /b 0

REM openssl genrsa -aes256 -passout pass:%CAPASS% -out %ORG%\ca.%ORG%.key.crt
REM openssl req -new -newkey rsa -keyout %ORG%\ca.%ORG%.key.crt -out %ORG%\ca.%ORG%.csr -passout pass:%CAPASS%

REM openssl req -new -nodes -newkey rsa -keyout %ORG%\ca.%ORG%.key.crt -out %ORG%\ca.%ORG%.csr
openssl req -batch -new -nodes -keyout %ORG%\ca.%ORG%.key.crt -out %ORG%\ca.%ORG%.csr

:: view csr:
REM openssl req -noout -text -in %ORG%\ca.%ORG%.csr
:: view key:
REM openssl rsa -noout -text -in %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS%

goto :EOF


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: -extensions val     CERT extension section (override value in config file)
:: -reqexts val        REQ  extension section (override value in config file)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


:create_CA
echo %c%%~0%END%
:: verify it:
echo %HIGH%%b%  openssl x509 -text -noout -in %ORG%\ca.%ORG%.crt %END%

IF EXIST %ORG%\ca.%ORG%.crt IF /I NOT "%FORCE_CA%"=="y" exit /b 0

:: https://www.phildev.net/ssl/creating_ca.html
REM openssl ca -batch -create_serial -days 3650 -out %ORG%\ca.%ORG%.crt -keyfile %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS% -selfsign -extensions v3_ca -infiles %ORG%\ca.%ORG%.csr
REM openssl ca -batch -create_serial -rand_serial -subj "/CN=%ORG% CA/OU=OPS/O=%ORG%" -out %ORG%\ca.%ORG%.crt -passin pass:%CAPASS% -keyfile %ORG%\ca.%ORG%.key.crt -selfsign -extensions v3_ca -infiles %ORG%\ca.%ORG%.csr

:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM -startdate val          Cert notBefore, YYMMDDHHMMSSZ
REM -enddate val            YYMMDDHHMMSSZ cert notAfter (overrides -days)
openssl x509 -req -%default_md% -days 3650 -extfile openssl.%ORG%.cfg -extensions nq_root -in %ORG%\ca.%ORG%.csr -signkey %ORG%\ca.%ORG%.key.crt -out %ORG%\ca.%ORG%.crt
REM openssl x509 -req -%default_md% -days 3650 -extensions nq_root -in %ORG%\ca.%ORG%.csr -signkey %ORG%\ca.%ORG%.key.crt -out %ORG%\ca.%ORG%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: verify it:
openssl x509 -text -noout -in %ORG%\ca.%ORG%.crt
goto :EOF

:convert_CA_PFX
echo %c%%~0%END%

REM openssl pkcs12 -export -name "%ORG% CA" -inkey %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS% -in %ORG%\%CADOMAIN%.crt -out %ORG%\ca.%ORG%.pfx -passout pass:%PFXPASS%
REM openssl pkcs12 -export -name "%ORG% CA" -inkey %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS% -in %ORG%\ca.%ORG%.crt -out %ORG%\ca.%ORG%.pfx -passout pass:%PFXPASS%

:: https://www.phildev.net/ssl/creating_ca.html
openssl pkcs12 -export -name "%ORG% CA" -inkey %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS% -in %ORG%\ca.%ORG%.crt -passout pass:%PFXPASS% -out %ORG%\ca.%ORG%.pfx
IF %ERRORLEVEL% NEQ 0 pause & exit 1

echo %b% certutil -f -p %CADOMAIN% %%~dp0ca.%ORG%.pfx %END%
echo certutil -f -p %CADOMAIN% %%~dp0ca.%ORG%.pfx >%ORG%\ca.%ORG%.pfx.cmd

goto :EOF

:import_CA
echo %c%%~0%END%

:: https://medium.com/better-programming/trusted-self-signed-certificate-and-local-domains-for-testing-7c6e6e3f9548
:: no friendly name with PEM
echo certutil -f -addstore "Root" %ORG%\ca.%ORG%.crt
certutil -f -addstore "Root" %ORG%\ca.%ORG%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

goto :EOF

:create_server_KEY
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl rsa -noout -text -in %ORG%\star.%CADOMAIN%.key.crt %END%

IF EXIST %ORG%\star.%CADOMAIN%.key.crt exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
openssl genrsa -passout pass:%CAPASS% -out %ORG%\star.%CADOMAIN%.key.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: view it:
REM openssl rsa -noout -text -in %ORG%\star.%CADOMAIN%.key.crt
goto :EOF

:create_server_CSR
echo %c%%~0%END%
:: verify it:
echo %HIGH%%b%  openssl req -verify -in %ORG%\star.%CADOMAIN%.csr -text -noout %END%

IF EXIST %ORG%\star.%CADOMAIN%.crt IF /I NOT "%FORCE_CRT%"=="y" exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
:: you don't have to specify rsa keysize here, it's in the cfg already
REM openssl req -batch -new -nodes -newkey rsa -subj "/CN=*.%CADOMAIN%" -keyout %ORG%\star.%CADOMAIN%.key.crt -out %ORG%\star.%CADOMAIN%.csr

:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
openssl req -new -%default_md% -nodes -newkey rsa -subj "/CN=*.%CADOMAIN%" -key %ORG%\star.%CADOMAIN%.key.crt -passin pass:%CAPASS% -out %ORG%\star.%CADOMAIN%.csr
IF %ERRORLEVEL% NEQ 0 pause & exit 1

:: verify it:
REM openssl req -verify -in %ORG%\star.%CADOMAIN%.csr -text -noout
goto :EOF

:sign_server_CSR
echo %c%%~0%END%
:: view it:
echo %HIGH%%b%  openssl x509 -text -noout -in %ORG%\star.%CADOMAIN%.crt %END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %ORG%\star.%CADOMAIN%.crt %END%

IF EXIST %ORG%\star.%CADOMAIN%.crt IF /I NOT "%FORCE_CRT%"=="y" exit /b 0

:: https://adfinis.com/en/blog/openssl-x509-certificates/
REM openssl x509 -req -%default_md% -days 3650 -CA %ORG%\ca.%ORG%.crt -CAkey %ORG%\ca.%ORG%.key.crt -CAcreateserial -CAserial %ORG%\star.%CADOMAIN%.srl -extfile openssl.%ORG%.cfg -extensions nq_subscriber -in %ORG%\star.%CADOMAIN%.csr -out %ORG%\star.%CADOMAIN%.crt

:: https://blog.behrang.org/articles/creating-a-ca-with-openssl.html
REM -startdate val          Cert notBefore, YYMMDDHHMMSSZ
REM -enddate val            YYMMDDHHMMSSZ cert notAfter (overrides -days)
REM -create_serial          will generate serialNumber into serialNumber.pem
REM -rand_serial            will generate serialNumber everytime and not store it, but actually it does
REM -md %default_md%        sha256 sha512
openssl ca -batch -create_serial -rand_serial -updatedb -days 3650 -passin pass:%CAPASS% -extfile openssl.%ORG%.cfg -extensions nq_subscriber -keyfile %ORG%\ca.%ORG%.key.crt -in %ORG%\star.%CADOMAIN%.csr -out %ORG%\star.%CADOMAIN%.crt
IF %ERRORLEVEL% NEQ 0 pause & exit 1

certutil -dump %ORG%\star.%CADOMAIN%.crt | findstr /b /c:"Cert Hash(sha1)" | for /f "tokens=3" %%t in ('more') do @echo %c%THUMBPRINT =%END% %%t

:: view it:
REM openssl x509 -text -noout -in %ORG%\star.%CADOMAIN%.crt

:: verify it:
REM certutil -verify -urlfetch %ORG%\star.%CADOMAIN%.crt

goto :EOF


:revoke_CRT
echo %c%%~0%END%

:: https://blog.didierstevens.com/2013/05/08/howto-make-your-own-cert-and-revocation-list-with-openssl/
echo:
echo To revoke the current certificate:
echo %c%  openssl ca -revoke %ORG%\star.%CADOMAIN%.crt -keyfile %ORG%\ca.%ORG%.key.crt -cert %ORG%\ca.%ORG%.crt %END%
REM openssl ca -revoke %ORG%\star.%CADOMAIN%.crt -keyfile %ORG%\ca.%ORG%.key.crt -cert %ORG%\ca.%ORG%.crt

exit /b 0
call :create_CRL

goto :EOF


:create_CRL
echo %c%%~0%END%

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %ORG%\star.%CADOMAIN%.crt %END%

:: https://blog.didierstevens.com/2013/05/08/howto-make-your-own-cert-and-revocation-list-with-openssl/
:: Generate an empty CRL (both in PEM and DER):
openssl ca -gencrl -keyfile %ORG%\ca.%ORG%.key.crt -cert %ORG%\ca.%ORG%.crt -out %ORG%\root.crl.crt
openssl crl -inform PEM -in %ORG%\root.crl.crt -outform DER -out %ORG%\root.crl

:: verify it:
echo %HIGH%%b%  certutil -verify -urlfetch %ORG%\star.%CADOMAIN%.crt %END%
:: verify it:
REM certutil -verify -urlfetch %ORG%\star.%CADOMAIN%.crt

:: a Windows Server 2003 CA will always check revocation on all certificates in the PKI hierarchy (except the root CA certificate) before issuing an end-entity certificate. However in this situation, a valid Certificate Revocation List (CRL) for one or more of the intermediate certification authority (CA) certificates was not be found since the root CA was offline. This issue may occur if the CRL is not available to the certificate server, or if the CRL has expired.

:: You may disabled the feature that checks revocation on all certificates in the PKI hierarchy with the following command on the CA:

REM certutil –setreg ca\CRLFlags +CRLF_REVCHECK_IGNORE_OFFLINE
goto :EOF


:convert_chain_PFX
echo %c%%~0%END%

:: https://stackoverflow.com/questions/9971464/how-to-convert-crt-cetificate-file-to-pfx
:: CRT + CA: all in one
REM openssl pkcs12 -export -name "*.%CADOMAIN%" -inkey %ORG%\ca.%ORG%.key.crt -passin pass:%CAPASS% -in %ORG%\star.%CADOMAIN%.crt -certfile %ORG%\ca.%ORG%.crt -passout pass:%PFXPASS% -out %ORG%\%CADOMAIN%.pfx

:: certfile and CAfile seem identical
openssl pkcs12 -export -name "*.%CADOMAIN%" -inkey %ORG%\star.%CADOMAIN%.key.crt -passin pass:%CAPASS% -in %ORG%\star.%CADOMAIN%.crt -chain -CAfile %ORG%\ca.%ORG%.crt -passout pass:%PFXPASS% -out %ORG%\%CADOMAIN%.pfx
IF %ERRORLEVEL% NEQ 0 pause & exit 1

echo %b% certutil -importPFX -f -p "%PFXPASS%" %%~dp0\%CADOMAIN%.pfx %END%
echo certutil -importPFX -f -p "%PFXPASS%" %%~dp0\%CADOMAIN%.pfx >%ORG%\%CADOMAIN%.pfx.cmd
echo certutil -verify -urlfetch %%~dp0\star.%CADOMAIN%.crt >>%ORG%\%CADOMAIN%.pfx.cmd
echo: >>%ORG%\%CADOMAIN%.pfx.cmd
echo revoque IR5 certificates: >>%ORG%\%CADOMAIN%.pfx.cmd
echo netsh http delete sslcert ipport=0.0.0.0:8085 >>%ORG%\%CADOMAIN%.pfx.cmd
echo netsh http delete sslcert ipport=0.0.0.0:8086 >>%ORG%\%CADOMAIN%.pfx.cmd
echo timeout /t 5 >>%ORG%\%CADOMAIN%.pfx.cmd

goto :EOF


:import_chain_CRT
echo %c%%~0%END%

echo %HIGH%%b%  certutil -importPFX -f -p "%PFXPASS%" %ORG%\%CADOMAIN%.pfx %END%

set /p IMPORT=Import PFX? [%IMPORT_PFX%] 
IF /I "%IMPORT_PFX%"=="y" certutil -importPFX -f -p "%PFXPASS%" %ORG%\%CADOMAIN%.pfx || pause
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
