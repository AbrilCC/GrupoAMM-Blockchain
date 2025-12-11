// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/AMM.sol";

/// @title Mock USD Token para testing
contract USD is ERC20 {
    constructor() ERC20("USD Stablecoin", "USD") {
        _mint(msg.sender, 1_000_000 * 1e18); // 1M USD
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AMMTest is Test {
    AMM public amm;
    USD public usd;

    address owner = makeAddr("owner");
    address trader = makeAddr("trader");

    // Precio inicial: 3000 USD por ETH
    uint256 constant INITIAL_ETH = 10 ether;
    uint256 constant INITIAL_USD = 30_000 * 1e18; // 3000 USD/ETH * 10 ETH

    function setUp() public {
        // Dar ETH al owner
        vm.deal(owner, 100 ether);

        // Owner despliega el token y el AMM
        vm.startPrank(owner);

        usd = new USD();
        amm = new AMM(address(usd));

        // Owner aprueba y provee liquidez inicial
        usd.approve(address(amm), INITIAL_USD);
        amm.addLiquidity{value: INITIAL_ETH}(INITIAL_USD);

        vm.stopPrank();

        // Preparar al trader con fondos
        vm.deal(trader, 100 ether);
        usd.mint(trader, 100_000 * 1e18);

        vm.prank(trader); // prank solo personifica la siguiente linea de codigo
        usd.approve(address(amm), type(uint256).max);

        _logReserves("Setup completado");
    }

    // =========================================================================
    // TEST: ETH -> USD Swap
    // =========================================================================

    function test_SwapEthToToken() public {
        console.log("\n=== SWAP: ETH -> USD ===\n");

        uint256 ethToSwap = 1 ether;

        // Estado previo
        uint256 traderUsdBefore = usd.balanceOf(trader);
        (uint256 ethReserveBefore, uint256 usdReserveBefore) = amm.getReserves();
        uint256 priceBefore = (usdReserveBefore * 1e18) / ethReserveBefore;

        console.log("Trader vende: %s ETH (en base units)", ethToSwap);
        console.log("Trader vende: %s ETH", ethToSwap / 1e18);
        console.log("Precio antes: %s USD/ETH (en base units)", priceBefore);
        console.log("Precio antes: %s USD/ETH", priceBefore / 1e18);

        // Ejecutar swap
        vm.prank(trader);
        uint256 usdReceived = amm.ethToTokenSwap{value: ethToSwap}(0);

        // Estado posterior
        (uint256 ethReserveAfter, uint256 usdReserveAfter) = amm.getReserves();
        uint256 priceAfter = (usdReserveAfter * 1e18) / ethReserveAfter;
        uint256 effectivePrice = (usdReceived * 1e18) / ethToSwap;

        console.log("USD recibidos: %s (en base units)", usdReceived);
        console.log("USD recibidos: %s", usdReceived / 1e18);
        console.log("Precio efectivo: %s USD/ETH (en base units)", effectivePrice);
        console.log("Precio efectivo: %s USD/ETH", effectivePrice / 1e18);
        console.log("Precio despues: %s USD/ETH (en base units)", priceAfter);
        console.log("Precio despues: %s USD/ETH", priceAfter / 1e18);

        // Verificaciones basicas
        assertGt(usdReceived, 0, "Deberia recibir USD");
        assertEq(usd.balanceOf(trader), traderUsdBefore + usdReceived);
        assertLt(priceAfter, priceBefore, "Precio USD/ETH deberia bajar");

        _logReserves("Post-swap ETH->USD");
    }

    // =========================================================================
    // TEST: USD -> ETH Swap
    // =========================================================================

    function test_SwapTokenToEth() public {
        console.log("\n=== SWAP: USD -> ETH ===\n");

        uint256 usdToSwap = 3000 * 1e18;

        // Estado previo
        uint256 traderEthBefore = trader.balance;
        (uint256 ethReserveBefore, uint256 usdReserveBefore) = amm.getReserves();
        uint256 priceBefore = (usdReserveBefore * 1e18) / ethReserveBefore;

        console.log("Trader vende: %s USD (en base units)", usdToSwap);
        console.log("Trader vende: %s USD", usdToSwap / 1e18);
        console.log("Precio antes: %s USD/ETH (en base units)", priceBefore);
        console.log("Precio antes: %s USD/ETH", priceBefore / 1e18);

        // Ejecutar swap
        vm.prank(trader);
        uint256 ethReceived = amm.tokenToEthSwap(usdToSwap, 0);

        // Estado posterior
        (uint256 ethReserveAfter, uint256 usdReserveAfter) = amm.getReserves();
        uint256 priceAfter = (usdReserveAfter * 1e18) / ethReserveAfter;
        uint256 effectivePrice = (usdToSwap * 1e18) / ethReceived;

        console.log("ETH recibidos: %s (en base units)", ethReceived);
        console.log("ETH recibidos: %s mETH", ethReceived / 1e15);
        console.log("Precio efectivo: %s USD/ETH (en base units)", effectivePrice);
        console.log("Precio efectivo: %s USD/ETH", effectivePrice / 1e18);
        console.log("Precio despues: %s USD/ETH (en base units)", priceAfter);
        console.log("Precio despues: %s USD/ETH", priceAfter / 1e18);

        // Verificaciones basicas
        assertGt(ethReceived, 0, "Deberia recibir ETH");
        assertEq(trader.balance, traderEthBefore + ethReceived);
        assertGt(priceAfter, priceBefore, "Precio USD/ETH deberia subir");

        _logReserves("Post-swap USD->ETH");
    }

    // =========================================================================
    // TEST: Roundtrip - El precio vuelve al inicial
    // =========================================================================

    function test_RoundtripPriceReturns() public {
        console.log("\n=== ROUNDTRIP: ETH -> USD -> ETH ===\n");

        uint256 ethToSwap = 1 ether;

        // Estado inicial
        (uint256 ethReserveInitial, uint256 usdReserveInitial) = amm.getReserves();
        uint256 priceInitial = (usdReserveInitial * 1e18) / ethReserveInitial;
        uint256 traderEthInitial = trader.balance;

        console.log("=== ESTADO INICIAL ===");
        console.log("Precio inicial: %s USD/ETH (en base units)", priceInitial);
        console.log("Precio inicial: %s USD/ETH", priceInitial / 1e18);
        _logReserves("Inicial");

        // --- SWAP 1: ETH -> USD ---
        console.log("=== SWAP 1: Vendemos 1 ETH ===");
        vm.prank(trader);
        uint256 usdReceived = amm.ethToTokenSwap{value: ethToSwap}(0);

        (uint256 ethReserveAfter1, uint256 usdReserveAfter1) = amm.getReserves();
        uint256 priceAfter1 = (usdReserveAfter1 * 1e18) / ethReserveAfter1;

        console.log("USD recibidos: %s (en base units)", usdReceived);
        console.log("USD recibidos: %s", usdReceived / 1e18);
        console.log("Precio despues del swap 1: %s USD/ETH (en base units)", priceAfter1);
        console.log("Precio despues del swap 1: %s USD/ETH", priceAfter1 / 1e18);
        _logReserves("Despues de Swap 1");

        // --- SWAP 2: USD -> ETH (devolvemos los USD que recibimos) ---
        console.log("=== SWAP 2: Vendemos los USD que recibimos ===");
        vm.prank(trader);
        uint256 ethReceived = amm.tokenToEthSwap(usdReceived, 0);

        (uint256 ethReserveFinal, uint256 usdReserveFinal) = amm.getReserves();
        uint256 priceFinal = (usdReserveFinal * 1e18) / ethReserveFinal;

        console.log("ETH recibidos: %s (en base units)", ethReceived);
        console.log("ETH recibidos: %s mETH", ethReceived / 1e15);
        console.log("Precio final: %s USD/ETH (en base units)", priceFinal);
        console.log("Precio final: %s USD/ETH", priceFinal / 1e18);
        _logReserves("Final");

        // --- COMPARACION ---
        console.log("=== COMPARACION ===");
        console.log("Precio inicial: %s USD/ETH", priceInitial / 1e18);
        console.log("Precio final:   %s USD/ETH", priceFinal / 1e18);

        uint256 ethLost = ethToSwap - ethReceived;
        console.log("ETH perdido por slippage: %s (en base units)", ethLost);
        console.log("ETH perdido por slippage: %s mETH", ethLost / 1e15);

        // El precio vuelve aproximadamente al inicial
        // (no es exacto debido al slippage en ambas direcciones)
        assertApproxEqRel(priceFinal, priceInitial, 0.01e18, "Precio deberia volver aprox al inicial");
        
        // El trader pierde ETH en el roundtrip (costo del slippage)
        assertLt(ethReceived, ethToSwap, "Trader deberia perder ETH por slippage");
        assertLt(trader.balance, traderEthInitial, "Balance final menor que inicial");

        // NOTA SOBRE REDONDEOS:
        // Los redondeos en un AMM siempre deben ser a favor del pool (en contra del usuario).
        // - Cuando el usuario RECIBE tokens: floor() -> recibe menos
        // - Cuando el usuario PAGA tokens: ceil() -> paga mas
        // Esto previene ataques donde alguien hace muchos swaps pequenos para "robar"
        // fracciones de wei del pool aprovechando redondeos a su favor.
        // En este test, el trader pierde ~1 wei por los redondeos, que se queda en el pool.
    }

    // =========================================================================
    // HELPERS
    // =========================================================================

    function _logReserves(string memory label) internal view {
        (uint256 ethRes, uint256 usdRes) = amm.getReserves();
        uint256 k = ethRes * usdRes;
        console.log("\n--- %s ---", label);
        console.log("Reserva ETH: %s (en base units)", ethRes);
        console.log("Reserva ETH: %s", ethRes / 1e18);
        console.log("Reserva USD: %s (en base units)", usdRes);
        console.log("Reserva USD: %s", usdRes / 1e18);
        console.log("k (x*y): %s (en base units)", k);
        console.log("k (x*y): %s", k / 1e36);
        console.log("");
    }
}
