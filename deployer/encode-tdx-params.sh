#!/bin/bash

usage() {
    echo "Usage: $0 [--hex|--base64] --svn <value> --mrseam <value> --mrtd <value> [--pcr1 <value>] [--pcr2 <value>] ... [--pcr24 <value>]" >&2
    echo "" >&2
    echo "Input format:" >&2
    echo "  --hex     Input values are in hexadecimal format (default)" >&2
    echo "  --base64  Input values are in base64 format" >&2
    echo "" >&2
    echo "Required parameters:" >&2
    echo "  --svn     TEE TCB SVN (16 bytes)" >&2
    echo "  --mrseam  MR SEAM value (48 bytes)" >&2
    echo "  --mrtd    MR TD value (48 bytes)" >&2
    echo "" >&2
    echo "Optional parameters:" >&2
    echo "  --pcr1 to --pcr24  PCR values (32 bytes each)" >&2
    echo "" >&2
    echo "Output: ABI-encoded TrustedParams struct as hex" >&2
    exit 1
}

SVN=""
MRSEAM=""
MRTD=""
declare -A PCRS
PCR_BITMAP=0
INPUT_FORMAT="hex"  # Default to hex

# Function to convert base64 to hex
base64_to_hex() {
    echo "$1" | base64 -d | xxd -p | tr -d '\n'
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --hex)
            INPUT_FORMAT="hex"
            shift
            ;;
        --base64)
            INPUT_FORMAT="base64"
            shift
            ;;
        --svn)
            SVN="$2"
            shift 2
            ;;
        --mrseam)
            MRSEAM="$2"
            shift 2
            ;;
        --mrtd)
            MRTD="$2"
            shift 2
            ;;
        --pcr*)
            PCR_NUM="${1#--pcr}"
            if [[ "$PCR_NUM" =~ ^[0-9]+$ ]] && [ "$PCR_NUM" -ge 1 ] && [ "$PCR_NUM" -le 24 ]; then
                PCRS[$PCR_NUM]="$2"
                BIT_POS=$((PCR_NUM - 1))
                PCR_BITMAP=$((PCR_BITMAP | (1 << BIT_POS)))
            else
                echo "Error: Invalid PCR number. Must be between 1 and 24." >&2
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "Error: Unknown parameter $1" >&2
            usage
            ;;
    esac
done

if [ -z "$SVN" ] || [ -z "$MRSEAM" ] || [ -z "$MRTD" ]; then
    echo "Error: Missing required parameters" >&2
    usage
fi

# Convert base64 to hex if needed
if [ "$INPUT_FORMAT" = "base64" ]; then
    SVN=$(base64_to_hex "$SVN")
    MRSEAM=$(base64_to_hex "$MRSEAM")
    MRTD=$(base64_to_hex "$MRTD")
    
    # Convert PCR values
    for key in "${!PCRS[@]}"; do
        PCRS[$key]=$(base64_to_hex "${PCRS[$key]}")
    done
fi

# Clean up hex inputs (remove 0x prefix if present)
SVN="${SVN#0x}"
MRSEAM="${MRSEAM#0x}"
MRTD="${MRTD#0x}"

if [ ${#SVN} -ne 32 ]; then
    echo "Error: SVN must be 16 bytes (32 hex characters). Got ${#SVN} characters." >&2
    echo "Input format: $INPUT_FORMAT" >&2
    exit 1
fi

if [ ${#MRSEAM} -ne 96 ]; then
    echo "Error: MRSEAM must be 48 bytes (96 hex characters). Got ${#MRSEAM} characters." >&2
    echo "Input format: $INPUT_FORMAT" >&2
    exit 1
fi

if [ ${#MRTD} -ne 96 ]; then
    echo "Error: MRTD must be 48 bytes (96 hex characters). Got ${#MRTD} characters." >&2
    echo "Input format: $INPUT_FORMAT" >&2
    exit 1
fi

for key in "${!PCRS[@]}"; do
    PCRS[$key]="${PCRS[$key]#0x}"
    if [ ${#PCRS[$key]} -ne 64 ]; then
        echo "Error: PCR$key must be 32 bytes (64 hex characters). Got ${#PCRS[$key]} characters." >&2
        echo "Input format: $INPUT_FORMAT" >&2
        exit 1
    fi
done

BITMAP_HEX=$(printf "%06x" $PCR_BITMAP)

PCR_ARRAY=""
PCR_COUNT=0
for i in {1..24}; do
    if [ -n "${PCRS[$i]}" ]; then
        PCR_ARRAY="${PCR_ARRAY}${PCRS[$i]}"
        ((PCR_COUNT++))
    fi
done

# Build the PCR array format for cast
if [ $PCR_COUNT -eq 0 ]; then
    PCR_ARRAY_ARG="[]"
else
    # Build array of bytes32 values
    PCR_ARRAY_ARG="["
    FIRST=true
    for i in {1..24}; do
        if [ -n "${PCRS[$i]}" ]; then
            if [ "$FIRST" = false ]; then
                PCR_ARRAY_ARG="${PCR_ARRAY_ARG},"
            fi
            PCR_ARRAY_ARG="${PCR_ARRAY_ARG}0x${PCRS[$i]}"
            FIRST=false
        fi
    done
    PCR_ARRAY_ARG="${PCR_ARRAY_ARG}]"
fi

ENCODED=$(cast abi-encode "f((bytes16,uint24,bytes,bytes,bytes32[]))" \
    "(0x${SVN},${PCR_BITMAP},0x${MRSEAM},0x${MRTD},${PCR_ARRAY_ARG})")

# Output summary to stderr
echo "TDX Trusted Params Summary:" >&2
echo "  SVN: 0x${SVN}" >&2
echo "  PCR Bitmap: 0x${BITMAP_HEX} (decimal: ${PCR_BITMAP})" >&2
echo "  MRSEAM: 0x${MRSEAM}" >&2
echo "  MRTD: 0x${MRTD}" >&2
if [ $PCR_COUNT -gt 0 ]; then
    echo "  PCRs included:" >&2
    for i in {1..24}; do
        if [ -n "${PCRS[$i]}" ]; then
            echo "    PCR$i: 0x${PCRS[$i]}" >&2
        fi
    done
else
    echo "  No PCRs included" >&2
fi

# Output encoded result to stdout
echo "$ENCODED"
