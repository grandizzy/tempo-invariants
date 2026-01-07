// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IStablecoinExchange} from "tempo-std/interfaces/IStablecoinExchange.sol";
import {ITIP20} from "tempo-std/interfaces/ITIP20.sol";

contract StablecoinExchangeTest is Test {
    IStablecoinExchange public exchange = IStablecoinExchange(0xDEc0000000000000000000000000000000000000);
    ITIP20 pathUsd = ITIP20(0x20C0000000000000000000000000000000000000);
    ITIP20 betaUsd = ITIP20(0x20C0000000000000000000000000000000000002);

    uint256 expectedPathUsdExchangeBalance = 0;

    function setUp() public {
        targetContract(address(this));

        expectedPathUsdExchangeBalance = pathUsd.balanceOf(address(exchange));
    }

    function placeBid(address actor, uint128 amount, int16 tick, bool cancel) external {
        tick = int16(bound(tick, 10, 10));
        amount = uint128(bound(amount, 100000000, 10000000000));

        vm.startPrank(0xBfaA9CEFb6c7d4537EceE5d036341BF4FACbf20e);
        betaUsd.approve(address(exchange), 10000000000000);
        pathUsd.approve(address(exchange), 10000000000000);
        uint128 orderId = exchange.place(address(betaUsd), amount, true, tick);

        expectedPathUsdExchangeBalance += amount;

        // TODO: assert balance reduced from user, shows up in exchange

        if (cancel) {
            exchange.cancel(orderId);
            // TODO: assert balance reduced from exchange, shows up for user

            expectedPathUsdExchangeBalance -= amount;
        }
        vm.stopPrank();
    }

    function invariant_stablecoin_exchange() public {
        uint256 exchangeBalance = pathUsd.balanceOf(address(exchange));

        console.log(exchangeBalance);
        console.log(expectedPathUsdExchangeBalance);

        assertEq(exchangeBalance, expectedPathUsdExchangeBalance, "pathUSD exchange balance different than expected");
    }
}
