# Resonance Network Wallet

A mobile wallet application for the Resonance Network blockchain and its native REZ cryptocurrency.

## Features

- **Welcome Screen**: Create a new wallet or import an existing one
- **Create Wallet**: Generates a 24-word recovery phrase for a new wallet
- **Import Wallet**: Restore access using a 12 or 24-word recovery phrase
- **Main Wallet Screen**: View balance and recent transactions
- **Send REZ**: Send cryptocurrency to other accounts
- **Receive REZ**: Display QR code with your wallet address
- **Identity Support**: Display human-readable names for accounts when available

## Getting Started

### Prerequisites

- Flutter 2.10.0 or higher
- Dart 2.16.0 or higher

### Installation

1. Clone this repository
```
git clone https://github.com/yourusername/resonance-network-wallet.git
```

2. Navigate to the project directory
```
cd resonance-network-wallet
```

3. Install dependencies
```
flutter pub get
```

4. Run the app
```
flutter run
```

## Implementation Notes

- The wallet uses polkadot_dart for Substrate blockchain interactions
- This is a simple implementation with all code in a single file (main.dart)
- In a production environment, the code should be structured into multiple files and follow best practices
- Proper security measures should be implemented for storing private keys and sensitive information

## Security Considerations

- Recovery phrases should be stored securely
- In a production app, biometric authentication should be implemented
- Private keys should be encrypted on device

## License

This project is licensed under the MIT License - see the LICENSE file for details. 