// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract InteractionWithDSCEngin is Script {
    address public weth = 0x8a7d85bbC5153396357Ee30ba0d2b964022B4DC8;
    address public dsce = 0x2a9d306079A48D0d3b25a2C9ec6a82D5302Bf422;
    address public dsc = 0x108B53A7246c1de29bF866c96330C1A1A8433179;

    function run() external {
        despotiCollateralandMintDSC();
    }

    // 0.2814 eth 30 dsc

    // function redeemCollateralAndBurnDSC() public {
    //     vm.startBroadcast();
    //     DecentralizedStableCoin(dsc).approve(dsce, 30 ether);
    //     DSCEngine(dsce).redeemCollateralForDsc(weth, 0.02 ether, 30 ether);
    //     vm.stopBroadcast();
    // }

    // function mintMoreStablaCoin() public {
    //     vm.startBroadcast();
    //     DSCEngine(dsce).mintDsc(2 ether);
    //     vm.stopBroadcast();
    // }

    function despotiCollateralandMintDSC() public {
        vm.startBroadcast();
        ERC20(weth).approve(address(dsce), 0.01 ether);
        DSCEngine(dsce).depositCollateralAndMintDsc(weth, 0.01 ether, 15 ether);
        vm.stopBroadcast();
    }

    // function despotiCollateral() public {
    //     vm.startBroadcast();
    //     ERC20(weth).approve(address(dsce), 0.01 ether);
    //     DSCEngine(dsce).depositCollateral(weth, 0.01 ether);
    //     vm.stopBroadcast();
    // }

    // function convertSadToHappy() public {
    //     vm.startBroadcast();
    //     DSCEngine(0x2a9d306079A48D0d3b25a2C9ec6a82D5302Bf422).flipMood(0);
    //     vm.stopBroadcast();
    // }
}
