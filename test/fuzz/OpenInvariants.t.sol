// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {Test, console} from "forge-std/Test.sol";
// import {DeployStableCoin} from "../../script/DeployStableCoin.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {ERC20Mock} from "../mocks/ERC20Mock.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// // Have our invariant aka properties

// // what are our invariants?

// // 1. The total supply of DSC should be less than the total value of collateral

// // 2 Geter view functions should never revert <- evergreen invariant

// contract OpenInvariantsTest is StdInvariant, Test {
//     DeployStableCoin deployer;
//     DSCEngine dsce;
//     HelperConfig config;
//     DecentralizedStableCoin dsc;
//     address public deployerAddress;
//     address wethUsdPriceFeed;
//     address wbtcUsdPriceFeed;
//     address weth;
//     address wbtc;

//     function setUp() external {
//         deployer = new DeployStableCoin();
//         (dsc, dsce, config) = deployer.run();
//         (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,, deployerAddress) = config.activeNetworkConfig();
//         targetContract(address(dsce));
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         uint256 totalSupply = dsc.totalSupply();
//         uint256 totalWethDeplosited = IERC20(weth).balanceOf(address(dsce));
//         uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

//         uint256 wethValue = dsce.getUsdValue(weth, totalWethDeplosited);
//         uint256 wbtcValue = dsce.getUsdValue(wbtc, totalBtcDeposited);

//         console.log("totalSupply", totalSupply);
//         console.log("wethValue", wethValue);
//         console.log("wbtcValue", wbtcValue);

//         assert(wethValue + wbtcValue >= totalSupply);
//     }
// }
