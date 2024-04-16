// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployStableCoin} from "../script/DeployStableCoin.s.sol";

contract TestStableCoin is Test {
    DecentralizedStableCoin public stableCoin;
    DeployStableCoin public deployer;

    address alice = makeAddr("alice");
    uint256 constant INITIAL_VALUE = 1 ether;

    function setUp() public {
        deployer = new DeployStableCoin();
        stableCoin = deployer.run(alice);

        vm.deal(alice, INITIAL_VALUE);
    }

    function testMint() public {
        uint256 mintAmount = 5 ether;
        vm.prank(alice);
        stableCoin.mint(alice, mintAmount);

        console.log(stableCoin.balanceOf(alice));

        assertEq(stableCoin.balanceOf(alice), 5 ether);
    }

    function testBurn() public {
        uint256 mintAmount = 5 ether;
        vm.prank(alice);
        stableCoin.mint(alice, mintAmount);
        console.log(stableCoin.balanceOf(alice));

        // do burn
        vm.prank(alice);
        uint256 burnAmount = 2 ether;
        stableCoin.burn(burnAmount);
        console.log(stableCoin.balanceOf(alice));

        assertEq(stableCoin.balanceOf(alice), mintAmount - burnAmount);
    }
}
