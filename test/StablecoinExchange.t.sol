// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {IStablecoinExchange} from "tempo-std/interfaces/IStablecoinExchange.sol";
import {ITIP20} from "tempo-std/interfaces/ITIP20.sol";

contract StablecoinExchangeTest is Test {
    IStablecoinExchange public exchange = IStablecoinExchange(0xDEc0000000000000000000000000000000000000);
    ITIP20 pathUsd = ITIP20(0x20C0000000000000000000000000000000000000);
    ITIP20 betaUsd = ITIP20(0x20C0000000000000000000000000000000000002);

    address[] private _actors;
    mapping(address => uint128[]) private _placedOrders;
    int16[10] private _ticks = [int16(10), 20, 30, 40, 50, 60, 70, 80, 90, 100];
    uint128 private _nextOrderId;

    uint256 expectedPathUsdExchangeBalance = 0;

    function setUp() public {
        targetContract(address(this));

        _actors = _buildActors(10);
        expectedPathUsdExchangeBalance = pathUsd.balanceOf(address(exchange));
        _nextOrderId = exchange.nextOrderId();
    }

    function placeOrder(uint256 actorRnd, uint128 amount, uint256 tickRnd, bool isBid, bool cancel) external {
        int16 tick = _ticks[tickRnd % _ticks.length];
        address actor = _actors[actorRnd % _actors.length];
        console2.log("tick", tick);
        console2.log("actor", actor);
        amount = uint128(bound(amount, 100000000, 10000000000));

        vm.startPrank(actor);
        uint128 orderId = exchange.place(address(betaUsd), amount, isBid, tick);
        _assertNextOrderId(orderId);

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
        } else {
            _placedOrders[actor].push(orderId);
        }

        vm.stopPrank();
    }

    function placeFlipOrder(uint256 actorRnd, uint128 amount, uint256 tickRnd) external {
        int16 tick = _ticks[tickRnd % _ticks.length];
        address actor = _actors[actorRnd % _actors.length];
        amount = uint128(bound(amount, 100000000, 10000000000));

        vm.startPrank(actor);
        uint128 orderId = exchange.placeFlip(address(betaUsd), amount, true, tick, 200);
        vm.writeLine("exchange.log", string.concat("flip order: ", vm.toString(orderId)));
        _assertNextOrderId(orderId);
        _placedOrders[actor].push(orderId);

        vm.stopPrank();
    }

    function swapExactAmountIn(uint256 providerRnd, uint256 swapperRnd, uint128 amount) external {
        address provider = _actors[providerRnd % _actors.length];
        address swapper = _actors[swapperRnd % _actors.length];
        amount = uint128(bound(amount, 100000000, 10000000000));

        vm.startPrank(provider);
        uint128 orderId = exchange.place(address(betaUsd), amount, true, 10);
        // Next order id invariant
        _assertNextOrderId(orderId);
        _placedOrders[provider].push(orderId);
        vm.stopPrank();

        vm.startPrank(swapper);
        uint128 amountOut = exchange.swapExactAmountIn(address(betaUsd), address(pathUsd), 100000000, 10);
        // Read next order id - if a flip order is hit then next order id is incremented.
        _nextOrderId = exchange.nextOrderId();
        assertGt(amountOut, 0, "swap exact amount in cannot be 0");
        vm.stopPrank();
    }

    function afterInvariant() public {
        for (uint256 i = 0; i < _actors.length; i++) {
            address actor = _actors[i];
            vm.startPrank(actor);
            for (uint256 orderId = 0; orderId < _placedOrders[actor].length; orderId++) {
                exchange.cancel(_placedOrders[actor][orderId]);
            }
            vm.stopPrank();
        }
    }

    function invariantStablecoinExchange() public view {
        uint256 exchangePathUsdBalance = pathUsd.balanceOf(address(exchange));
        // TODO: assert path usd and beta usd balances for exchange and for each actor
        //assertEq(exchangePathUsdBalance, expectedPathUsdExchangeBalance, "pathUSD exchange balance different than expected");

        uint256 exchangeBetaUsdBalance = betaUsd.balanceOf(address(exchange));
    }

    function _assertNextOrderId(uint128 orderId) internal {
        // Next order id invariant
        assertEq(orderId, _nextOrderId, "next order id mismatch");
        _nextOrderId += 1;
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
            vm.stopPrank();
        }

        return actorsAddress;
    }
}
