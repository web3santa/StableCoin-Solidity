// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployStableCoin} from "../../script/DeployStableCoin.s.sol";
import {DSCEngin} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployStableCoin public deployer;
    DecentralizedStableCoin public dsc;
    DSCEngin public dece;
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

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15e18 * 3000/ETHH = 45000e18
        uint256 expectedUsd = 45000e18;
        vm.prank(deployerAddress);
        uint256 ethUSDValue = dece.getUsdValue(weth, ethAmount);
        console.log(ethUSDValue);

        uint256 btcAmount = 12e18;
        // 12e18 * 40000/BTC = 480000e18
        uint256 expectedBtcAmount = 480000e18;
        vm.prank(deployerAddress);
        uint256 btcUsdValue = dece.getUsdValue(wbtc, btcAmount);
        console.log(btcUsdValue);
        assertEq(ethUSDValue, expectedUsd);
        assertEq(btcUsdValue, expectedBtcAmount);
    }

    // deposit collateralt test
    function testRevertIfCollateralZero() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(dece), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngin.DSCEngine__MorethanZero.selector);
        dece.depositCollateral(weth, 0);
        uint256 balance = ERC20Mock(weth).balanceOf(user);
        console.log(balance);
        vm.stopPrank();
    }

    function testMint() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dece), AMOUNT_COLLATERAL);

        dece.depositCollateral(weth, 5 ether);
        uint256 wethBalance = ERC20Mock(weth).balanceOf(user);
        console.log(wethBalance);

        dece.mintDsc(3 ether);
        uint256 dscBal = dsc.balanceOf(user);
        console.log(dscBal);

        vm.stopPrank();
        assertEq(dscBal, 3 ether);
        assertEq(wethBalance, 5 ether);
    }

    function testGetUserCollerterraBTCAmount() public {
        vm.startPrank(user);
        uint256 wbtcBalance = ERC20Mock(wbtc).balanceOf(user);
        console.log(wbtcBalance);

        ERC20Mock(wbtc).approve(address(dece), 1 ether);
        dece.depositCollateral(wbtc, 1 ether);

        wbtcBalance = ERC20Mock(wbtc).balanceOf(user);
        console.log(wbtcBalance);

        uint256 wbtcColleteralAmount = dece.getUserCollerterralAmount(user, wbtc);
        console.log(wbtcColleteralAmount);

        assertEq(wbtcColleteralAmount, 1 ether);

        vm.stopPrank();
    }
}
