
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.3;

/// @title The interface for the TickHelper
/// @notice The TickHelper automates the calculations to determine the Max or Min Ticks to use within the Unicrypt / Uniswap V3 integration
interface ITickHelper {

    /// @notice Returns the max tick for a given fee amount
    /// @param fee the fee used in the pool
    /// @return maxTick The tick spacing
    function getMaxTick(uint24 fee) external view returns (int24 maxTick);

    /// @notice Returns the min tick for a given fee amount
    /// @param fee the fee used in the pool
    /// @return minTick The tick spacing
    function getMinTick(uint24 fee) external view returns (int24 minTick);

    /// @notice Sets a new fee and tickSpace for that fee. Only Owner can call
    /// Should only be used when uniswap v3 adds new fees
    /// @param fee the new fee to be added.
    /// @param tickSpace the new ticks space related to the fee
    function setTickSpace(uint24 fee, uint24 tickSpace) external;

}
