// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/AMM.sol";

/// @title USD Token para deploy
contract USD is ERC20 {
    constructor() ERC20("USD Stablecoin", "USD") {
        _mint(msg.sender, 1_000_000 * 1e18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title Script de deploy del AMM y USD token
contract DeployScript is Script {
    function run() external {
        // Usar la primera cuenta de Anvil como deployer
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy USD token
        USD usd = new USD();
        console.log("USD Token deployed at:", address(usd));

        // Deploy AMM
        AMM amm = new AMM(address(usd));
        console.log("AMM deployed at:", address(amm));

        // Proveer liquidez inicial: 10 ETH + 30,000 USD (precio = 3000 USD/ETH)
        uint256 initialEth = 10 ether;
        uint256 initialUsd = 30_000 * 1e18;

        usd.approve(address(amm), initialUsd);
        amm.addLiquidity{value: initialEth}(initialUsd);

        console.log("\n=== LIQUIDEZ INICIAL ===");
        console.log("ETH depositado:", initialEth / 1e18);
        console.log("USD depositado:", initialUsd / 1e18);
        console.log("Precio inicial: 3000 USD/ETH");

        (uint256 ethRes, uint256 usdRes) = amm.getReserves();
        console.log("\n=== RESERVAS ===");
        console.log("Reserva ETH:", ethRes / 1e18);
        console.log("Reserva USD:", usdRes / 1e18);

        vm.stopBroadcast();

        // Guardar direcciones para usar despues
        console.log("\n=== DIRECCIONES PARA COPIAR ===");
        console.log("export USD_ADDRESS=%s", address(usd));
        console.log("export AMM_ADDRESS=%s", address(amm));
    }
}
