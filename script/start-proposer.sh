#!/bin/sh

set -eou pipefail

if [ "$ENABLE_PROPOSER" = "true" ]; then
    ARGS="--verbosity 4
        --l1.ws ${L1_ENDPOINT_WS}
        --l2.http http://l2-nethermind-execution-client:${L2_HTTP_PORT}
        --l2.auth http://l2-nethermind-execution-client:${L2_ENGINE_API_PORT}
        --taikoInbox ${TAIKO_INBOX}
        --taikoAnchor ${TAIKO_ANCHOR}
        --jwtSecret /tmp/jwt/jwtsecret
        --l1.proposerPrivKey ${L1_PROPOSER_PRIVATE_KEY}
        --l2.suggestedFeeRecipient ${L2_SUGGESTED_FEE_RECIPIENT}
        --inbox ${L1_SIGNAL_SERVICE}
        --bridge ${L1_BRIDGE}
        --taikoWrapper ${TAIKO_WRAPPER}
        --forcedInclusionStore ${FORCED_INCLUSION_STORE}
        --metrics true
        --metrics.port 6061"

    if [ -z "$L1_ENDPOINT_WS" ]; then
        echo "Error: L1_ENDPOINT_WS must be non-empty"
        exit 1
    fi

    if [ -z "$L1_PROPOSER_PRIVATE_KEY" ]; then
        echo "Error: L1_PROPOSER_PRIVATE_KEY must be non-empty"
        exit 1
    fi

    if [ -n "$CHECK_PROFITABILITY" ]; then
        ARGS="${ARGS} --checkProfitability=${CHECK_PROFITABILITY}"
    fi

    if [ -n "$ALLOW_EMPTY_BLOCKS" ]; then
        ARGS="${ARGS} --allowEmptyBlocks=${ALLOW_EMPTY_BLOCKS}"
    fi

    if [ -n "$SURGE_PROPOSER_WRAPPER" ]; then
        ARGS="${ARGS} --surgeProposerWrapper ${SURGE_PROPOSER_WRAPPER}"
    fi

    if [ -n "$EPOCH_INTERVAL" ]; then
        ARGS="${ARGS} --epoch.interval ${EPOCH_INTERVAL}"
    fi

    if [ -n "$EPOCH_MIN_TIP" ]; then
        ARGS="${ARGS} --epoch.minTip ${EPOCH_MIN_TIP}"
    fi

    if [ -n "$EPOCH_MIN_PROPOSING_INTERVAL" ]; then
        ARGS="${ARGS} --epoch.minProposingInterval ${EPOCH_MIN_PROPOSING_INTERVAL}"
    fi

    if [ -n "$EPOCH_ALLOW_ZERO_TIP_INTERVAL" ]; then
        ARGS="${ARGS} --epoch.allowZeroTipInterval ${EPOCH_ALLOW_ZERO_TIP_INTERVAL}"
    fi

    if [ -n "$TX_POOL_MAX_TX_LISTS_PER_EPOCH" ]; then
        ARGS="${ARGS} --txPool.maxTxListsPerEpoch ${TX_POOL_MAX_TX_LISTS_PER_EPOCH}"
    fi

    if [ -n "$PROVER_SET" ]; then
        ARGS="${ARGS} --proverSet ${PROVER_SET}"
    fi

    if [ -n "$TXPOOL_LOCALS" ]; then
        ARGS="${ARGS} --txPool.localsOnly"
        ARGS="${ARGS} --txPool.locals ${TXPOOL_LOCALS}"
    fi

    if [ "$L1_BLOB_ALLOWED" == "true" ]; then
        ARGS="${ARGS} --l1.blobAllowed"
    fi

    if [ "$L1_FALLBACK_TO_CALLDATA" == "true" ]; then
        ARGS="${ARGS} --l1.fallbackToCalldata"
    fi

    if [ "$L1_REVERT_PROTECTION" == "true" ]; then
        ARGS="${ARGS} --l1.revertProtection"
    fi

    # TXMGR Settings
    if [ -n "$TX_FEE_LIMIT_MULTIPLIER" ]; then
            ARGS="${ARGS} --tx.feeLimitMultiplier ${TX_FEE_LIMIT_MULTIPLIER}"
    fi

    if [ -n "$TX_FEE_LIMIT_THRESHOLD" ]; then
        ARGS="${ARGS} --tx.feeLimitThreshold ${TX_FEE_LIMIT_THRESHOLD}"
    fi

    if [ -n "$TX_GAS_LIMIT" ]; then
        ARGS="${ARGS} --tx.gasLimit ${TX_GAS_LIMIT}"
    fi

    if [ -n "$TX_MIN_BASE_FEE" ]; then
        ARGS="${ARGS} --tx.minBaseFee ${TX_MIN_BASE_FEE}"
    fi

    if [ -n "$TX_MIN_TIP_CAP" ]; then
        ARGS="${ARGS} --tx.minTipCap ${TX_MIN_TIP_CAP}"
    fi

    if [ -n "$TX_NOT_IN_MEMPOOL_TIMEOUT" ]; then
        ARGS="${ARGS} --tx.notInMempoolTimeout ${TX_NOT_IN_MEMPOOL_TIMEOUT}"
    fi

    if [ -n "$TX_NUM_CONFIRMATIONS" ]; then
        ARGS="${ARGS} --tx.numConfirmations ${TX_NUM_CONFIRMATIONS}"
    fi

    if [ -n "$TX_RECEIPT_QUERY_INTERVAL" ]; then
        ARGS="${ARGS} --tx.receiptQueryInterval ${TX_RECEIPT_QUERY_INTERVAL}"
    fi

    if [ -n "$TX_RESUBMISSION_TIMEOUT" ]; then
        ARGS="${ARGS} --tx.resubmissionTimeout ${TX_RESUBMISSION_TIMEOUT}"
    fi

    if [ -n "$TX_SAFE_ABORT_NONCE_TOO_LOW_COUNT" ]; then
        ARGS="${ARGS} --tx.safeAbortNonceTooLowCount ${TX_SAFE_ABORT_NONCE_TOO_LOW_COUNT}"
    fi

    if [ -n "$TX_SEND_TIMEOUT" ]; then
        ARGS="${ARGS} --tx.sendTimeout ${TX_SEND_TIMEOUT}"
    fi

    echo "Starting Proposer with args: ${ARGS}"
    exec taiko-client proposer ${ARGS}
else
    echo "PROPOSER IS DISABLED"
    sleep infinity
fi
