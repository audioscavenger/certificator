::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: This batch collects all the variables used to setup your DOMAIN certificates ::
::               Simply replace the values where you see fit.                   ::
::                    Some values can also be left blank.                       ::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: this is your FQDN domain and should be = to %USERDNSDOMAIN%
set CADOMAIN=INTERNAL.NQSALES.COM

:: this is your ORGanisation short name and should be = to %USERDOMAIN%
set ORG_Root=NQSALES

:: Authority Information Access: -------------------------------------------------
:: website of the CA emiter:
set authorityInfoAccessOCSP=sales-cc.INTERNAL.NQSALES.COM/ocsp/
:: cert of the emiter:
set authorityInfoAccessCaIssuers=sales-cc.INTERNAL.NQSALES.COM/int.NQSALES.crt

:: 3650 = 10 years
set default_days=3650

:: Expert constantly predict the end of 1024bit encryption but, as of 2021 it still has not been breaked; using 2048 your security is improved 2^1024 times
:: From a security perspective, sha512 it would be pretty pointless: In practical terms, SHA-256 is just as secure as SHA-384 or SHA-512. We can't produce collisions in any of them with current or foreseeable technology, so the security you get is identical. 
set default_md=sha256
set default_bits=2048

:: Password for Private keys and certificates, can be blank but should be 20 chars really
set PASSWORD_Root=INTERNAL.NQSALES.COM

:: Password for exported PFX files, cannot be blank because of java\keytool
set PASSWORD_PFX=INTERNAL.NQSALES.COM

:: req_distinguished_name section, https://en.wikipedia.org/wiki/Certificate_signing_request
:: Only countryName MUST be 2 chars, the rest can be 64 chars max
set countryName=US
set stateOrProvinceName=Arizona
set localityName=Tempe
set organizationName=nQ ZebraWorks Inc.
set organizationalUnitName=NQSALES
set commonName=nQ ZebraWorks Inc.
set emailAddress=admin@nqzw.com
:: optional:
set postalCode=85284
set streetAddress=7890 S Hardy Drive
:: secondary company name:
set unstructuredName=nQ ZebraWorks Inc.

:: [alt_names] section, enter a list of domains/IP to cover; there is no limit
:: You can add short machine names, IP addresses, and wildcard domains
:: Simply increment the DNS.{num} of the variable to add more domains
:: Delete the lines you do not need starting from the bottom
set DNS.1=*.INTERNAL.NQSALES.COM
set DNS.2=sales-cc.INTERNAL.NQSALES.COM
set DNS.3=sales-ep-2.INTERNAL.NQSALES.COM
set DNS.4=sales-ir5.INTERNAL.NQSALES.COM
set DNS.5=sales-pa.INTERNAL.NQSALES.COM
set DNS.6=sales-im-100.INTERNAL.NQSALES.COM
set DNS.7=sales-ot-16.INTERNAL.NQSALES.COM
set DNS.8=sales-pl-19.INTERNAL.NQSALES.COM
set DNS.9=sales-sql.INTERNAL.NQSALES.COM
set DNS.10=sales-wd-gx4.INTERNAL.NQSALES.COM
set DNS.11=sales-cc
set DNS.12=sales-ep-2
set DNS.13=sales-ir5
set DNS.14=sales-pa
set DNS.15=sales-im-100
set DNS.16=sales-ot-16
set DNS.17=sales-pl-19
set DNS.18=sales-sql
set DNS.19=sales-wd-gx4
set IP.1=10.1.13.12
set IP.2=10.1.13.121
set IP.3=10.1.13.95
set IP.4=10.1.13.97
set IP.5=10.1.13.34
set IP.6=10.1.13.42
set IP.7=10.1.13.53
set IP.8=10.1.13.17
set IP.9=10.1.13.81


:: X509v3 Certificate Policies:
:: CPS Point to the Internet Security Research Group (ISRG) Certification Practice Statementer of the CA emiter
:: that describes the policy under which the certificate in the subject was issued. 
:: examples: http://cps.letsencrypt.org   http://certificates.godaddy.com/repository/   https://www.digicert.com/legal-repository
set CPS.1=https://www.nqzw.com/
:: OIDs of public policies that apply to you. Add at least one.
:: Example: 2.23.140.1.2.1 = https://oidref.com/2.23.140.1.2.1 = domain-validated
:: Example: 1.3.6.1.4.1.44947.1.1.1 = OID attached to certificates issued by Let's Encrypt.
:: Example: 2.16.840.1.101 = gov; 2.16.840.1.113938 = EQUIFAX INC.; etc
set policiesOIDsSubordinate=2.23.140.1.2.1
:: https://stackoverflow.com/questions/51641962/how-do-i-create-my-own-extended-validation-certificate-to-display-a-green-bar/51644728
:: https://www.sysadmins.lv/blog-en/certificate-policies-extension-all-you-should-know-part-1.aspx
:: Object Identifiers (OID) are controlled by IANA and you need to register a Private Enterprise Number (PEN), or OID arc under 1.3.6.1.4.1 namespace.
:: Here is the FREE PEN registration page: http://pen.iana.org/pen/PenApplication.page
set policyIdentifier=1.3.5.8

:: User Notice is a small piece of text (RFC recommends to use no more than 200 characters) that describes particular policy.
set explicitText=This certificate protects the private data transmitted throught the local domain NQSALES, own by nQ ZebraWorks Inc.
set organization=nQ ZebraWorks Inc.

:: revocation url: you should server root.crl and root.crl.pem over http at this address:
set crlDistributionPoints.1=http://sales-cc.INTERNAL.NQSALES.COM/root.crl

:: //TODO: CT Precertificate SCTs: https://certificate.transparency.dev/howctworks/
:: //TODO: CT Precertificate SCTs: https://letsencrypt.org/2018/04/04/sct-encoding.html
