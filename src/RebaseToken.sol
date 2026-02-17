// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Nishant Kumar
 * @notice This is a cross-chain rebase token that incentivizes users to deposit into a vault and gain interest in rewards
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit
 */
contract RebaseToken is ERC20 {
    /////////////////
    //    Errors   //
    /////////////////

    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    ///////////////////////
    //  State Variables  //
    ///////////////////////

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10; // 0.000000005 -> 5e10 tokens to be minted per second
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    ///////////////////////
    //      Events       //
    ///////////////////////

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    /**
     * @notice Set the interest rate in the contract
     * @param _newInterestRate The new interest rate to set
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external {
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint the tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * Calculate the balance for the user including the interest that has accumulated since the last update
     * (principal balance) + some interest that has accrued
     * @param _user The user to calculate the balance for
     * @return The balance of the user including the interest that has accumulated since the last update
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principal balance (the number of tokens that have actually been minted to the user)
        // multiply the principal balance by the interest that has accumulated in the time since the balance was last updated
        return (super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user)) / PRECISION_FACTOR;
    }

    /**
     * @notice Calculate the interest that has accumulated since the last update
     * @param _user The user to calculate teh interest accumulated for
     * @return linearInterest The interest that has accumulated since the last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need to calculate the interest that has accumulated since the last update
        // this is going to be linear growth with time
        // 1. calculate the time since the last update
        // 2. calculate the amount of linear growth
        // (principal amount) + principal amount * user interest rate * time elapsed
        // deposit: 10 tokens
        // interest rate 0.5 tokens per second
        // time elapsed is 2 seconds
        // 10 + (10 * 0.5 * 2)
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    function _mintAccruedInterest(address _user) internal {
        // (1) find their current balance of rebase tokens that have been minted to the user -> principal balance
        uint256 principalAmount = super.balanceOf(_user);
        // (2) calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens that need to be minted to the user -> (2) - (1)
        uint256 interest = currentBalance - principalAmount;
        // call _mint to mint the tokens to the user
        _mint(_user, interest);
        // set the users last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    //////////////////////////
    //// Getter Functions ////
    //////////////////////////

    /**
     * @notice Get the interest rate for the user
     * @param _user The user address to get the interest rate for
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
