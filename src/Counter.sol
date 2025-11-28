// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AMM {
    uint256 supplyETH;
    uint256 supplyToken;
    uint256 supplyLiquidity;
    uint256 k;

    function addLiquidity() public {
        uint256 alpha = msg.value / supplyETH;
        
        supplyETH =+ (alpha + 1)*supplyETH;
        supplyToken =+ (alpha + 1)*supplyToken;
        supplyLiquidity =+ (alpha + 1)*supplyLiquidity;
    }

    function removeLiquidity(uint256 amount) public {

    }

    function getETHPrice(uint256 amountToSpend) {
        
    }

    function getUNItokenPrice(uint256 amountToSpend) {
        
    }
}
