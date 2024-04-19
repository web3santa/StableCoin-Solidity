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
contract DSCEngine is ReentrancyGuard {
    error DSCEngine__MorethanZero();
    error DSCEngine__PriceFeedMustMatchLenthTokenAddress();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__MintFail();
    error DSCEngine__BreakHealthFactor(uint256 healthFactor);
    error DSCEngine__HealthFactorOK();
    error DSCEngine__HealthFactorNotImproved();

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    // eth / usd decimal 8
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200 % overcollateralied
    uint256 private constant LIQUIDATION_PRECISION = 100; //
    uint256 private constant LIQUIDATION_BONUS = 10;
    //  this mean a 10 % bonus
    uint256 private constant MIN_HEALTH_FACTOR = 1e18; // 200 % overcollateralied
    // state variable

    mapping(address token => address priceFeed) private s_priceFeeds; // tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscToMint) private s_DSCMinted;

    address[] private s_collateralToken;

    DecentralizedStableCoin private immutable i_dsc;

    // events
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemFrom, address indexed redeemTo, address indexed token, uint256 amount
    );

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

    // main function
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @notice follows CEI pattern
     * @param tokenCollateralAddress this address token deplosit collateral
     * @param amountCollateral the amount of calleral to deposit
     * nonReentrant is importtant to protect security
     *
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
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

    /**
     *
     * @param tokenCollateralAddress THe Collateral address to redeem
     * @param amountCollateral The amount of collateral to redeem
     * @param amountDscToBurn The amount of DSC to burn
     * this function burnd DSC and redeems underying collateral in one transaction
     */
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);

        // redeemCOllateral already check health factor
    }

    // in order to redeem collateral;
    // 1. health factor must be over 1 after collateral pulled
    /// dry dont repeat yourself
    // cei check effect interaction
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        // 100 - 1000 (revert)
        _redeemCollatteral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // fows CEI
    // 1. check if the collateral value > dsc amount price feeds, values
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if they mint too much ($150 dsc, $ 100 ETH) need to do revert
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFail();
        }
    }

    // do we need to check if this break health factor?
    function burnDsc(uint256 amount) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // i dont this this would ever hit..
    }

    // $100 ETH bacing $50 DSC
    // $20 ETH back $50 DSC <- dis int worth $1
    // if someone is almost undercollateralized, we will pay yu to liquidate them!
    /**
     *
     * @param collateral this address is collateral address
     * @param user  this user who ha broken the health factor. their healthfactor should be below min_health_factor
     * @param debtToCover th amount of des you want to burn to improve the users health factor
     * 200 % overcollateralizd
     *
     * follows CEI check effects interactions
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // need to check health factor

        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOK();
        }

        // we want to burn thir DSC "debt"
        // adn take their collateral
        // BAD user: $140 ETH, $100 DSC.
        // debToCover $100
        /// 0.05 ETH
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // and give them a 10$ bonus
        // we are ging the liquidator $110 of WETH for 100 DSC
        // we should implement ad feature to liquidate in the event the protocal is insolvent
        // and sweep extra amounts into a treasury

        // 0.05 ETH * .1 = 0.005 ETH for bonus so. getting 0.055
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollatteral(user, msg.sender, collateral, totalCollateralToRedeem);

        // we need to burn
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUsrHealthFactor = _healthFactor(user);
        if (endingUsrHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

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

        return _calculateHealthFactor(totalDscMinted, collaterlValueInUsd);
    }

    function calculateHalthFactor(uint256 totalDscMinted, uint256 collaterlValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collaterlValueInUsd);
    }

    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collaterlValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalDscMinted == 0) return type(uint256).max;

        uint256 collateralAdjustedForThreshold = (collaterlValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return (collateralAdjustedForThreshold * 1e18) / totalDscMinted;
    }

    /**
     * Low-level internal fuctnion, do not call unless the function calling it is
     * checking for health factors being broken
     */
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        // this conditional is hypothtically unrealchale
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
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

    function _redeemCollatteral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
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

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        // price of ETH (token)
        // $ETH
        // $2000 / ETH. $1000 = 0.5 ETH
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        // ($1000e18 * 1e18) / ($2000 * 1e10) =
        // 5000000000000000000 / 30000000000000 = 166666
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getUserCollerterralAmount(address user, address token) public view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getUserAccountInfo(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);

        return (totalDscMinted, collateralValueInUsd);
    }

    function getPRECISION() public pure returns (uint256) {
        return PRECISION;
    }

    function getLIQUIDATION_THRESHOLD() public pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLIQUIDATION_PRECISION() public pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getLIQUIDATION_BONUS() public pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getMIN_HEALTH_FACTOR() public pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getCollateralToken() public view returns (address[] memory) {
        return s_collateralToken;
    }
}
