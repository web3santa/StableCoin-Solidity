// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployStableCoin is Script {
    // HelperConfig public helperConfig;

    function run(address deployer) external returns (DecentralizedStableCoin) {
        vm.startBroadcast();
        DecentralizedStableCoin stableCoin = new DecentralizedStableCoin(
            deployer
        );

        vm.stopBroadcast();

        return stableCoin;
    }
}
