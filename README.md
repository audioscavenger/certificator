# certificator
![certificator-hierarchy.jpg](assets/certificator-hierarchy.jpg)
- generate CA + Subordinate + Server certificates chain using wildcard.USERDNSDOMAIN
- outputs server PFX and clients PFX + unattended batch install with password inside
- generates CRL structure to renew Sub and Server certs later on
![certificator-chain.jpg](assets/certificator-chain.jpg)


## How To
1. run certificator.cmd and answer the questions
2. edit all 3 batches generated under YOURORG folder and YOURORG/USERDOMAIN subfolder
3. run certificator.cmd again (Optional: run as admin to be able to import the generated PFX)
4. optional: import the generated PFX by runing the generated batches *.chain.pfx.cmd
![certificator-prompt.jpg](assets/certificator-prompt.jpg)

PFX installers:
- DNSDOMAIN/ca.DOMAIN.chain.pfx.cmd = Root+Subordinate chain to deploy on every desktop
- DNSDOMAIN/DNSDOMAIN.chain.pfx.cmd = Root+Subordinate+Server chain to deploy on servers ONLY
![certificator-output.jpg](assets\certificator-output.jpg)

## Requisites
- powershell
- **openssl** for Winmdows (provided in /bin - get it [here](https://slproweb.com/products/Win32OpenSSL.html))
  - works with OpenSSL 1.1.1x and 3.x

## TODO
- [ ] make it clear that our Int is actually a Subordinate, as it cannot generate Subordinate CAs
- [ ] rename int to "sub" or "delegate"
- [ ] retest ECC generation
- [ ] generate extra Intermediate cert
- [ ] generate extra OCSP cert
- [ ] generate extra client cert

