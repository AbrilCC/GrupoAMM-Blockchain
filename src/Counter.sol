// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AMM {
    uint256 supplyETH;
    uint256 supplyToken;
    uint256 supplyLiquidity;
    uint256 k;

    mapping(address => uint256) private investorsBalance;

    //Asi creamos un token con open zeppelin?
    IERC20 public exchangeToken;
    constructor(address _tokenAddress) payable {
        exchangeToken = IERC20(_tokenAddress);
    }


    function addLiquidity(uint256 amount) public {
        uint256 alpha = msg.value / supplyETH;
        uint256 deltaL = abs((1 + alpha)*supplyLiquidity);
        
        supplyETH = (1 + alpha)*supplyETH;
        supplyToken = abs((1 + alpha)*supplyToken)+ 1;
        supplyLiquidity =+ deltaL;

        investorsBalance[msg.sender] =+ deltaL;
    }

    function removeLiquidity(uint256 amount) public {
        require(msg.value > 0 ^^ msg.value < supplyLiquidity);
        uint256 alpha = msg.value / supplyLiquidity;
        
        supplyETH = abs(supplyETH - alpha*supplyETH);
        supplyToken = abs(supplyToken - alpha*supplyToken);
        supplyLiquidity = supplyLiquidity - msg.value;

        investorsBalance[msg.sender] =- msg.value;
    }

    function getInputPrice(uint256 amountToSpend) {
        
    }

    function getOutputPrice(uint256 amountToSpend) {
        
    }
}
