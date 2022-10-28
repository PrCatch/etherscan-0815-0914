
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.3;

/// @title The interface for the Uniswap V3 LP Factory on Unicrypt
/// @notice The Uniswap V3 LPFactory facilitates creation of Uniswap V3 pools and Unicrypt LP tokens
interface IUnicryptUniV3LPFactory {

    /// @notice Returns the LP Token address for a given pair of tokens and a fee, or address 0 if it does not exist
    /// @dev tokenA and tokenB may be passed in either token0/token1 or token1/token0 order
    /// @param _token0 The contract address of either token0 or token1
    /// @param _token1 The contract address of the other token
    /// @param _fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @return lpToken The pool address
    function getLPTokenAddress(
        address _token0,
        address _token1,
        uint24 _fee
    ) external view returns (address lpToken);

    /// @notice Returns the LP Token address for a given index
    /// @dev Use NUM_TOKENS to get the array length, then iterate through the array with this function
    /// @param _index The index
    /// @return lpToken The pool address
    function getLPTokenByIndex(
        uint256 _index
    ) external view returns (address lpToken);

    /// @notice Creates a pool for the given two tokens and fee, or updates a pool if it already exists. Creates an LP token.
    /// @param _token0 One of the two tokens in the desired pool
    /// @param _token1 The other of the two tokens in the desired pool
    /// @param _fee The desired fee for the pool
    /// @param _sqrtPriceX96 to initiate the pool
    /// @dev tokenA and tokenB may be passed in either order: token0/token1 or token1/token0.
    /// The call will revert if the fee is invalid, or the token arguments
    /// are invalid.
    /// @return lpToken The address of the newly created LP Token
    function createOrUpdatePool(
        address  _token0,
        address _token1,
        uint24 _fee,
        uint160 _sqrtPriceX96
    ) external returns (address lpToken);

    /// @notice Sets the address for the current or desired TickHelper Contract
    /// @dev called only when updating the TickHelper Contract
    /// @param _newtickHelper address of the new contract
    function updateTickHelper(
        address  _newtickHelper
    ) external;

    /// @notice Sets the address for the current or desired FeeHelper Contract
    /// @dev called only when updating the FeeHelper Contract
    /// @param _newFeeHelper address of the new contract
    function updateFeeHelper(
        address  _newFeeHelper
    ) external;

    /// @notice Returns the feeHelper Address
    /// @return feeHelper Address
    function getFeeHelperAddress() external view returns (address);

    /// @notice Sets the address for the current or desired lpTokenHelper Contract
    /// @dev called only when updating the lpTokenHelper Contract
    /// @param _newLPTokenHelper address of the new contract
    function updateLPTokenHelper(
        address  _newLPTokenHelper
    ) external;

    /// @notice Returns the lpTokenHelper Address
    /// @return lpTokenHelper Address
    function getLPTokenHelperAddress() external view returns (address);

}
