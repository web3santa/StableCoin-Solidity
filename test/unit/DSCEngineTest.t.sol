// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployStableCoin} from "../../script/DeployStableCoin.s.sol";
import {DSCEngin} from "../../src/DSCEngine.sol";

contract DSCEngineTest is Test {
    DeployStableCoin deployer;
    DecentralizedStableCoin dsc;
    DSCEngin dscEngine;

    function setUp() public {
        deployer = new DeployStableCoin();
        (dsc, dscEngine) = deployer.run();
    }
}
