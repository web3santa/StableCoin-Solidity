// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployStableCoin} from "../../script/DeployStableCoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Handler is Test {
    DeployStableCoin deployer;
    DSCEngine dsce;
    HelperConfig config;
    DecentralizedStableCoin dsc;
    address public deployerAddress;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max; // max uint96 value

    constructor(DSCEngine _dsceEngine, DecentralizedStableCoin _dsc) {
        dsce = _dsceEngine;
        dsc = _dsc;

        address[] memory collateralToken = dsce.getCollateralToken();
        weth = ERC20Mock(collateralToken[0]);
        wbtc = ERC20Mock(collateralToken[1]);
    }

    function mintDsc(uint256 amount) public {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getUserAccountInfo(msg.sender);
        int256 maxDscTomint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);

        if (maxDscTomint < 0) {
            return;
        }

        amount = bound(amount, 0, uint256(maxDscTomint));
        if (amount == 0) {
            return;
        }

        dsce.mintDsc(amount);
    }

    // redeem collateral <-
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        collateral.mint(address(this), amountCollateral);
        collateral.approve(address(dsce), amountCollateral);

        dsce.depositCollateral(address(collateral), amountCollateral);
    }

    function redeemCollateral(uint256 collsteralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collsteralSeed);
        uint256 maxCollateralToRedeem = dsce.getUserCollerterralAmount(msg.sender, address(collateral));

        // there is a bug, wehre a user can redeem more than they have
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);

        if (amountCollateral == 0) {
            return;
        }
        dsce.redeemCollateral(address(collateral), amountCollateral);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
