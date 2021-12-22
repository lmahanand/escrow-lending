// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./CompoundRegistry.sol";

interface ERC20 {
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface ICompound {
    function addInvestment(address _wallet, address _token, uint256 _amount) external returns (uint256 _invested);
    function removeInvestment(address _wallet, address _token, uint256 _fraction) external;
    function getInvestment( address _wallet, address _token) external view returns (uint256 _tokenValue, uint256 _periodEnd);
}

interface ICToken {
    function comptroller() external view returns (address);
    function underlying() external view returns (address);
    function symbol() external view returns (string memory);
    function exchangeRateCurrent() external returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function balanceOf(address _account) external view returns (uint256);
    function borrowBalanceCurrent(address _account) external returns (uint256);
    function borrowBalanceStored(address _account) external view returns (uint256);
    function mint(uint256) external returns (uint256);
    function redeem(uint) external returns (uint);
    function redeemUnderlying(uint) external returns (uint);
}

/**
 * @title Compound
 * @dev Module to invest tokens in Compound
 */
contract Compound is ICompound{

    // The registry mapping underlying with cTokens
    CompoundRegistry public compoundRegistry;

    // Mock token address for ETH
    address constant internal ETH_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    using SafeMath for uint256;

    event InvestmentAdded(address indexed _wallet, address _token, uint256 _invested);
    event InvestmentRemoved(address indexed _wallet, address _token, uint256 _fraction);

    constructor( CompoundRegistry _compoundRegistry ) {
        compoundRegistry = _compoundRegistry;
    }
    
    /**
     * @dev Invest tokens for a given period.
     * @param _wallet The target wallet.
     * @param _token The token address.
     * @param _amount The amount of tokens to invest.
     */
    function addInvestment(
        address _wallet,
        address _token,
        uint256 _amount
    )
        override
        external
        returns (uint256 _invested)
    {
        address cToken = compoundRegistry.getCToken(_token);
        require(cToken != address(0), "Compound: No market for target token");
        require(_amount > 0, "Compound: amount cannot be 0");
        
        if (_token == ETH_TOKEN_ADDRESS) {
            _invested = ICToken(cToken).mint(_amount);
        } else {
            ERC20(_token).approve(cToken, _amount);
            _invested = _invested = ICToken(cToken).mint(_amount);
        }
        emit InvestmentAdded(_wallet, _token, _amount);
    }

    /**
     * @dev Exit invested postions.
     * @param _wallet The target wallet.
     * @param _token The token address.
     * @param _fraction The fraction of invested tokens to exit in per 10000.
     */
    function removeInvestment(
        address _wallet,
        address _token,
        uint256 _fraction
    )
        override
        external
    {
        require(_fraction <= 10000, "CompoundV2: invalid fraction value");
        address cToken = compoundRegistry.getCToken(_token);
        uint shares = ICToken(cToken).balanceOf(_wallet);
        require(cToken != address(0), "Compound: No market for target token");
        uint amount = shares.mul(_fraction).div(10000);
        require(amount > 0, "Compound: amount cannot be 0");
        ICToken(cToken).redeem(amount);
        emit InvestmentRemoved(_wallet, _token, _fraction);
    }

    /**
     * @dev Get the amount of investment in a given token.
     * @param _wallet The target wallet.
     * @param _token The token address.
     */
    function getInvestment(
        address _wallet,
        address _token
    )
        override
        external
        view
        returns (uint256 _tokenValue, uint256 _periodEnd)
    {
        address cToken = compoundRegistry.getCToken(_token);
        uint amount = ICToken(cToken).balanceOf(_wallet);
        uint exchangeRateMantissa = ICToken(cToken).exchangeRateStored();
        _tokenValue = amount.mul(exchangeRateMantissa).div(10 ** 18);
        _periodEnd = 0;
    }
}