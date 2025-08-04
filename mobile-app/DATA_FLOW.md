# 📊 Quantus Wallet Data Flow Architecture

This document explains the complete data flow architecture of the Quantus Wallet application, including all providers, services, and their interactions.

## 🏗️ **Core Architecture Overview**

The wallet uses a **reactive, provider-based architecture** built with Riverpod that ensures real-time data synchronization across all components.

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Blockchain    │    │   Local State   │    │   User Interface│
│   (GraphQL)     │◄──►│   (Providers)   │◄──►│   (Widgets)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 💰 **Balance System**

### **Two-Layer Balance Architecture**

```dart
// Layer 1: Raw blockchain balance
balanceProviderRaw → ChainHistoryService → GraphQL API

// Layer 2: Effective balance (what user can spend)
balanceProvider = balanceProviderRaw - pendingOutgoingTransactions
```

**Classes Involved:**
- `balanceProviderFamily`: Fetches balance for specific account ID
- `balanceProviderRaw`: Raw blockchain balance for active account
- `balanceProvider`: Effective spendable balance (accounts for pending)
- `_calculatePendingOutgoing()`: Helper function for pending adjustments

**Data Flow:**
```
User Action → Pending Transaction Added → Effective Balance Recalculated → UI Updates
Blockchain Confirmation → Raw Balance Updates → Effective Balance Recalculated → UI Updates
```

## 📋 **Transaction System**

### **Three-Tier Transaction Architecture**

```dart
allTransactionsProvider = {
  pendingTransactions,     // From pendingTransactionsProvider
  reversibleTransfers,     // From paginationController.reversibleTransfers  
  otherTransfers          // From paginationController.items
}
```

**Classes Involved:**
- `PendingTransactionEvent`: Transactions in progress
- `ReversibleTransferEvent`: Time-locked transfers 
- `TransactionEvent`: Confirmed blockchain transactions
- `CombinedTransactionsList`: Unified data structure
- `PaginationController`: Manages paginated historical data

## 🔄 **Polling Services Architecture**

### **Multi-Service Polling System**

```
HistoryPollingManager (Orchestrator)
├── GlobalHistoryPollingService (60s intervals)
├── TransactionTrackingService (10s for inBlock transactions)
└── ReversibleTransferMonitoringService (5s for timer execution)
```

**Service Responsibilities:**

#### **1. GlobalHistoryPollingService**
- **Purpose**: Background sync every 60 seconds
- **Triggers**: `silentRefresh()` on history and balance
- **Lifecycle**: Managed by app foreground/background state

#### **2. TransactionTrackingService** 
- **Purpose**: Track pending transactions entering `inBlock` state
- **Method**: Polls every 10 seconds until transaction appears in history
- **Action**: Updates pending state and triggers silent refresh

#### **3. ReversibleTransferMonitoringService**
- **Purpose**: Monitor reversible transfers approaching execution
- **Strategy**: 30-second buffer detection + 5-second aggressive polling
- **Method**: Hash-based queries for efficient detection
- **Action**: Inline status updates (no full refresh needed)

## 📡 **Data Sources & Services**

### **Blockchain Data Services**

```dart
ChainHistoryService {
  // Core data fetching
  fetchAllTransactionTypes() → SortedTransactionsList
  fetchScheduledTransfers() → List<ReversibleTransferEvent>
  fetchTransactionsByTransactionHash() → List<TransactionEvent>
  
  // Balance queries  
  SubstrateService.queryBalance() → BigInt
}
```

### **State Management Services**

```dart
PendingTransactionsProvider {
  add(transaction)     // Add new pending transaction
  remove(id)          // Remove completed/failed transaction  
  updateState(id, state) // Update transaction status
}

PaginationController {
  loadingRefresh()    // Manual refresh with loading indicators
  silentRefresh()     // Background refresh without loading
  fetchMore()         // Load next page of transactions
  updateReversibleTransferToExecuted() // Inline status update
}
```

## 🔄 **Complete Data Flow Examples**

### **Scenario 1: User Sends Transaction**

