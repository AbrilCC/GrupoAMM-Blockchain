// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Simple Uniswap V1-style constant-product AMM
/// @notice Trades one ERC20 token against ETH using x * y = k (constant product formula).
///         This contract is also the LP token (inherits ERC20).

contract AMM is ERC20 {
    IERC20 public exchangeToken;

    uint256 public reserveEth;
    uint256 public reserveToken;

    constructor(address _tokenAddress) ERC20("AMM LPToken", "AMMLP") {
        exchangeToken = IERC20(_tokenAddress);
    }

    // ------------------------------------------------------------------------
    // FUNCIÓN VIEW: devolver reservas actuales (e, t).
    // ------------------------------------------------------------------------
    function getReserves() external view returns (uint256 ethReserve, uint256 tokenReserve) {
        ethReserve = reserveEth;
        tokenReserve = reserveToken;
    }

    // ------------------------------------------------------------------------
    // addLiquidity
    //
    // Relación con el paper:
    // - Sección 2.1 (Minting Liquidity).
    // - addLiquidityspec: (e, t, l) -> (e', t', l') con
    //     e' = (1 + α)e
    //     t' = (1 + α)t
    //     l' = (1 + α)l
    //     α = Δe / e
    //   preservando la razón e:t:l y aumentando k = e·t.
    //
    // - addLiquiditycode: versión entera donde t' y l' se aproximan
    //   con divisiones enteras y +1 para t.
    //
    // En este contrato:
    // - Para el PRIMER LP: definimos l' = e' (LP inicial = ETH depositado).
    //   El primer LP fija el precio inicial t/e.
    // - Para LPs posteriores:
    //   * el usuario deposita Δe = msg.value
    //   * exigimos Δt ≈ Δe · t / e (misma razón que el pool)
    //   * minteamos Δl = Δe / e · l (versión entera: (Δe * l) / e)
    //
    // Esto implementa la idea de “escalar” (e, t, l) por (1 + α).
    // ------------------------------------------------------------------------
    function addLiquidity(uint256 maxTokens) external payable returns (uint256 liquidityMinted, uint256 tokenAmount) {
        require(msg.value > 0, "se requiere ETH");
        require(maxTokens > 0, "se requieren tokens");

        // ------------------------------------------------------------
        // Caso 1: el pool ya tiene liquidez (l > 0 en el paper).
        // Usamos la versión entera de addLiquiditycode:
        //
        //   e' = e + Δe
        //   t' = t + floor(Δe·t / e) + 1
        //   l' = l + floor(Δe·l / e)
        //
        // Implementamos la misma idea:
        //   requiredTokens = Δe · t / e + 1
        //   liquidityMinted = Δe · l / e
        // ------------------------------------------------------------
        if (totalSupply() > 0) {
            uint256 e = reserveEth;
            uint256 t = reserveToken;

            // Tokens que se deben depositar para mantener la misma razón e:t.
            tokenAmount = (msg.value * t) / e + 1; // floor(Δe·t / e) + 1
            require(tokenAmount <= maxTokens, "tokens insuficientes");

            // Liquidez minteada proporcional a Δe/e (versión entera).
            liquidityMinted = (msg.value * totalSupply()) / e; // no nos importa el redondeo para abajo en la liquidez
            require(liquidityMinted > 0, "LP minteado = 0");

            // Actualizamos el estado (e', t', l').
            reserveEth = e + msg.value;
            reserveToken = t + tokenAmount;

            _mint(msg.sender, liquidityMinted);

            exchangeToken.transferFrom(msg.sender, address(this), tokenAmount);
        }
        // ------------------------------------------------------------
        // Caso 2: primer proveedor de liquidez (l = 0 en el paper).
        //
        // El paper no detalla el caso de inicialización; solo modela
        // el sistema cuando ya existe (e, t, l) con e,t,l > 0.
        //
        // Aquí elegimos una convención simple:
        //   - l0 = e0  (LP inicial = ETH depositado)
        //   - token_amount = maxTokens (el usuario define el precio t/e)
        //
        // A partir de aquí, las reglas de addLiquiditycode / removeLiquiditycode
        // preservan las proporciones para todos los LPs.
        // ------------------------------------------------------------
        else {
            tokenAmount = maxTokens;

            liquidityMinted = msg.value; // l0 = e0
            require(liquidityMinted > 0, "LP inicial = 0");

            reserveEth = msg.value;
            reserveToken = tokenAmount;

            // Minteamos los LP tokens al usuario
            _mint(msg.sender, liquidityMinted);

            require(exchangeToken.transferFrom(msg.sender, address(this), tokenAmount), "transferFrom fallida");
        }

        return (liquidityMinted, tokenAmount);
    }

    // ------------------------------------------------------------------------
    // removeLiquidity
    //
    // Relación con el paper:
    // - Sección 2.2 (Burning Liquidity).
    // - removeLiquidityspec: (e, t, l) -> (e0, t0, l0) con
    //     e0 = (1 - α)e
    //     t0 = (1 - α)t
    //     l0 = (1 - α)l
    //     α = Δl / l
    //
    // El usuario quema Δl y recibe:
    //   Δe = e - e0 = αe
    //   Δt = t - t0 = αt
    //
    // En enteros, removeLiquiditycode:
    //   e00 = e - floor(Δl · e / l)
    //   t00 = t - floor(Δl · t / l)
    //   l00 = l - Δl
    //
    // Aquí implementamos la versión entera:
    //   ethOut   = e · Δl / l
    //   tokenOut = t · Δl / l
    // ------------------------------------------------------------------------
    function removeLiquidity(uint256 liquidity) external returns (uint256 ethOut, uint256 tokenOut) {
        require(liquidity > 0, "LP = 0");

        uint256 _totalSupply = totalSupply();
        require(_totalSupply > 0, "no hay liquidez");

        uint256 e = reserveEth;
        uint256 t = reserveToken;

        // Proporción α = Δl / l, pero aplicada con divisiones enteras.
        ethOut = (e * liquidity) / _totalSupply;
        tokenOut = (t * liquidity) / _totalSupply;
        require(ethOut > 0 && tokenOut > 0, "salida ~ 0");

        _burn(msg.sender, liquidity);

        reserveEth = e - ethOut;
        reserveToken = t - tokenOut;

        payable(msg.sender).transfer(ethOut);
        require(exchangeToken.transfer(msg.sender, tokenOut), "transfer fallida");
    }

    // ------------------------------------------------------------------------
    // Swaps sin comisión (modelo x·y = k exacto).
    //
    // Relación con el paper:
    // - Sección “Trading”: el estado es (x, y) y se preserva x·y = k (sin fee).
    //   Dado Δx (input), calculamos Δy usando:
    //     Δy = (Δx · y) / (x + Δx)
    // ------------------------------------------------------------------------

    /// @notice Intercambia ETH por tokens (entrada exacta de ETH).
    /// @param minTokensOut Protección de slippage.
    function ethToTokenSwap(uint256 minTokensOut) external payable returns (uint256 dy) {
        require(msg.value > 0, "ETH = 0");

        dy = _getInputPrice(msg.value, reserveEth, reserveToken);
        require(dy >= minTokensOut, "slippage");

        // Nuevo estado: e' = e + Δe, t' = t - Δt.
        reserveEth += msg.value;
        reserveToken -= dy;

        exchangeToken.transfer(msg.sender, dy);
    }

    /// @notice Intercambia tokens por ETH (entrada exacta de tokens).
    /// @param tokensSold Cantidad de tokens que vende el usuario.
    /// @param minEthOut Protección de slippage.
    function tokenToEthSwap(uint256 tokensSold, uint256 minEthOut) external returns (uint256 ethBought) {
        require(tokensSold > 0, "tokens = 0");

        // Precio usando las reservas anteriores a actualizar:
        //   Δy (aquí ETH) = (Δx · e) / (t + Δx)
        ethBought = _getInputPrice(tokensSold, reserveToken, reserveEth);
        require(ethBought >= minEthOut, "slippage");

        // Nuevo estado: t' = t + Δx, e' = e - Δy.
        reserveToken += tokensSold;
        reserveEth -= ethBought;

        exchangeToken.transferFrom(msg.sender, address(this), tokensSold);
        payable(msg.sender).transfer(ethBought);
    }

    // ------------------------------------------------------------------------
    // Función de precio de entrada (swaps): modelo x·y = k sin fee.
    //
    // En el paper, sin comisión, el output Δy viene dado por:
    //   x·y = (x + Δx)·(y - Δy)
    //   ⇒ Δy = (Δx · y) / (x + Δx)
    //
    // Aquí:
    //   inputAmount = Δx
    //   inputReserve = x
    //   outputReserve = y
    // ------------------------------------------------------------------------
    function _getInputPrice(uint256 dx, uint256 x, uint256 y) internal pure returns (uint256 dy) {
        require(dx > 0, "inputAmount = 0");
        require(x > 0 && y > 0, "no hay liquidez");
        dy = (dx * y) / (x + dx);
    }

    receive() external payable {
        // Evitamos que entren ETH "huérfanos" sin lógica de swap/liquidez
        revert("Usa swap o addLiquidity");
    }
}
