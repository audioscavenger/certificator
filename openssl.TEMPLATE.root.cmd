::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: This batch collects all the variables used to setup your DOMAIN certificates ::
::               Simply replace the values where you see fit.                   ::
::                    Some values can also be left blank.                       ::
::                 https://cabforum.org/extended-validation/                    ::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: RSA vs ECC is still subject of debate as of 2021.
:: There is no denial that it's faster and exponentially more secure than rsa
:: However some ill-developped clients still cannot handle it
set ENCRYPTION=RSA

:: this is your Root CA ORGanisation short name
set ORG_Root=YOURORG
:: this is your Intermediate ORGanisation short name and could be = to %USERDOMAIN%
set ORG_Intermediate=YOURDOMAIN

:: website of the CA emiter:
set authorityInfoAccessOCSP=ocsp.godaddy.com/

:: pkix-cert of the emiter:
set authorityInfoAccessCaIssuers=certificates.godaddy.com/repository/gdig2.crt

:: 3650 = 10 years
set default_days_Root=7300

:: From a security perspective, sha512 is overkill: In practical terms, SHA-256 is just as secure as SHA-384 or SHA-512. 
:: We can't produce collisions in any of them with current or foreseeable technology, so the security you get is identical. 
set default_md_Root=sha512

:: Expert constantly predict the end of 1024bit encryption but, as of 2021 it still has not been breaked; using 2048 your security is improved 2^1024 times
:: https://sectigo.com/resource-library/rsa-vs-dsa-vs-ecc-encryption
::    RSA     ECC
::    1024    160
::    2048    224
::    3072    256
::    7680    384
::    15360   521
set default_bits_Root=4096
set default_ecc_Root=521

:: Password for Private keys and certificates, can be blank but should be 20 chars really
set PASSWORD_Root=root_key_pass

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: req_distinguished_name section, https://en.wikipedia.org/wiki/Certificate_signing_request
set organizationName=caCompany
:: Subject Organization Name Field: subject:organizationName (OID 2.5.4.10 )
set organizationalUnitName=YOURORG
:: Subject Common Name Field: subject:commonName (OID:  2.5.4.3)
:: Required/Optional:   Deprecated (Discouraged, but not prohibited)
set commonName=caCompany YOURORG Root
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
