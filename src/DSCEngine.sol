// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author Web3Santa
 * @notice The sysyem is designed to be as minimal as possible and have the tokens maintain a 1 token == $1 peg.
 * This stablecoin has the properties
 * Dolla Pegged
 * Alogoritmicall Stable
 *
 * It is Simila to DAI if DAI had no gonverance , no fees, and was only baked by WETH and WBTC.
 * This contract is the core of the DSC system
 *  DSC system should always be ovvercollateralized at no point should the value of all collateral
 *
 */
contract DSCEngin is ReentrancyGuard {
    error DSCEngine__MorethanZero();
    error DSCEngine__PriceFeedMustMatchLenthTokenAddress();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__MintFail();
    error DSCEngine__BreakHealthFactor(uint256 healthFactor);

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    // eth / usd decimal 8
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200 % overcollateralied
    uint256 private constant LIQUIDATION_PRECISION = 100; // 200 % overcollateralied
    uint256 private constant MIN_HEALTH_FACTOR = 1; // 200 % overcollateralied
    // state variable

    mapping(address token => address priceFeed) private s_priceFeeds; // tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscToMint) private s_DSCMinted;

    address[] private s_collateralToken;

    DecentralizedStableCoin private immutable i_dsc;

    // events
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MorethanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }

        _;
    }

    constructor(address[] memory tokenAddress, address[] memory priceFeedAddress, address dscAddress) {
        // USD Proce Feed
        if (tokenAddress.length != priceFeedAddress.length) {
            revert DSCEngine__PriceFeedMustMatchLenthTokenAddress();
        }

        // for example ETH/ usd BTC / usd mkr / usd
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_priceFeeds[tokenAddress[i]] = priceFeedAddress[i];
            s_collateralToken.push(tokenAddress[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    function depositCollateralAndMintDsc() external {}

    /**
     * @notice follows CEI pattern
     * @param tokenCollateralAddress this address token deplosit collateral
     * @param amountCollateral the amount of calleral to deposit
     * nonReentrant is importtant to protect security
     *
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    // fows CEI
    // 1. check if the collateral value > dsc amount price feeds, values
    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if they mint too much ($150 dsc, $ 100 ETH) need to do revert
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFail();
        }
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollaterlValue(user);
    }

    // return how close to liquidation a user is
    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted

        // total collateral value

        (uint256 totalDscMinted, uint256 collaterlValueInUsd) = _getAccountInformation(user);

        uint256 collateralAdjustedForThreshold = (collaterlValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        // $ 150 eth / 100 dsc = 1.5

        // 1000 ETH * 50 = 50,000 / 100 = 500
        // 150 * 50 = 7500 / 100 = 75 / 100 < 1

        // $1000 eth / 100 dsc
        // 1000 * 50 = 50000 / 100 = (500 / 100) > 1

        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted; // (150 / 100)
    }

    // private & internal function
    function _revertIfHealthFactorIsBroken(address user) internal view {
        // check health factor (do they have enough collateral?)
        // revert if they dont
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreakHealthFactor(userHealthFactor);
        }
    }

    // public & externvl view function

    function getAccountCollaterlValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through each callateal token, get the amount they have deposited
        for (uint256 i = 0; i < s_collateralToken.length; i++) {
            address token = s_collateralToken[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }

        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (
            /* uint80 roundID */
            ,
            int256 price,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();

        // 1eth = $ 3000
        // the returns  1e8
        return ((uint256(price) * amount * ADDITIONAL_FEED_PRECISION) / PRECISION);
    }
}
