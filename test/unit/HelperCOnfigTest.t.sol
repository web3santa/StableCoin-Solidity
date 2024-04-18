// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployStableCoin} from "../../script/DeployStableCoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract TestHelperConfig is Test {
    DeployStableCoin public deployer;
    DecentralizedStableCoin public dsc;
    DSCEngine public dece;
    HelperConfig public config;
    address public deployerAddress;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;
    address user = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployStableCoin();
        (dsc, dece, config) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,, deployerAddress) = config.activeNetworkConfig();
        vm.deal(user, 100 ether);

        ERC20Mock(weth).mint(user, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_ERC20_BALANCE);
    }

    function testDECIMAL() public {
        vm.prank(user);
        uint256 deci = config.DECIMAL();
        console.log(deci);

        assertEq(deci, 8);
    }

    function testETH_USD_PRICE() public {
        vm.prank(user);
        int256 ethPrice = config.ETH_USD_PRICE();

        assertEq(ethPrice, 3000e8);
    }
}
