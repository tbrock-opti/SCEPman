#!/bin/bash

# Ensure Zenity is installed
if ! command -v zenity &> /dev/null; then
    echo "Zenity is not installed. Please install it to use this script."
    exit 1
fi

# Function to clean up in case of errors
cleanup() {
    zenity --warning --text="An error occurred. Undoing changes."
    rm -rf "$PKI_DIR"
}

# Set trap to call cleanup on any error
trap cleanup ERR

# Prompt user for inputs using Zenity dialogs
PFX_FILE=$(zenity --file-selection --title="Select the PFX File")
if [[ -z "$PFX_FILE" ]]; then
    zenity --error --text="No file selected. Exiting."
    exit 1
fi

PFX_PASS=$(zenity --entry --title="PFX Password" --hide-text --text="Enter the PFX file password")
if [[ -z "$PFX_PASS" ]]; then
    zenity --error --text="Password not provided. Exiting."
    exit 1
fi

SSID="Optimizely Internal"

#UPN=$(zenity --entry --title="UPN/Username" --text="Enter the UPN/Username, i.e: QuocHuy.Le@optimizely.com")
#if [[ -z "$UPN" ]]; then
#    zenity --error --text="UPN/Username not provided. Exiting."
#    exit 1
#fi

USERHOME=${USER%@*}

# Define necessary variables
PKI_DIR="/home/$USERHOME/.scepman"
KEY_FILE="scepman-client.key.pem"
CERT_FILE="scepman-client.pem"
SCEPMAN_URL="https://app-scepman-kuvpncndxfzvo.azurewebsites.net"
CA_CERT_FILENAME="scepman-root.pem"
RENEWAL_CERT_URL="http://10.141.0.33/scepman/renewcertificate.sh"
GREEN=$(tput setaf 2)
NC=$(tput sgr0)

# Verify or create PKI directory
echo "${GREEN}Verifying PKI directory..."
if [ -d "$PKI_DIR" ]; then
    echo "$PKI_DIR exists..."
else
    echo "${GREEN}$PKI_DIR NOT found, creating..."
    mkdir $PKI_DIR || exit 1
fi

# Save SCEPman URL root
echo "Saving SCEPman URL root: $SCEPMAN_PREFIX"
echo "$SCEPMAN_PREFIX" > "$PKI_DIR/scepmanurlroot"

# Copy renewal script to PKI directory
echo "${GREEN}Copying renewal script to PKI_DIR"
wget -O "$PKI_DIR/renewcertificate.sh" "$RENEWAL_CERT_URL" || exit 1

# Get CA cert and convert it to PEM
echo "${GREEN}Downloading CA cert from SCEPman...${NC}"
wget -O "$PKI_DIR/scepman-root.cer" "$SCEPMAN_URL/certsrv/mscep/mscep.dll/pkiclient.exe?operation=GetCACert" || exit 1

echo "${GREEN}Converting CA cert to PEM...${NC}"
openssl x509 -inform DER -in "$PKI_DIR/scepman-root.cer" -outform PEM -out "$PKI_DIR/$CA_CERT_FILENAME" || exit 1

# Save UPN
#echo "${GREEN}Saving UPN: $UPN...${NC}"
#echo $UPN >$PKI_DIR/upn

# Save private key passphrase
echo $PFX_PASS >$PKI_DIR/pp

# Extract key from PFX and encrypt with PFX password
echo "${GREEN}Extracting private key...${NC}"
openssl pkcs12 -in "$PFX_FILE" -nocerts -out "$PKI_DIR/$KEY_FILE" -passin pass:$PFX_PASS -passout pass:$PFX_PASS || exit 1

# Extract certificate from PFX
echo "${GREEN}Extracting client certificate...${NC}"
openssl pkcs12 -in "$PFX_FILE" -clcerts -nokeys -out "$PKI_DIR/$CERT_FILE" -passin pass:$PFX_PASS || exit 1

# Delete any existing connections for the same SSID
echo "${GREEN}Deleting any existing $SSID connections...${NC}"
CONS_DEL=$(nmcli -t -f name,UUID con | grep "$SSID" | cut -d ":" -f 2)
for line in $CONS_DEL; do
    sudo nmcli con delete "$line"
done

# Create Wi-Fi connection
echo "${GREEN}Creating Wifi Connection for $SSID...${NC}"
sudo nmcli connection add type wifi con-name "$SSID" \
    802-11-wireless.ssid "$SSID" \
    802-11-wireless-security.key-mgmt wpa-eap \
    802-1x.eap tls \
    802-1x.identity "anonymous" \
    802-1x.ca-cert "$PKI_DIR/$CA_CERT_FILENAME" \
    802-1x.client-cert "$PKI_DIR/$CERT_FILE" \
    802-1x.private-key "$PKI_DIR/$KEY_FILE" \
    802-1x.private-key-password "$PFX_PASS" || exit 1

# Add/update cron job to renew certificate daily
echo "${GREEN}Adding cron job for renewal...${NC}"
COMMAND="$PKI_DIR/renewcertificate.sh 30"
JOB="0 10 * * * $COMMAND"
(
    crontab -l
    echo "$JOB"
) | sort - | uniq - | crontab -
echo "${GREEN}cron jobs:${NC}"
crontab -l
sudo chmod +x "$PKI_DIR/renewcertificate.sh"
