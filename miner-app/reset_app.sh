#!/bin/bash

# Set QUANTUS_HOME if not set
if [ -z "$QUANTUS_HOME" ]; then
    QUANTUS_HOME="$HOME/.quantus"
fi

echo "Resetting Quantus Miner App..."
echo "QUANTUS_HOME: $QUANTUS_HOME"

# Define paths
NODE_BINARY_PATH="$QUANTUS_HOME/bin/quantus-node"
EXTERNAL_MINER_BINARY_PATH="$QUANTUS_HOME/bin/external-miner"
NODE_KEY_PATH="$QUANTUS_HOME/node_key.p2p"
REWARDS_ADDRESS_PATH="$QUANTUS_HOME/rewards-address.txt"
NODE_DATA_PATH="$QUANTUS_HOME/node_data"
BIN_DIR="$QUANTUS_HOME/bin"

# --- Additions for Keychain --- 
# Define Keychain variables
# The service name is typically flutter_secure_storage.KEY_NAME
FLUTTER_SECURE_STORAGE_KEY_NAME="rewards_address_mnemonic"
SERVICE_NAME="flutter_secure_storage.$FLUTTER_SECURE_STORAGE_KEY_NAME"
# The account name is the app's bundle identifier
ACCOUNT_NAME="com.example.quantusMiner"
# --- End Additions for Keychain ---

echo ""
echo "=== Deleting Binaries ==="

# Delete the node binary
if [ -f "$NODE_BINARY_PATH" ]; then
    echo "Deleting node binary: $NODE_BINARY_PATH"
    rm -f "$NODE_BINARY_PATH"
else
    echo "Node binary not found: $NODE_BINARY_PATH"
fi

# Delete the external miner binary
if [ -f "$EXTERNAL_MINER_BINARY_PATH" ]; then
    echo "Deleting external miner binary: $EXTERNAL_MINER_BINARY_PATH"
    rm -f "$EXTERNAL_MINER_BINARY_PATH"
else
    echo "External miner binary not found: $EXTERNAL_MINER_BINARY_PATH"
fi

# Delete the entire bin directory if it exists and is empty
if [ -d "$BIN_DIR" ]; then
    echo "Cleaning up bin directory: $BIN_DIR"
    # Remove any leftover tar.gz files
    rm -f "$BIN_DIR"/*.tar.gz
    # Remove directory if empty
    rmdir "$BIN_DIR" 2>/dev/null || echo "Bin directory not empty, keeping it"
fi

echo ""
echo "=== Deleting Configuration Files ==="

# Delete node key file
if [ -f "$NODE_KEY_PATH" ]; then
    echo "Deleting node key file: $NODE_KEY_PATH"
    rm -f "$NODE_KEY_PATH"
else
    echo "Node key file not found: $NODE_KEY_PATH"
fi

# Delete rewards address file
if [ -f "$REWARDS_ADDRESS_PATH" ]; then
    echo "Deleting rewards address file: $REWARDS_ADDRESS_PATH"
    rm -f "$REWARDS_ADDRESS_PATH"
else
    echo "Rewards address file not found: $REWARDS_ADDRESS_PATH"
fi

echo ""
echo "=== Deleting Node Data Directory ==="

# Delete the node data directory
if [ -d "$NODE_DATA_PATH" ]; then
    echo "Deleting node data directory: $NODE_DATA_PATH"
    rm -rf "$NODE_DATA_PATH"
else
    echo "Node data directory not found: $NODE_DATA_PATH"
fi

echo ""
echo "=== Deleting Keychain Items ==="

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

echo ""
echo "=== Cleanup Complete ==="

# Remove the entire .quantus directory if it's empty
if [ -d "$QUANTUS_HOME" ]; then
    rmdir "$QUANTUS_HOME" 2>/dev/null && echo "Removed empty QUANTUS_HOME directory: $QUANTUS_HOME" || echo "QUANTUS_HOME directory not empty, keeping it: $QUANTUS_HOME"
fi

echo ""
echo "🎉 App reset complete! You can now run the setup process again." 