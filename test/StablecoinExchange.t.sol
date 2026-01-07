// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IStablecoinExchange} from "tempo-std/interfaces/IStablecoinExchange.sol";
import {ITIP20} from "tempo-std/interfaces/ITIP20.sol";

contract StablecoinExchangeTest is Test {
    IStablecoinExchange public exchange = IStablecoinExchange(0xDEc0000000000000000000000000000000000000);
    ITIP20 pathUsd = ITIP20(0x20C0000000000000000000000000000000000000);
    ITIP20 betaUsd = ITIP20(0x20C0000000000000000000000000000000000002);

    address[] public actors;
    int16[10] private ticks = [int16(10), 20, 30, 40, 50, 60, 70, 80, 90, 100];

    uint256 expectedPathUsdExchangeBalance = 0;

    function setUp() public {
        targetContract(address(this));

        actors = _buildActors(10);
        expectedPathUsdExchangeBalance = pathUsd.balanceOf(address(exchange));
    }

    function placeOrder(uint256 actorRnd, uint128 amount, uint256 tickRnd, bool isBid, bool cancel) external {
        int16 tick = ticks[tickRnd % ticks.length];
        address actor = actors[actorRnd % actors.length];
        console.log(tick);
        console.log(actor);
        amount = uint128(bound(amount, 100000000, 10000000000));

        vm.startPrank(actor);
        uint128 orderId = exchange.place(address(betaUsd), amount, isBid, tick);

        uint32 price = exchange.tickToPrice(tick);
        uint256 expectedEscrow = (uint256(amount) * uint256(price)) / uint256(exchange.PRICE_SCALE());
        expectedPathUsdExchangeBalance += expectedEscrow;

        if (cancel) {
            exchange.cancel(orderId);
            if (isBid) {
                exchange.withdraw(address(pathUsd), uint128(expectedEscrow));
                expectedPathUsdExchangeBalance -= expectedEscrow;
            } else {
                exchange.withdraw(address(betaUsd), amount);
            }
        }
        vm.stopPrank();
    }

    function invariant_stablecoin_exchange() public view {
        uint256 exchangePathUsdBalance = pathUsd.balanceOf(address(exchange));
        // TODO: assert path usd and beta usd balances for exchange and for each actor
        //assertEq(exchangePathUsdBalance, expectedPathUsdExchangeBalance, "pathUSD exchange balance different than expected");

        uint256 exchangeBetaUsdBalance = betaUsd.balanceOf(address(exchange));
    }

    function _buildActors(uint256 noOfActors_) internal returns (address[] memory) {
        address[] memory actorsAddress = new address[](noOfActors_);

        for (uint256 i = 0; i < noOfActors_; i++) {
            address actor = makeAddr(string(abi.encodePacked("Actor", vm.toString(i))));
            actorsAddress[i] = actor;

            vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
            pathUsd.mint(actor, 10000000000000);
            betaUsd.mint(actor, 10000000000000);
            vm.stopPrank();

            vm.startPrank(actor);
            betaUsd.approve(address(exchange), 10000000000000);
            pathUsd.approve(address(exchange), 10000000000000);
        }

        return actorsAddress;
    }
}
