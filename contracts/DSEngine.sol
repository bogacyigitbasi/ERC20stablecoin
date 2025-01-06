// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

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
contract DSEngine {
    /////////
    /// Errors
    /////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenIsNotAllowed();
    error DSCEngine__TokenPriceFeedAndTokenAddressesMustBeSameLength();
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

    /////////
    /// State Variables
    /////////

    mapping(address => bool) private s_tokenAllowed;

    // check the collateral type
    modifier isAllowedToken(address token) {
        if (!s_tokenAllowed[token]) {
            revert DSCEngine__TokenIsNotAllowed();
        }
        _;
    }
    // as an alternative above. if the priceFeed existsm then thats a valid
    // collateral token
    mapping(address token => address priceFeed) private s_PriceFeeds;
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
        }
    }

    /////////
    /// EXTERNAL FUNCTIONS
    /////////
    function depositCollateralAndMintDSC() external {}

    /**
    @param tokenCollateralAddress the address of the token to deposit as collateral
    @param amountCollateral amount of collateral to deposit
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external moreThanZero(amountCollateral) {}

    function redeemCollateral() external {}

    function redeemCollateralAndMintDSC() external {}

    function mintDSC() external {}

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
}
