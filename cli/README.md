# Resonance Network CLI

Command line interface for Resonance Network blockchain operations including wallet management, reversible transfers (theft deterrence), account recovery, and mining operations.

## Features

- 🔑 **Wallet Management**: Create, import, and manage Dilithium quantum-resistant wallets
- 💰 **Balance Operations**: Check account balances and transfer funds
- 🔒 **Reversible Transfers**: Theft deterrence with reversible transactions
- 🛡️ **Account Recovery**: Multi-signature account recovery system
- ⛏️ **Mining Operations**: Node management and mining controls

## Installation

### From Source

```bash
# Clone the repository and navigate to CLI
cd cli

# Install dependencies using melos (recommended)
cd .. && melos get

# Or install directly
dart pub get

# Build executable
dart compile exe bin/main.dart -o resonance
```

### Using Melos (Workspace)

```bash
# From the root of the workspace
melos build-cli
# This creates ./build/resonance executable
```

## Usage

### Basic Commands

```bash
# Show help
./resonance --help

# Show version
./resonance --version
```

### Wallet Operations

```bash
# Create a new wallet
./resonance wallet create

# Import wallet from mnemonic
./resonance wallet import --mnemonic "word1 word2 ... word12"

# Check balance
./resonance wallet balance --address 5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY
```

### Reversible Transfers (Theft Deterrence)

```bash
# Enable reversibility on your account
./resonance transfer enable --mnemonic "your mnemonic" --delay 3600000

# Schedule a reversible transfer
./resonance transfer send --mnemonic "your mnemonic" --to ADDRESS --amount 1000000000000

# Cancel a pending transfer (theft deterrence!)
./resonance transfer cancel --mnemonic "your mnemonic" --tx-id TRANSACTION_ID

# Check your reversibility settings
./resonance transfer status --address YOUR_ADDRESS
```

### Account Recovery

```bash
# Set up recovery configuration
./resonance recovery setup --mnemonic "your mnemonic" --friends ADDR1,ADDR2,ADDR3 --threshold 2

# Initiate recovery for a lost account
./resonance recovery initiate --mnemonic "rescuer mnemonic" --lost-account LOST_ADDRESS

# Vouch for a recovery (as a friend)
./resonance recovery vouch --mnemonic "friend mnemonic" --lost LOST_ADDR --rescuer RESCUER_ADDR

# Claim a successful recovery
./resonance recovery claim --mnemonic "rescuer mnemonic" --lost-account LOST_ADDRESS
```

### Mining Operations

```bash
# Start mining
./resonance mining start --mnemonic "your mnemonic"

# Check mining status
./resonance mining status

# Stop mining
./resonance mining stop
```

## Configuration

The CLI uses the Quantus SDK configuration. By default it connects to:
- **Local Development**: `ws://localhost:9944`
- **Network**: Configure in quantus_sdk for different networks

## Development

This CLI is part of the Quantus workspace managed by Melos:

```bash
# Run all workspace commands from root
cd ..

# Get dependencies for all packages
melos get

# Analyze all code
melos analyze

# Format all code
melos format

# Run tests
melos test

# Generate polkadart bindings
melos generate

# Full setup
melos setup
```

### Adding New Commands

1. Create a new command class in `lib/commands/`
2. Follow the pattern of existing commands
3. Add the command to `bin/main.dart`
4. Update this README

### Command Structure

```dart
class MyCommand {
  ArgParser get argParser { /* ... */ }
  Future<void> run(ArgResults command) async { /* ... */ }
}
```

## Dependencies

All package versions are managed centrally through the workspace `melos.yaml`:

- **polkadart**: ^0.6.1 (Substrate blockchain interaction)
- **quantus_sdk**: Local package (shared services)
- **args**: ^2.4.2 (CLI argument parsing)
- **mason_logger**: ^0.2.11 (Logging)

## Security Notes

⚠️ **Important Security Considerations:**

1. **Mnemonic Storage**: Never store mnemonics in plaintext files
2. **Network Security**: Ensure secure connection to blockchain nodes
3. **Key Management**: Use hardware wallets for significant funds
4. **Recovery Setup**: Choose trusted friends for account recovery

## Architecture

The CLI uses the shared Quantus SDK services:
- `SubstrateService`: Blockchain connection and transaction submission
- `ReversibleTransfersService`: Theft deterrence functionality
- `RecoveryService`: Account recovery operations

This ensures no code duplication and consistent behavior across mobile app, miner app, and CLI.

## Contributing

1. Follow the workspace coding standards
2. Run `melos analyze` before committing
3. Add tests for new functionality
4. Update documentation

## License

[Add your license here] 