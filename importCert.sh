# parameters
# $1 = full path to downloaded PFX file
# $2 = PFX file password
# $3 = full path to SCEPman CA cert (PEM)
# $4 = Azure UPN (Username) of user cert is for

PFX_FILE="$1"
PFX_PASS="$2"
PKI_DIR="/home/$USER/.scepman"
KEY_FILE="scepman-client.key.pem"
#NOENC_KEY_FILE="scepman-client-noenc.key.pem"
CERT_FILE="scepman-client.pem"
CA_CERT_PATH="$3"
CA_CERT_FILENAME="scepman-root.pem"

# verify or create pki directory
echo "Verifying PKI directory..."
if [ -d "$PKI_DIR" ]; then
	echo "$PKI_DIR exists, copying CA cert..."
else
	echo "$PKI_DIR NOT found, creating..."
	mkdir $PKI_DIR
fi

# verify or copy CA file
echo "Verifying CA cert..."
if [ -f $PKI_DIR/$CA_CERT_FILENAME ]; then
	echo "CA Cert found, skipping..."
else
	echo "CA Cert NOT found, copying..."
	cp $CA_CERT_PATH $PKI_DIR/
fi

# save username (to be used in renewal script)
echo "Saving UPN..."
echo $4 > $PKI_DIR/upn

# save private key passphrase
echo $PFX_PASS > $PKI_DIR/pp

# extract key from PFX and encrypt with PFX password
echo "Extracting private key..."
openssl pkcs12 -in $PFX_FILE -nocerts -out $PKI_DIR/$KEY_FILE -passin pass:$PFX_PASS -passout pass:$PFX_PASS

# extract key from PFX and do not encrypt
# renewing cert isn't compatible with encrypted key files
#openssl pkcs12 -in $PFX_FILE -nocerts -out $PKI_DIR/$NOENC_KEY_FILE -passin pass:$PFX_PASS -passout pass:""

# extract certificate from PFX
echo "Extracting client certificate..."
openssl pkcs12 -in $1 -clcerts -nokeys -out $PKI_DIR/$CERT_FILE -passin pass:$PFX_PASS

# create wifi connection
echo "Creating Wifi Connection for Optimizely Wireless..."
nmcli c add type wifi ifname wlan0 con-name "Optimizely Internal" \
	802-11-wireless.ssid "Optimizely Internal" \
	802-11-wireless-security.key-mgmt wpa-eap \
	802-1x.eap tls \
	802-1x.identity anonymous \
	802-1x.ca-cert $PKI_DIR/$CA_CERT_FILENAME \
	802-1x.client-cert $PKI_DIR/$CERT_FILE \
	802-1x.private-key $PKI_DIR/$KEY_FILE \
	802-1x.private-key-password $PFX_PASS
