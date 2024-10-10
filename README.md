Setup your wifi network and the renewal script with the following command:
```
curl -sSL https://raw.githubusercontent.com/tbrock-opti/SCEPman/refs/heads/main/importCert.sh | bash -s -- \
	/path/to/certificate.pfx \
	cert-private-key \
	scepman-hostname-without-fqdn \
	"Wireless SSID"
```
