// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployStableCoin} from "../../script/DeployStableCoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    error DSCEngine__BreakHealthFactor(uint256 healthFactor);

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

    modifier depositedCollateralAndMintDsc() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 1500 ether);
        vm.stopPrank();
        _;
    }

    function testRedeedDo() public depositedCollateralAndMintDsc {
        vm.startPrank(user);
        uint256 dscBal = dsc.balanceOf(user);
        console.log(dscBal);
        uint256 wethBal = ERC20Mock(weth).balanceOf(user);
        console.log(wethBal);
        dsc.approve(address(dsce), 1500 ether);
        dsce.redeemCollateralForDsc(address(weth), AMOUNT_COLLATERAL, 1500 ether);
        dscBal = dsc.balanceOf(user);
        console.log(dscBal);
        wethBal = ERC20Mock(weth).balanceOf(user);
        console.log(wethBal);

        vm.stopPrank();
        assertEq(wethBal, 10 ether);
        assertEq(dscBal, 0);
    }

    function testcalculateHalthFactor() public depositedCollateralAndMintDsc {
        vm.startPrank(user);
        uint256 tokenUSdValue = dsce.getUsdValue(weth, 10 ether);
        uint256 health = dsce.calculateHalthFactor(20000 ether, tokenUSdValue);
        console.log((health / 1e18) * 100);
        vm.stopPrank();

        // assertEq(health, 5000000000000000000);
    }

    function testgetMIN_HEALTH_FACTOR() public view {
        uint256 precition = dsce.getMIN_HEALTH_FACTOR();
        assertEq(precition, 1e18);
    }

    function testgetLIQUIDATION_BONUS() public view {
        uint256 precition = dsce.getLIQUIDATION_BONUS();
        assertEq(precition, 10);
    }

    function testgetLIQUIDATION_PRECISION() public view {
        uint256 precition = dsce.getLIQUIDATION_PRECISION();
        assertEq(precition, 100);
    }

    function testgetLIQUIDATION_THRESHOLD() public view {
        uint256 precition = dsce.getLIQUIDATION_THRESHOLD();
        assertEq(precition, 50);
    }

    function testgetPRECISION() public view {
        uint256 precition = dsce.getPRECISION();
        assertEq(precition, 1e18);
    }

    function testRedeeomToGetCollateral() public depositedCollateralAndMintDsc {
        vm.startPrank(user);
        uint256 uscBal = dsc.balanceOf(user);
        console.log(uscBal);
        dsc.approve(address(dsce), 1500000000000000000000);
        dsce.burnDsc(1500000000000000000000);

        uint256 callateralWEHAmount = dsce.getUserCollerterralAmount(user, weth);
        console.log(callateralWEHAmount);

        dsce.redeemCollateral(address(weth), callateralWEHAmount);
        callateralWEHAmount = dsce.getUserCollerterralAmount(user, weth);
        console.log(callateralWEHAmount);
        uscBal = dsc.balanceOf(user);
        console.log(uscBal);

        vm.stopPrank();

        assertEq(callateralWEHAmount, 0);
        assertEq(uscBal, 0);
    }

    function testBurnDsc() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 15000 ether);
        uint256 userBal = dsc.balanceOf(user);
        console.log(userBal);
        uint256 burnAmount = 5000 ether;
        dsc.approve(address(dsc), burnAmount);

        vm.expectRevert(DSCEngine.DSCEngine__MorethanZero.selector);
        dsce.burnDsc(0);

        dsc.balanceOf(user);
        console.log(userBal);

        vm.stopPrank();
    }

    function testgetUsdValueWithRevert() public {
        vm.startPrank(user);
        ERC20Mock newToken = new ERC20Mock("new", "new", address(user), 100 ether);
        uint256 bal = ERC20Mock(newToken).balanceOf(user);
        console.log(bal);
        vm.expectRevert();
        dsce.getUsdValue(address(newToken), 10 ether);
        // uint256 expectedETHUsdValue = 10 ether * 3000;
        // console.log(acturalUsdValueETH);
        vm.stopPrank();

        // assertEq(acturalUsdValueETH, expectedETHUsdValue);
    }

    function testgetUsdValue() public {
        vm.startPrank(user);
        uint256 acturalUsdValueETH = dsce.getUsdValue(address(weth), 10 ether);
        uint256 expectedETHUsdValue = 10 ether * 3000;
        console.log(acturalUsdValueETH);
        vm.stopPrank();

        assertEq(acturalUsdValueETH, expectedETHUsdValue);
    }

    function testgetAccountCollaterlValue() public depositedCollateralAndMintDsc {
        vm.startPrank(user);
        uint256 totalCollateralValueInUsd = dsce.getAccountCollaterlValue(user);
        console.log(totalCollateralValueInUsd);
        vm.stopPrank();

        assertEq(totalCollateralValueInUsd, AMOUNT_COLLATERAL * 3000);
    }

    function testLiquidation() public {
        vm.startPrank(user);
        uint256 initialCollateralEth = 1 ether;
        uint256 overMintDsc = 1500 ether;
        ERC20Mock(weth).approve(address(dsce), initialCollateralEth);
        dsce.depositCollateralAndMintDsc(weth, initialCollateralEth, overMintDsc);
        uint256 userHealthFactor = dsce.getHealthFactor(user);
        console.log(userHealthFactor);

        vm.stopPrank();

        // 1071428571428571428
    }

    function testBreakHealthFactor() public {
        vm.startPrank(user);
        uint256 initialCollateralEth = 5 ether;
        uint256 overMintDsc = 15000 ether;
        ERC20Mock(weth).approve(address(dsce), initialCollateralEth);
        vm.expectRevert();

        dsce.depositCollateralAndMintDsc(weth, initialCollateralEth, overMintDsc);
        // uint256 userHealthFactor = dsce.getHealthFactor(user);
        // console.log(userHealthFactor);

        vm.stopPrank();
    }

    function testSmallCollateralAndMintOverDscRevert() public {
        vm.startPrank(user);
        uint256 initialCollateralEth = 10 ether;
        uint256 overMintDsc = 30000 ether;
        ERC20Mock(weth).approve(address(dsce), initialCollateralEth);

        vm.expectRevert();
        dsce.depositCollateralAndMintDsc(weth, initialCollateralEth, overMintDsc);
        uint256 userDscBal = dsc.balanceOf(user);
        console.log(userDscBal);
        // dsce.liquidate(address(weth), user, AMOUNT_COLLATERAL);

        vm.stopPrank();
    }

    function testLiquidateRevertWithHelathFactor() public depositedCollateralAndMintDsc {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOK.selector);
        dsce.liquidate(address(weth), user, 2 ether);
        vm.stopPrank();
    }

    function testLiquidateRevertWithZeroAmount() public depositedCollateralAndMintDsc {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__MorethanZero.selector);
        dsce.liquidate(address(weth), user, 0 ether);
        vm.stopPrank();
    }

    function testCheckHealthFactor() public {
        uint256 callateralAmount = 10 ether;
        uint256 mintDsc = 10 ether;
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), callateralAmount);
        dsce.depositCollateralAndMintDsc(weth, callateralAmount, mintDsc);
        uint256 healthFactor = dsce.getHealthFactor(user);
        console.log(healthFactor);
        vm.stopPrank();

        uint256 expectedHealthFactor = 1500 ether;

        assertEq(healthFactor, expectedHealthFactor);
    }

    function testRedeemCollateralRevertwithOvereAmount() public depositedCollateralAndMintDsc {
        vm.startPrank(user);
        vm.expectRevert();
        dsce.redeemCollateral(address(weth), 11 ether);
        vm.stopPrank();
    }

    function testredeemCollateralRevertWithZeroAmount() public depositedCollateralAndMintDsc {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__MorethanZero.selector);
        dsce.redeemCollateral(address(weth), 0 ether);
        vm.stopPrank();
    }

    function testDepositAndMintDsc() public {
        vm.startPrank(user);
        uint256 dscBalance = dsc.balanceOf(user);
        console.log(dscBalance);

        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_COLLATERAL);
        dscBalance = dsc.balanceOf(user);
        console.log(dscBalance);
        vm.stopPrank();
        uint256 expectedDSCAmount = 10 ether;
        assertEq(dscBalance, expectedDSCAmount);
    }

    function testRedeemCollateral() public depositedCollateral {
        vm.startPrank(user);
        uint256 userBalance = ERC20Mock(weth).balanceOf(user);
        console.log(userBalance);

        uint256 mintAmount = 2 ether;
        dsce.mintDsc(mintAmount);

        dsce.redeemCollateral(address(weth), 2 ether);
        userBalance = ERC20Mock(weth).balanceOf(user);
        console.log(userBalance);
        vm.stopPrank();

        assertEq(userBalance, 2 ether);
    }

    function testMintDSCAndRevert() public depositedCollateral {
        vm.startPrank(user);
        uint256 mintAmount = 0 ether;
        vm.expectRevert(DSCEngine.DSCEngine__MorethanZero.selector);
        dsce.mintDsc(mintAmount);
        uint256 userBalance = ERC20Mock(weth).balanceOf(user);
        console.log(userBalance);

        vm.stopPrank();
    }

    function testMintDSC() public depositedCollateral {
        vm.startPrank(user);
        ERC20Mock(weth).mint(user, 2 ether);
        uint256 userBalance = ERC20Mock(weth).balanceOf(user);

        uint256 mintAmount = 2 ether;
        dsce.mintDsc(mintAmount);
        userBalance = ERC20Mock(weth).balanceOf(user);
        console.log(userBalance);

        vm.stopPrank();
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
