#!/bin/bash

# $1 = renewal threshold: 

# Example command: 
# sh renewcertificate.sh 10

# prepare variables
PKI_DIR="/home/$USER/.scepman" # user scepman directory
NOENC_KEY_FILE="scepman-client-noenc.key.pem" # unencrypted key file name
KEY_FILE="scepman-client.key.pem"
CERT_FILE="scepman-client.pem" # client cert file name
CA_CERT_FILE="scepman-root.pem" # root CA file name
APPSERVICE_URL="https://app-scepman-kuvpncndxfzvo.azurewebsites.net/" # SCEPman instance root URL
UPN=$(cat $PKI_DIR/upn) # read UPN from scepman directory
PASSPHRASE=$(cat $PKI_DIR/pp) # passphrase for private key
HOSTNAME=$(hostname) # get hostname
SUBJECT="$UPN-$HOSTNAME" # subject to use in cert request
ABS_CER=`readlink -f $PKI_DIR/$CERT_FILE` # read cert file path
ABS_KEY=`readlink -f $PKI_DIR/$NOENC_KEY_FILE` # read cert key file path
ABS_ROOT=`readlink -f $PKI_DIR/$CA_CERT_FILE` # read CA file path
echo "ABS_KEY: $ABS_KEY"

TEMP=$(mktemp -d tmpXXXXXXX)
TEMP_CSR="$TEMP/tmp.csr"
TEMP_KEY="$TEMP/tmp.key"
TEMP_P7B="$TEMP/tmp.p7b"
TEMP_PEM="$TEMP/tmp.pem"

SECONDS_IN_DAY="86400"
RENEWAL_THRESHOLD_DAYS="$1" # Can be changed - number of days before expiry that a certificate will be renewed
RENEWAL_THRESHOLD=$(($RENEWAL_THRESHOLD_DAYS * $SECONDS_IN_DAY))

trap "rm -r $TEMP" EXIT

# if revoked then do nothing
OCSP_STATUS=`openssl ocsp -issuer "$ABS_ROOT" -cert "$ABS_CER" -url "$APPSERVICE_URL/ocsp"` 
TRIMMED_STATUS=`echo "$OCSP_STATUS" | grep "good"`
if ! [ -z "${TRIMMED_STATUS}" ]; then
	echo "Checking cert renewal... "
    if ! openssl x509 -checkend $RENEWAL_THRESHOLD -noout -in "$ABS_CER"; then
        # Certificate will expire within 10 days, renew using mTLS.

        # Unsure if challenge password is necessary for CSR.
	echo "creating new cert request with key: $PKI_DIR/$NOENC_KEY_FILE"
        openssl req -new -key "$PKI_DIR/$NOENC_KEY_FILE" -sha256 -out "$TEMP_CSR" -subj "/CN=$SUBJECT" -passout pass: -passin pass:""

        # Create renewed version of certificate.
	echo "Submitting request with curl..."
        echo "-----BEGIN PKCS7-----" > "$TEMP_P7B"
        curl -X POST --data "@$TEMP_CSR" -H "Content-Type: application/pkcs10" --cert "$ABS_CER" --key "$PKI_DIR/$NOENC_KEY_FILE" --pass "" --cacert "$ABS_ROOT" "$APPSERVICE_URL/.well-known/est/simplereenroll" >> "$TEMP_P7B"
        printf "\n-----END PKCS7-----" >> "$TEMP_P7B"

	echo "printing certs to file: $TEMP_PEM"
        openssl pkcs7 -print_certs -in "$TEMP_P7B" -out "$TEMP_PEM"
        if [ -f $TEMP_PEM ]; then
            # only execute if new pem file created:
            # re-useing existing private key so don't overwrite
		#cp "$TEMP_KEY" "$ABS_KEY"
            cp "$TEMP_PEM" "$ABS_CER"
        else
            echo "Renewal endpoint returned an error"
            exit 1
        fi
        
    else 
        echo "Certificate not expiring soon"
        exit 1
    fi
else
    echo "OCSP failed - probably invalid paths or revoked certificate" #can update this to reflect all of openssl ocsp errors
    exit 1
fi

