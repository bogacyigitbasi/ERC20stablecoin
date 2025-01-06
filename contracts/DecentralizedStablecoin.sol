// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import {ERC20, ERC20Burnable} from "../node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// import {Ownable} from "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
/**
    @title DecentralizeStablecoin
    @author by
    Collateral: wETH, wBTC
    Minting: Algorithmic
    Stability: using Chainlink

There are 2 main contracts of the project, this is just an ERC20
governed by DSEngine (DecentralizedStablecoinEngine) contract
*/
// we want to burn
contract DecentralizedStablecoin is ERC20Burnable, Ownable {
    // errors
    error DSC_MustBeGreaterThanZero();
    error DSC_MintTryForZeroAddress();
    // ERC20Burnable is ERC20 which means we have to use ERC20 constructor as well.
    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC20(name, symbol) Ownable(initialOwner) {}

    function burn(uint256 _amount) public override onlyOwner {
        if (_amount <= 0) {
            revert DSC_MustBeGreaterThanZero();
        }
        uint256 balance = balanceOf(msg.sender);
        require(_amount < balance, "Not enough token balance");

        // use the super class to burn
        super.burn(_amount);
    }

    // not overriding anything for `mint`
    // there is no mint function either in parent
    function mint(
        address _to,
        uint256 _amount
    ) public onlyOwner returns (bool) {
        if (_amount <= 0) {
            revert DSC_MustBeGreaterThanZero();
        }
        if (_to == address(0)) {
            revert DSC_MintTryForZeroAddress();
        }
        _mint(_to, _amount);
        return true;
    }
}
