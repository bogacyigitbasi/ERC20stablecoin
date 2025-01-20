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
    uint256 private constant PRECISION= 1e10;

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
    function depositCollateralAndMintDSC() external {}

    /**
    @notice follows CEI Checks -> Effects -> Interactions
    @param tokenCollateralAddress the address of the token to deposit as collateral
    @param amountCollateral amount of collateral to deposit
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        external
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

    function redeemCollateral() external {}

    function redeemCollateralAndMintDSC() external {}


    // 1 check if the collateral value > DSC amount. priceFeed and check values are needed
    // $200 ETH -> 20DSC?
    /**
     * @notice follows CEI (checks, effects and interactions)
     * @param amountDSCToMint amount of DSC to mint
     * @notice the depositer must have more collateral than the minimum threshold
     */
    function mintDSC(uint256 amountDSCToMint) external moreThanZero(amountDSCToMint) nonReentrant(){
        // we need to keep track of who minted how much
        s_userDSCMintAmount[msg.sender] += amountDSCToMint;
        // if they minted too much ($150  and 100 ETH)???
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDSC() external {}

    // lets say we have $100 ETH and minted $50 DSC
    // what happens when the ETH price drops too much? like $40 collateral
    // then you dont want to end up in that position
    // you liquidate people to not lose, you kick out them from the system.
    // to save the protocol
    function liquidate() external {}

    // in the previous case, what if the eth price dumped into 40
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
    function getHealthFactor() external view {}


    // PRIVATE internal view functions
    ////// @title Private internal view functions
    /**
     * @notice get all values for the user to compute health factor
     * @param user
     * @return totalDSCMinted
     * @return totalValueInUSD
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
    function revertIfHealthFactorIsBroken(address user) internal view {
        // check health factor if they have enough collateral
        // revert if they dont

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

        return (uint256(price)*ADDITIONAL_FEED_PRECISION * amount)/PRECISION;
    }
}
