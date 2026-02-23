#!/bin/bash

ENDPOINT="https://subsquid.quantus.com/graphql"
LIMIT=20
OFFSET=0

SINGLE_ACCOUNT='["qzmNaLjPU7hcvkjHpGmrVDPD9y12vdAFimCSrP1GkhVFJMaUq"]'
ALL_ACCOUNTS='["qzmNaLjPU7hcvkjHpGmrVDPD9y12vdAFimCSrP1GkhVFJMaUq","qzn5St24cMsjE4JKYdXLBctusWj5zom67dnrW22SweAahLGeG","qznUDF2JJD8XCnVAXSzVUA7TncMEmagfd4UEzGDwFwHszV29E","qzmuHhD8p2dvndwkbjw5htDvaptyis5rEVc7v5BmqR3pfQ7QN","qzpmyBs51FJNbyv9YgtdhrVCiGX2tgY9iaeGZUHKsx57wDWuT","qzqBzwLQAZ4G5eKF8TYGjmHcENm6hbiTLGLPJhMmFquWbG19u","qzq5yUyndQZJeMaNqxDQkBQpf44kRthNSfo9Tv9fBeBuDtbUh","qzjqcZbyemACctJ7rQi2G63v461CzVrDSRu7LVEivXDxHi4dJ"]'

SCHEDULED_QUERY='query ScheduledTransfersByAccounts($accounts: [String!]!, $limit: Int!, $offset: Int!) { events( limit: $limit offset: $offset where: { reversibleTransfer: { AND: [ { status_eq: SCHEDULED }, { OR: [ { from: { id_in: $accounts } }, { to: { id_in: $accounts } } ] } ] } } orderBy: reversibleTransfer_scheduledAt_DESC ) { id reversibleTransfer { id amount timestamp from { id } to { id } txId scheduledAt status block { height hash } extrinsicHash timestamp } } }'

# Original combined query (SLOW)
EVENTS_QUERY='query EventsByAccounts($accounts: [String!]!, $limit: Int!, $offset: Int!) { events( limit: $limit, offset: $offset, where: { OR: [ { AND: [ { extrinsicHash_isNull: false }, { transfer: { OR: [ { from: { id_in: $accounts } }, { to: { id_in: $accounts } } ] } } ] }, { AND: [ { extrinsicHash_isNull: false }, { reversibleTransfer: { AND: [ { status_not_eq: SCHEDULED }, { OR: [ { from: { id_in: $accounts } }, { to: { id_in: $accounts } } ] } ] } } ] }, { minerReward: { miner: { id_in: $accounts } } } ] }, orderBy: timestamp_DESC ) { id transfer { id amount timestamp from { id } to { id } block { height hash } extrinsicHash timestamp fee } reversibleTransfer { id amount timestamp from { id } to { id } txId scheduledAt status block { height hash } extrinsicHash timestamp } minerReward { id reward timestamp miner { id } block { height hash } } extrinsicHash } }'

# Split query 1: Transfers only
TRANSFERS_QUERY='query TransfersByAccounts($accounts: [String!]!, $limit: Int!, $offset: Int!) { events( limit: $limit, offset: $offset, where: { extrinsicHash_isNull: false, transfer: { OR: [ { from: { id_in: $accounts } }, { to: { id_in: $accounts } } ] } }, orderBy: timestamp_DESC ) { id transfer { id amount timestamp from { id } to { id } block { height hash } extrinsicHash timestamp fee } extrinsicHash } }'

# Split query 2: Reversible transfers only (non-scheduled)
REVERSIBLE_QUERY='query ReversibleByAccounts($accounts: [String!]!, $limit: Int!, $offset: Int!) { events( limit: $limit, offset: $offset, where: { extrinsicHash_isNull: false, reversibleTransfer: { AND: [ { status_not_eq: SCHEDULED }, { OR: [ { from: { id_in: $accounts } }, { to: { id_in: $accounts } } ] } ] } }, orderBy: timestamp_DESC ) { id reversibleTransfer { id amount timestamp from { id } to { id } txId scheduledAt status block { height hash } extrinsicHash timestamp } extrinsicHash } }'

# Split query 3: Miner rewards only
REWARDS_QUERY='query RewardsByAccounts($accounts: [String!]!, $limit: Int!, $offset: Int!) { events( limit: $limit, offset: $offset, where: { minerReward: { miner: { id_in: $accounts } } }, orderBy: timestamp_DESC ) { id minerReward { id reward timestamp miner { id } block { height hash } } extrinsicHash } }'

FMT="  DNS: %{time_namelookup}s | Connect: %{time_connect}s | TLS: %{time_appconnect}s | FirstByte: %{time_starttransfer}s | Total: %{time_total}s | Size: %{size_download} bytes | HTTP: %{http_code}\n"

run_query() {
  local label="$1"
  local query="$2"
  local accounts="$3"
  local body='{"query":"'"$query"'","variables":{"accounts":'"$accounts"',"limit":'"$LIMIT"',"offset":'"$OFFSET"'}}'

  echo "$label"
  curl -s -o /dev/null -w "$FMT" -X POST "$ENDPOINT" -H 'Content-Type: application/json' -d "$body"
}

echo "============================================"
echo "Subsquid Debug - $(date)"
echo "============================================"
echo ""

echo "==== ORIGINAL COMBINED QUERY ===="
echo ""
run_query "Combined Events (1 account):" "$EVENTS_QUERY" "$SINGLE_ACCOUNT"
echo ""
run_query "Combined Events (8 accounts):" "$EVENTS_QUERY" "$ALL_ACCOUNTS"
echo ""

echo "==== SPLIT QUERIES (1 account) ===="
echo ""
run_query "Transfers only (1 account):" "$TRANSFERS_QUERY" "$SINGLE_ACCOUNT"
echo ""
run_query "Reversible only (1 account):" "$REVERSIBLE_QUERY" "$SINGLE_ACCOUNT"
echo ""
run_query "Miner rewards only (1 account):" "$REWARDS_QUERY" "$SINGLE_ACCOUNT"
echo ""

echo "==== SPLIT QUERIES (8 accounts) ===="
echo ""
run_query "Transfers only (8 accounts):" "$TRANSFERS_QUERY" "$ALL_ACCOUNTS"
echo ""
run_query "Reversible only (8 accounts):" "$REVERSIBLE_QUERY" "$ALL_ACCOUNTS"
echo ""
run_query "Miner rewards only (8 accounts):" "$REWARDS_QUERY" "$ALL_ACCOUNTS"
echo ""

echo "============================================"
echo "Done"
echo "============================================"
