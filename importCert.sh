# parameters
# $1 = full path to downloaded PFX file
# $2 = PFX file password
# $3 = SCEPman URL prefix (app-scepman-xxxxxxxxxxxxxxx)
# $4 = Wifi SSID

PFX_FILE="$1"
PFX_PASS="$2"
PKI_DIR="/home/$USER/.scepman"
KEY_FILE="scepman-client.key.pem"
#NOENC_KEY_FILE="scepman-client-noenc.key.pem"
CERT_FILE="scepman-client.pem"
SCEPMAN_URL="https://$3.azurewebsites.net"
CA_CERT_PATH="$3"
CA_CERT_FILENAME="scepman-root.pem"
SSID="$4"
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
NC=$(tput sgr0)

# get UPN from cert path
BN=$(basename $PFX_FILE)
UPN=$(echo "${BN//certificate-/""}" | cut -d '-' -f 1)

# verify or create pki directory
echo "${GREEN}Verifying PKI directory..."
if [ -d "$PKI_DIR" ]; then
	echo "$PKI_DIR exists..."
else
	echo "${GREEN}$PKI_DIR NOT found, creating..."
	mkdir $PKI_DIR
fi

# get CA cert and convert it to PEM
	echo "${GREEN}Downloading CA cert from SCEPman...${NC}"
	wget -O "$PKI_DIR/scepman-root.cer" \
		"$SCEPMAN_URL/certsrv/mscep/mscep.dll/pkiclient.exe?operation=GetCACert"
	openssl x509 -in "$PKI_DIR/scepman-root.cer" \
		-outform PEM -out "$PKI_DIR/scepman-root.pem"

# save username (to be used in renewal script)
echo "${GREEN}Saving UPN...${NC}"
echo $UPN > $PKI_DIR/upn

# save private key passphrase
echo $PFX_PASS > $PKI_DIR/pp

# extract key from PFX and encrypt with PFX password
echo "${GREEN}Extracting private key...${NC}"
openssl pkcs12 -in $PFX_FILE -nocerts -out $PKI_DIR/$KEY_FILE -passin pass:$PFX_PASS -passout pass:$PFX_PASS

# extract key from PFX and do not encrypt
# renewing cert isn't compatible with encrypted key files
#openssl pkcs12 -in $PFX_FILE -nocerts -out $PKI_DIR/$NOENC_KEY_FILE -passin pass:$PFX_PASS -passout pass:""

# extract certificate from PFX
echo "${GREEN}Extracting client certificate...${NC}"
openssl pkcs12 -in $1 -clcerts -nokeys -out $PKI_DIR/$CERT_FILE -passin pass:$PFX_PASS

# delete any existing connections for the same SSID
echo "${GREEN}Deleting any existing $SSID connections...${NC}"
CONS_DEL=$(nmcli -t -f name,UUID con | grep "$SSID" | cut -d ":" -f 2)
if ! [[ -z $CONS_DEL ]]; then
    for line in $CONS_DEL; do 
        sudo nmcli con delete "$line"
    done
fi

# create wifi connection
echo "${GREEN}Creating Wifi Connection for $SSID...${NC}"
sudo nmcli c add type wifi ifname wlan0 con-name "$SSID" \
	802-11-wireless.ssid "$SSID" \
	802-11-wireless-security.key-mgmt wpa-eap \
	802-1x.eap tls \
	802-1x.identity anonymous \
	802-1x.ca-cert $PKI_DIR/$CA_CERT_FILENAME \
	802-1x.client-cert $PKI_DIR/$CERT_FILE \
	802-1x.private-key $PKI_DIR/$KEY_FILE \
	802-1x.private-key-password $PFX_PASS