```
1. User initiates send
   └── TransactionSubmissionService.submitTransaction()

2. Transaction added to pending
   └── pendingTransactionsProvider.add(transaction)

3. Effective balance recalculates  
   └── balanceProvider = rawBalance - pendingOutgoing
   
4. UI updates instantly
   └── Balance drops, pending transaction appears

5. Transaction tracking starts
   └── TransactionTrackingService monitors inBlock state

6. Transaction confirms
   └── Found in history → Remove from pending → UI updates
```

### **Scenario 2: Reversible Transfer Execution**

```
1. Timer approaches zero
   └── ReversibleTransferMonitoringService starts monitoring

2. Timer hits zero
   └── Aggressive 5-second polling begins

3. Execution detected
   └── Hash-based query finds executed transaction

4. Inline update
   └── updateReversibleTransferToExecuted()
   
5. UI updates instantly
   └── Transfer moves from scheduled to executed list

6. Balance refreshes
   └── balanceProviderFamily.invalidate()
```

### **Scenario 3: App Resume from Background**

```
1. App returns to foreground
   └── AppLifecycleManager detects resumed state

2. Silent refresh triggered
   └── HistoryPollingManager.triggerSilentRefresh()

3. All data updates silently
   ├── Balance: balanceProviderFamily.invalidate()  
   ├── History: paginationController.silentRefresh()
   └── Tracking: Continue pending transaction monitoring

4. UI shows fresh data
   └── No loading indicators, seamless experience
```

### **Scenario 4: Pull-to-Refresh**

```
1. User pulls to refresh
   └── RefreshIndicator.onRefresh()

2. Loading refresh triggered
   ├── balanceProviderRaw.invalidate() (shows spinner)
   └── paginationController.loadingRefresh() (shows spinner)

3. Fresh data loaded
   ├── New balance from blockchain
   ├── Latest transaction history
   └── Updated pending states

4. UI updates with indicators
   └── Both balance and history show loading → fresh data
```

## 🎯 **Key Design Principles**

### **1. Separation of Concerns**
- **Raw Data**: Pure blockchain state (`balanceProviderRaw`, `otherTransfers`)
- **Computed Data**: Business logic applied (`balanceProvider`, `allTransactionsProvider`)
- **UI State**: Loading, error, and display states

### **2. Reactive Updates**
- All providers automatically react to dependency changes
- UI updates happen automatically when data changes
- No manual state synchronization needed

### **3. Efficient Polling**
- **Global**: 60-second background sync
- **Targeted**: 10-second inBlock tracking  
- **Aggressive**: 5-second execution detection
- **Smart**: Hash-based queries for specific transactions

### **4. User Experience Focus**
- **Silent Updates**: Background data refresh without UI disruption
- **Loading Feedback**: Clear indicators for user-initiated actions
- **Instant Feedback**: Immediate balance adjustments for pending transactions
- **Consistent State**: Always synchronized balance and transaction data

## 📁 **File Structure Overview**

```
mobile-app/lib/
├── providers/
│   ├── account_providers.dart          # Active account management
│   ├── wallet_providers.dart           # Balance and raw data providers
│   ├── pending_transactions_provider.dart # Pending transaction state
│   └── all_transactions_provider.dart  # Combined transaction data
│
├── services/
│   ├── history_polling_manager.dart    # Orchestrates all polling
│   ├── global_history_polling_service.dart # 60s background sync
│   ├── transaction_tracking_service.dart   # inBlock monitoring
│   ├── reversible_transfer_monitoring_service.dart # Execution detection
│   └── transaction_submission_service.dart # Send transactions
│
└── features/main/screens/
    ├── wallet_main.dart                # Main dashboard
    ├── transactions_screen.dart        # Full transaction history
    └── send/                           # Send transaction flows
```

## 🔧 **Debugging & Monitoring**

### **Console Logging**
- All services log their operations for debugging
- Transaction state changes are logged with IDs
- Polling cycles show timing and results

### **Provider Dependencies**
- Use Riverpod Inspector in development to visualize provider graph
- Watch for circular dependencies between providers
- Monitor provider rebuild frequency for performance

### **Performance Monitoring**
- Track polling frequency and adjust intervals as needed
- Monitor GraphQL query efficiency 
- Watch for memory leaks in subscription management

---

This architecture provides **enterprise-grade reliability** with **excellent user experience** through its reactive, efficient, and well-organized data flow system.