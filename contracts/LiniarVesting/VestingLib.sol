// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./IVesting.sol";

/// @title Vesting Library
/// @notice Provides utility functions for calculating vested and claimable token amounts
library VestingLib {
    /// @notice Calculates the total amount of tokens vested for a given vesting schedule at the current time
    /// @param v The vesting information struct
    /// @return The total amount of tokens vested
    function vestedAmount(IVesting.VestingInfo storage v) internal view returns (uint256) {
        if (block.timestamp < v.startTime + v.cliff) return 0;
        uint256 passed = block.timestamp - (v.startTime + v.cliff);
        if (passed > v.duration) passed = v.duration;
        return (v.totalAmount * passed) / v.duration;
    }

    /// @notice Calculates the amount of tokens currently claimable by the beneficiary
    /// @param v The vesting information struct
    /// @return The amount of tokens that can be claimed
    function claimableAmount(IVesting.VestingInfo storage v) internal view returns (uint256) {
        uint256 vested = vestedAmount(v);
        if (vested <= v.claimed) return 0;
        return vested - v.claimed;
    }
}