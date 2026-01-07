// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IStablecoinExchange} from "tempo-std/interfaces/IStablecoinExchange.sol";
import {ITIP20} from "tempo-std/interfaces/ITIP20.sol";

contract StablecoinExchangeReproTest is Test {
    IStablecoinExchange public exchange = IStablecoinExchange(0xDEc0000000000000000000000000000000000000);
    ITIP20 pathUsd = ITIP20(0x20C0000000000000000000000000000000000000);
    ITIP20 betaUsd = ITIP20(0x20C0000000000000000000000000000000000002);

    uint256 expectedPathUsdExchangeBalance = 0;
    
    function testPlaceBidWithRounding() external {
        vm.startPrank(0xBfaA9CEFb6c7d4537EceE5d036341BF4FACbf20e);
        betaUsd.approve(address(exchange), 10000000000000);
        pathUsd.approve(address(exchange), 10000000000000);
        
        uint256 initialExchangeBalance = pathUsd.balanceOf(address(exchange));
        exchange.place(address(betaUsd), 9900000011, true, 10);
        assertEq(initialExchangeBalance + 9900000011, pathUsd.balanceOf(address(exchange)), "pathUSD exchange balance different than expected");
    }

}
