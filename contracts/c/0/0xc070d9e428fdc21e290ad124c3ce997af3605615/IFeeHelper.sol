
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.3;

/// @title The interface for the FeeHelper
/// @notice The FeeHelper manages the fee percentages and wallets to use within the Unicrypt / Uniswap V3 integration
interface IFeeHelper {

    /// @notice Returns the fee percentage
    /// @return fee percentage
    function getFee() view external returns(uint256);

    /// @notice Returns the fee denominator to calculate fee percentages.
    /// @return fee denominator
    function getFeeDenominator() view external returns(uint256);
    
    /// @notice Sets a new fee. Only Owner can call
    /// @param _fee the new fee.
    function setFee(uint _fee) external;
    
    /// @notice Returns the fee wallet address
    /// @return fee wallet address
    function getFeeAddress() view external returns(address);

    /// @notice Sets a new fee wallet address. Only Owner can call
    /// @param _feeAddress the new fee wallet address.
    function setFeeAddress(address payable _feeAddress) external;

}
