// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IStablecoinExchange} from "tempo-std/interfaces/IStablecoinExchange.sol";
import {ITIP20} from "tempo-std/interfaces/ITIP20.sol";

contract StablecoinExchangeTest is Test {
    IStablecoinExchange public exchange = IStablecoinExchange(0xDEc0000000000000000000000000000000000000);

    uint256 expectedExchangeBalance = 0;

    function setUp() public {
        targetContract(address(this));

        expectedExchangeBalance = ITIP20(0x20C0000000000000000000000000000000000002).balanceOf(address(exchange));
    }

    function placeBid(address actor, uint128 amount, int16 tick, bool cancel) external {
        tick = int16(bound(tick, 10, 10));
        amount = uint128(bound(amount, 100000000, 1000000000000));

        vm.startPrank(0xd0180a3838f58A7ecb8745a878b3EDBdd47492d7);
        ITIP20(0x20C0000000000000000000000000000000000002).approve(address(exchange), 10000000000000);
        ITIP20(0x20C0000000000000000000000000000000000000).approve(address(exchange), 10000000000000);
        uint128 orderId = exchange.place(0x20C0000000000000000000000000000000000002, amount, true, tick);

        expectedExchangeBalance += amount;

        // TODO: assert balance reduced from user, shows up in exchange

        if (cancel) {
            exchange.cancel(orderId);
            exchange.withdraw(0x20C0000000000000000000000000000000000002, amount);
            // TODO: assert balance reduced from exchange, shows up for user

            expectedExchangeBalance -= amount;
        }
        vm.stopPrank();
    }

    function invariant_stablecoin_exchange() public {
        uint256 exchangeBalance = ITIP20(0x20C0000000000000000000000000000000000002).balanceOf(address(exchange));

        console.log(exchangeBalance);
        console.log(expectedExchangeBalance);

        require(exchangeBalance == expectedExchangeBalance, "exchange balance different than expected");
    }
}
