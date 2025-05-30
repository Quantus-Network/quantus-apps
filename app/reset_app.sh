NODE_BINARY_PATH="$QUANTUS_HOME/bin/quantus-node"
NODE_KEY_PATH="$QUANTUS_HOME/node_key.p2p"

# --- Additions for Keychain --- 
# Define Keychain variables
# The service name is typically flutter_secure_storage.KEY_NAME
# Replace "mnemonic" if your app uses a different key for flutter_secure_storage
FLUTTER_SECURE_STORAGE_KEY_NAME="mnemonic"
SERVICE_NAME="flutter_secure_storage.$FLUTTER_SECURE_STORAGE_KEY_NAME"
# The account name is the app's bundle identifier
ACCOUNT_NAME="com.example.quantusMiner"
# --- End Additions for Keychain ---

# Delete the node binary
if [ ! -f "$NODE_BINARY_PATH" ]; then
    echo "Node binary not found: $NODE_BINARY_PATH"
fi

if [ ! -f "$NODE_KEY_PATH" ]; then
    echo "Node identity file not found: $NODE_KEY_PATH"
fi

# --- Additions for Keychain --- 
# Delete the Keychain item for flutter_secure_storage
# Check if the item exists first
echo "Attempting to delete Keychain item for flutter_secure_storage..."
echo "Service: $SERVICE_NAME, Account: $ACCOUNT_NAME"
security find-generic-password -s "$SERVICE_NAME" -a "$ACCOUNT_NAME" &> /dev/null
if [ $? -eq 0 ]; then
    echo "Keychain item found. Deleting..."
    security delete-generic-password -s "$SERVICE_NAME" -a "$ACCOUNT_NAME"
    if [ $? -eq 0 ]; then
        echo "Keychain item deleted successfully."
    else
        echo "Error deleting Keychain item. It might require permissions or may have already been deleted."
    fi
else
    echo "Keychain item not found for service '$SERVICE_NAME' and account '$ACCOUNT_NAME'. No action taken."
fi
# --- End Additions for Keychain ---

echo "App reset complete." 