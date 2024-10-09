# parameters
# $1 = full path to downloaded PFX file
# $2 = PFX file password
# $3 = SCEPman URL prefix (app-scepman-xxxxxxxxxxxxxxx)
# $4 = Wifi SSID

# validate input
ARG_MISSING=$(printf "ERROR: Missing argument\n
1 = full path to PFX file\n
2 = PFX file password\n
3 = SCEPMAN URL prefix (app-scepman-xxxxxxxxxxxxxxx)\n
4 = Wifi SSID")

: "${1:?"$ARG_MISSING"}"
: "${2:?"$ARG_MISSING"}"
: "${3:?"$ARG_MISSING"}"
: "${4:?"$ARG_MISSING"}"

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

echo "PFX_FILE: $PFX_FILE"

# save SCEPman url root
echo "Saving SCEPman URL root: $3"
echo "$3" >"$PKI_DIR/scepmanurlroot"

# verify or create pki directory
echo "${GREEN}Verifying PKI directory..."
if [ -d "$PKI_DIR" ]; then
	echo "$PKI_DIR exists..."
else
	echo "${GREEN}$PKI_DIR NOT found, creating..."
	mkdir $PKI_DIR
fi

# copy renewal script to pki directory
echo "${GREEN}Copying renewal script to PKI_DIR"
cp "./renewcertificate.sh" "$PKI_DIR/"

# get CA cert and convert it to PEM
echo "${GREEN}Downloading CA cert from SCEPman...${NC}"
wget -O "$PKI_DIR/scepman-root.cer" \
	"$SCEPMAN_URL/certsrv/mscep/mscep.dll/pkiclient.exe?operation=GetCACert"
openssl x509 -in "$PKI_DIR/scepman-root.cer" \
	-outform PEM -out "$PKI_DIR/scepman-root.pem"

# save username (to be used in renewal script)
BN=$(basename $PFX_FILE)
#echo "basename; $BN"
UPN=$(echo "${BN//certificate-/}")
#echo "UPN temp: $UPN"
UPN=$(echo $UPN | cut -d '-' -f 1)
echo "${GREEN}Saving UPN: $UPN...${NC}"
echo $UPN >$PKI_DIR/upn

# save private key passphrase
echo $PFX_PASS >$PKI_DIR/pp

# extract key from PFX and encrypt with PFX password
echo "${GREEN}Extracting private key...${NC}"
openssl pkcs12 -in $PFX_FILE -nocerts -out $PKI_DIR/$KEY_FILE -passin pass:$PFX_PASS -passout pass:$PFX_PASS

# extract certificate from PFX
echo "${GREEN}Extracting client certificate...${NC}"
openssl pkcs12 -in $1 -clcerts -nokeys -out $PKI_DIR/$CERT_FILE -passin pass:$PFX_PASS

# delete any existing connections for the same SSID
echo "${GREEN}Deleting any existing $SSID connections...${NC}"
CONS_DEL=$(nmcli -t -f name,UUID con | grep "$SSID" | cut -d ":" -f 2)
for line in $CONS_DEL; do
	sudo nmcli con delete "$line"
done

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

# add/update cron job to renew certificate daily
echo "${GREEN}Adding cron job for renewal...${NC}"
COMMAND="/home/$USER/.scepman/renewcertificate.sh 30"
JOB="0 10 * * * $COMMAND"
(
	crontab -l
	echo "$JOB"
) | sort - | uniq - | crontab -
echo "${GREEN}cron jobs:${NC}"
crontab -l
