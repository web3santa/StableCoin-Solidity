// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployStableCoin} from "../../script/DeployStableCoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployStableCoin public deployer;
    DecentralizedStableCoin public dsc;
    DSCEngine public dsce;
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
        (dsc, dsce, config) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,, deployerAddress) = config.activeNetworkConfig();
        vm.deal(user, 100 ether);

        ERC20Mock(weth).mint(user, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_ERC20_BALANCE);
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositeCollateralAndGetAccountInfos() public depositedCollateral {
        vm.startPrank(user);

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getUserAccountInfo(user);
        console.log(totalDscMinted);
        console.log(collateralValueInUsd);

        uint256 expectedTotalDscMinted = 0;

        // 10 ether * 3000 = 30,000 USD
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        vm.stopPrank();

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    // deposit test
    function testCanDepositCollateralAndgetUserCollerterralAmount() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(dsce), 2 ether);
        dsce.depositCollateral(weth, 2 ether);

        uint256 depositAmount = dsce.getUserCollerterralAmount(user, weth);

        console.log(depositAmount);
        vm.stopPrank();

        assertEq(depositAmount, 2 ether);
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock GOD = new ERC20Mock("GOD", "GOD", user, 88 ether);
        uint256 depositAmount = 10 ether;
        vm.startPrank(user);
        uint256 godBalance = GOD.balanceOf(user);
        console.log(godBalance);

        GOD.approve(address(dsce), depositAmount);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(GOD), depositAmount);
        godBalance = GOD.balanceOf(user);
        console.log(godBalance);
        vm.stopPrank();
    }

    function testRevertsWithDepositMorethanZero() public {
        uint256 zeroAmount = 0 ether;
        vm.expectRevert(DSCEngine.DSCEngine__MorethanZero.selector);
        dsce.depositCollateral(weth, zeroAmount);
    }

    // constructor test
    address[] public tokenAddress;
    address[] public priceFeedAddress;

    function testRevertIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddress.push(weth);
        priceFeedAddress.push(wethUsdPriceFeed);
        priceFeedAddress.push(wbtcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__PriceFeedMustMatchLenthTokenAddress.selector);
        new DSCEngine(tokenAddress, priceFeedAddress, address(dsc));
    }

    // price test
    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 60 ether; // 60 usd
        // $3000 / eth $100
        uint256 expectedWeth = 0.02 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        console.log(actualWeth);

        assertEq(actualWeth, expectedWeth);
    }

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15e18 * 3000/ETHH = 45000e18
        uint256 expectedUsd = 45000e18;
        vm.prank(deployerAddress);
        uint256 ethUSDValue = dsce.getUsdValue(weth, ethAmount);
        console.log(ethUSDValue);

        uint256 btcAmount = 12e18;
        // 12e18 * 40000/BTC = 480000e18
        uint256 expectedBtcAmount = 480000e18;
        vm.prank(deployerAddress);
        uint256 btcUsdValue = dsce.getUsdValue(wbtc, btcAmount);
        console.log(btcUsdValue);
        assertEq(ethUSDValue, expectedUsd);
        assertEq(btcUsdValue, expectedBtcAmount);
    }

    // deposit collateralt test
    function testRevertIfCollateralZero() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MorethanZero.selector);
        dsce.depositCollateral(weth, 0);
        uint256 balance = ERC20Mock(weth).balanceOf(user);
        console.log(balance);
        vm.stopPrank();
    }

    function testMint() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        dsce.depositCollateral(weth, 5 ether);
        uint256 wethBalance = ERC20Mock(weth).balanceOf(user);
        console.log(wethBalance);

        dsce.mintDsc(3 ether);
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

        ERC20Mock(wbtc).approve(address(dsce), 1 ether);
        dsce.depositCollateral(wbtc, 1 ether);

        wbtcBalance = ERC20Mock(wbtc).balanceOf(user);
        console.log(wbtcBalance);

        uint256 wbtcColleteralAmount = dsce.getUserCollerterralAmount(user, wbtc);
        console.log(wbtcColleteralAmount);

        assertEq(wbtcColleteralAmount, 1 ether);

        vm.stopPrank();
    }
}
