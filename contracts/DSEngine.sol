// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import "./DecentralizedStablecoin.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// chainlink

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
    @title DSEngine
    @author by
    The tokens are maintained as 1 token == $1 peg
    Its like DAI if DAI had no governance, and was only backed by wETH and wBTC
    - DSC should always be `overcollateralized`. At no point, should the value of
    all collateral <= the $ backed value of all the DSC.
    @notice  DSEngine is the base contract that contains all functions for minting
    ,redeeming, depositing and withdraw.
*/
contract DSEngine is ReentrancyGuard {
    /////////
    /// Errors
    /////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenIsNotAllowed();
    error DSCEngine__TokenIsNotAllowed2();
    error DSCEngine__TokenPriceFeedAndTokenAddressesMustBeSameLength();
    error DSEngine__DepositFailed();
    error DSCEngine_BreaksHealthFactor();
    error DSC_EngineMintFailed();
    error DSCEngine_Transferfailed();
    error DSEngine_TransferFailed();
    error DSCEngine_HealthFactorOK();
    error DSCEngine__HealthFactorNotImproved();
    /////////
    /// modifiers
    /////////
    // add one to check the amounts in all of the functions below
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    // check the collateral type
    modifier isAllowedToken(address token) {
        if (!s_tokenAllowed[token]) {
            revert DSCEngine__TokenIsNotAllowed();
        }
        _;
    }
    // following does the same with a different logic
    // for that token there has to be a priceFeed
    // initialized in the constructor
    modifier isAllowedToken2(address token) {
        if (s_PriceFeeds[token] == address(0)) {
            revert DSCEngine__TokenIsNotAllowed2();
        }
        _;
    }

    /////////
    /// State Variables
    /////////
    uint256 private constant ADDITIONAL_FEED_PRECISION= 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION= 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // 10$ bonus
    /// tokens alloed
    mapping(address => bool) private s_tokenAllowed;

    address[] s_collateralToken;

    // as an alternative above. if the priceFeed exists then thats a valid
    // collateral token
    mapping(address token => address priceFeed) private s_PriceFeeds;
    // stable coin imported
    DecentralizedStablecoin private immutable dsc;

    // mapping for deposit balances
    mapping(address user => mapping(address token => uint256 amount))
        private s_userCollateralDeposit;
    // who minted how much of DSC using the collateral
    mapping(address user => uint256 amount) private s_userDSCMintAmount;

    /////////
    /// Events
    /////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    event CollateralRedeemed(address indexed user, address indexed token, uint256 indexed amount);

    event CollateralRedeemedFrom(address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount);

    /////////
    /// Functions
    /////////

    constructor(
        address[] memory tokenAddress,
        address[] memory priceFeedAddress,
        address dscAddress
    ) {
        // the lengths must be the same for allowed tokens and the priceFeeds
        if (tokenAddress.length != priceFeedAddress.length) {
            revert DSCEngine__TokenPriceFeedAndTokenAddressesMustBeSameLength();
        }
        // set the tokens allowed as collateral and priceFeeds
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_PriceFeeds[tokenAddress[i]] = priceFeedAddress[i];
            s_collateralToken.push(tokenAddress[i]);
        }
        dsc = DecentralizedStablecoin(dscAddress);
    }

    /////////
    /// EXTERNAL FUNCTIONS
    /////////
    /**
     *
     * @param tokenCollateral the address of the collateral
     * @param amountCollateral the collateral amount
     * @param amountToMintDSC  amount to mint stablecoin
     * @notice this function will deposit collateral and mint stablecoin in one transaction
     */
    function depositCollateralAndMintDSC(address tokenCollateral, uint256 amountCollateral, uint256 amountToMintDSC) external {
        depositCollateral(tokenCollateral, amountCollateral);
        mintDSC(amountToMintDSC);
    }

    /**
    @notice follows CEI Checks -> Effects -> Interactions
    @param tokenCollateralAddress the address of the token to deposit as collateral
    @param amountCollateral amount of collateral to deposit
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        public
        moreThanZero(amountCollateral)
        isAllowedToken2(tokenCollateralAddress)
        nonReentrant
    {
        s_userCollateralDeposit[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;

        // we should always emit an event when we update the state
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if(!success){
            revert DSEngine__DepositFailed();
        }
    }

    // // in order to get the collateral back
    // // health factor must be over 1 after collateral withdrawn
    // function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) public moreThanZero(amountCollateral) nonReentrant{
    //     s_userCollateralDeposit[msg.sender][tokenCollateralAddress] -= amountCollateral;
    //     emit CollateralRedeemed(msg.sender, tokenCollateralAddress, amountCollateral);
    //     // to make it gas fee efficient  we do the transfer first and then check health factor
    //     // if its not okay we will revert anyway.
    //     bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
    //     if(!success){
    //         revert DSCEngine_Transferfailed();
    //     }
    // // check health factor
    //     _revertIfHealthFactorIsBroken(msg.sender);
    // }

     // in order to get the collateral back
    // health factor must be over 1 after collateral withdrawn
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) public moreThanZero(amountCollateral) nonReentrant{

       _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender,msg.sender);
    // check health factor
        _revertIfHealthFactorIsBroken(msg.sender);
    }

// in a real life scenario lets say I had $100 ETH and minted 20 DSC
// now I want 100 back, what should I do? if I get 100 back, that ruins my Health Factor
// I have to burn those DSC first.
// combine this to handle it in one transaction

/**
 *
 * @param tokenCollateralAddress tokencolateral address to redeem
 * @param amountCollateral amount of collateral to redeem
 * @param amountDSCtoBurn amount of DSC to burn
 */
    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDSCtoBurn) public {
        burnDSC(amountDSCtoBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }


    // 1 check if the collateral value > DSC amount. priceFeed and check values are needed
    // $200 ETH -> 20DSC?
    /**
     * @notice follows CEI (checks, effects and interactions)
     * @param amountDSCToMint amount of DSC to mint
     * @notice the depositer must have more collateral than the minimum threshold
     */
    function mintDSC(uint256 amountDSCToMint) public moreThanZero(amountDSCToMint) nonReentrant(){
        // we need to keep track of who minted how much
        s_userDSCMintAmount[msg.sender] += amountDSCToMint;
        // if they minted too much ($150  and 100 ETH)???
        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = dsc.mint(msg.sender, amountDSCToMint);

        if(!minted){
            revert DSC_EngineMintFailed();
        }

    }

    function burnDSC(uint256 amount) public moreThanZero(amount) {

        _burnDSC(amount, msg.sender, msg.sender);
        // when we burn debt the health factor cant get worse but lets check
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // lets say we have $100 ETH and minted $50 DSC
    // what happens when the ETH price drops too much? like $40 collateral
    // then you dont want to end up in that position
    // you liquidate people to not lose, you kick out them from the system.
    // to save the protocol

    // if health factor becomes dangerous we need someone to call burn and redeem
    // we call the liquitate if the price of the collateral tanks
    // if someone is almost undercollateralized we will pay you to liquidate them
    // this is a gamified approach, we incentivize people to liquidate people
    // in these positions

    // if someone is almost undercollateralized we will pay the liquidator to liquidate them
    // $75 backing $50 DSC -> certainly lower than the threshold
    // liquidator takes $75 backing and burns of the $50 DSC
    /**
     *
     * @param collateral the erc20 collateral to liquidate
     * @param user the user who has broken health factor. it should be below MIN_HEALTH_FACTOR
     * @param debtToCover the amount of DSC, you want to burn to improve the users health factor
     * @notice you can partically liquidate the user and you wll get a liquidation bonus
     * @notice this function assumes the protocol will be roughly 200% overcollateralized in order this to work
     * @notice a known bug would be if the protocol were 100% or less collateralized then we wouldnt be
     * able to incentive liquidators. For example, if the price of the collateral plummeted before anyone could be liquidated.
     * Cehcks, Effects, Interactions
     */
    function liquidate(address collateral, address user, uint256 debtToCover) moreThanZero(debtToCover) nonReentrant() external {
        // need to check the health factor for the user
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR){
            revert DSCEngine_HealthFactorOK();
        }
        // we want to burn their DSC 'debt' and take their collateral
        // Bad user: $140 ETH, $100 DSC
        // debtToCover = $100
        uint256 tokenAmountFromDebtCovered = getTokenAmmountFromUSD(collateral, debtToCover);
        // and give them 10% bonus
        // so we need to give %110
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS/ LIQUIDATION_PRECISION);
    // liquidated amount + reward
        uint256 totalCollateralToRedemeed = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(collateral, totalCollateralToRedemeed, user, msg.sender);

        _burnDSC(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor =_healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor){
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(user);
    }

    // what if the eth price dumped into 40
    // what to do prevent?
    // we can set a threshold like 150%?
    // if you have $50 in the protocol DSC -> then you have to have at least $75 ETH
    // at all times.

    // Example Person 1 - threshold 150%
    // $100 ETH Collateral  -> $74 (eth price down)
    // $50 DSC minted.

    // Person 2 - sees an opportunity, undercollateralized!!
    // I'll pay back the $50 DSC -> get all your collateral
    // he gets $74 wort of ETH in return of $50 DSC
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }


    // PRIVATE internal view functions
    ////// @title Private internal view functions
    /**
     * @notice get all values for the user to compute health factor
     * @param user user
     * @return totalDSCMinted amount of DSC already minted
     * @return totalValueInUSD collateral value that person has in USD
     */
    function _getAccountInformation(address user) internal view returns(uint256 totalDSCMinted,uint256 totalValueInUSD){
        totalDSCMinted= s_userDSCMintAmount[user];
        totalValueInUSD = getAccountCollateralValue(user);
    }

    /**
     * @notice returns how close to liquidation a user is
     * @param user if a user goes below 1 then they can get liquidated.
     */
    function _healthFactor(address user) internal view returns (uint256) {
        // total DSC minted by the user
        // total collateral VALUE of user

        // get values above
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = _getAccountInformation(user);
        // we always want to be overcollateralized
        // we cant get under or equally collateralized like 100-100
        // so we have a threshold

        uint256 collateralAdjusted = (collateralValueInUSD*LIQUIDATION_THRESHOLD)/ 100;
        // return (collateralValueInUSD/totalDSCMinted);
        return collateralAdjusted*100/totalDSCMinted;
    }
    /**
     * @notice The health factor is a critical metric within the Aave Protocol
     * that measures the safety of a borrow position.
     * The health factor measures a borrow position’s stability.
     * A health factor below 1 risks liquidation.
     * HF = (Total Collateral Value * Weighted Avg Liquidation Threshold) / Total Borrow Value
     * @param user if user has enough collateral above threshold.
     */
    ///// @title A title that should describe the contract/interface
    function _revertIfHealthFactorIsBroken(address user) internal view {
        // check health factor if they have enough collateral
        // revert if they dont
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR){
            revert DSCEngine_BreaksHealthFactor();
        }
    }

    /**
     *
     * @param tokenCollateralAddress token address
     * @param amountCollateral amount
     * @param from from which
     * @param to to whom
     * @notice the redeemCollateral function above requires message.sender to rededm
     * in that case how would the liquidators can call? we need to refactor it.
     */

    function _redeemCollateral (address tokenCollateralAddress, uint256 amountCollateral, address from, address to) private {
         s_userCollateralDeposit[msg.sender][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemedFrom(from,to, tokenCollateralAddress, amountCollateral);
        // to make it gas fee efficient  we do the transfer first and then check health factor
        // if its not okay we will revert anyway.
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if(!success){
            revert DSCEngine_Transferfailed();
        }
    // check health factor
        _revertIfHealthFactorIsBroken(msg.sender);
    }


    /**
     * @dev low-level internal function dont call unless the function calling its checking
     * the healthfactor is broken
     */

    function _burnDSC(uint256 amountDSCToBurn, address onBehalfOf, address dscFrom) private {
        s_userDSCMintAmount[onBehalfOf] -= amountDSCToBurn;
        bool success = dsc.transferFrom(dscFrom, address(this), amountDSCToBurn);
        if(!success){
            revert DSEngine_TransferFailed();
        }
        dsc.burn(amountDSCToBurn);
        // when we burn debt the health factor cant get worse but lets check
        _revertIfHealthFactorIsBroken(msg.sender);
    }
    /// Public & External view functions
    //////// public external view functions
    /// @notice Explain to an end user what this does
    /////
    /**
     *
     * @param user collateral user
      */
    function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralAmountInUSD) {
        // iterate each collateral token, get the amount deposited by the user
        // map it to the price in USD

        for (uint256 i =0; i < s_collateralToken.length; i++){
            address token = s_collateralToken[i];
            uint256 amount = s_userCollateralDeposit[user][token];
            // now we need the value of the token in USD using an oracle
            totalCollateralAmountInUSD += getValueOfCollateralInUSD(token, amount);
        }
        return totalCollateralAmountInUSD;
    }


    function getValueOfCollateralInUSD(address token, uint256 amount) public view returns (uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_PriceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // if 1 ETH = $1000
        // the returned value from CL will be 1000 * 1e8

        return (uint256(price)*ADDITIONAL_FEED_PRECISION * amount)/LIQUIDATION_PRECISION;
    }

    function getTokenAmmountFromUSD(address token, uint256 usdAmountInWei) public view returns(uint256) {
        // price of eth
        // $/ETH -> $2000 ETH -> and amount is collateral $1000 => 0.5 eth
         AggregatorV3Interface priceFeed = AggregatorV3Interface(s_PriceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        (usdAmountInWei * LIQUIDATION_PRECISION)/uint256(price) * ADDITIONAL_FEED_PRECISION;
    }
}
