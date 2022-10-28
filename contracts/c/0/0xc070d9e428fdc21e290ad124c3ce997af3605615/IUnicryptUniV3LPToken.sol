
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.3;

import "./IERC20.sol";

/// @title The interface for the Uniswap V3 LP Token on Unicrypt
/// @notice The Uniswap V3 LP Token facilitates creates and manages Unicrypt LP tokens and 
///  interactions with the pool
interface IUnicryptUniV3LPToken is IERC20{

    /// @notice Sets the ticks on the LP Token
    /// @dev Must call this from the factory before doing any liquidity operations
    /// @param _tickUpper The higher tick
    /// @param _tickLower The lower tick
    function setTicks(
        int24 _tickUpper,
        int24 _tickLower
    ) external;

    /// @notice Called to `msg.sender` after minting liquidity to a position from IUniswapV3Pool#mint.
    /// @dev In the implementation you must pay the pool tokens owed for the minted liquidity.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// @param amount0Owed The amount of token0 due to the pool for the minted liquidity
    /// @param amount1Owed The amount of token1 due to the pool for the minted liquidity
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#mint call
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;

    /// @notice Mints liquidity to the Uniswap V3 Pool, and adds to the total supply
    /// of the LP Token
    /// @param amount0Desired The desired amount of token0 added to the liquidity pool
    /// @param amount1Desired The desired amount of token1 added to the liquidity pool
    /// @return amount0 and amount1 - the amount eof each token used to provide liquidity
    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external payable returns (uint256 amount0, uint256 amount1);

    /// @notice Removes liquidity from the Uniswap V3 Pool, and burns the total supply
    /// of the LP Token, sends the owed tokens to the msg.sender
    /// @param _desiredLiquidity The desired amount of liquidity to remove
    /// @return amount0 and amount1 - the amount eof each token removed
    function removeLiquidity(
        uint128 _desiredLiquidity
    ) external payable returns (uint256 amount0, uint256 amount1);

    /// @notice Collects tokens owed from the liquidity pool and sends back to the LP Token
    /// @dev the LP Token receives the fees, then mints them back into the pool. 
    /// @param amount0Max The maximum amount of token0 to collect from the liquidity pool
    /// @param amount1Max The maximum amount of token1 to collect from the liquidity pool
    /// @return amount0 and amount1 - the amount of each token collected
    function collect(
        uint256 amount0Max,
        uint256 amount1Max
    ) external payable returns (uint256 amount0, uint256 amount1);

    /// @notice Sets the initial price for the pool. Can only be called once.
    /// @param _sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initializePool(
        uint160 _sqrtPriceX96
    ) external;

        // @notice Multicall to mint and collect
    /// @param _amount0Desired The desired amount of token0 added to the liquidity pool
    /// @param _amount1Desired The desired amount of token1 added to the liquidity pool
    /// @param _amount0Max The maximum amount of token0 to collect from the liquidity pool
    /// @param _amount1Max The maximum amount of token1 to collect from the liquidity pool
    /// @return results
    function addMulticall(uint256 _amount0Desired, uint256 _amount1Desired, uint128 _amount0Max, uint128 _amount1Max) external payable returns (bytes[] memory results);


        // @notice Multicall to remove and collect
    /// @param _desiredLiquidity The desired amount of liquidity to remove
    /// @param _amount0Max The maximum amount of token0 to collect from the liquidity pool
    /// @param _amount1Max The maximum amount of token1 to collect from the liquidity pool
    /// @return results
    function removeMulticall(uint256 _desiredLiquidity, uint128 _amount0Max, uint128 _amount1Max) external payable returns (bytes[] memory results);
}
