// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title Vesting Interface
/// @notice Provides a standard interface for token vesting contracts
interface IVesting {
    /// @notice Information about a beneficiary's vesting schedule
    /// @param totalAmount Total number of tokens to be vested
    /// @param startTime Timestamp when vesting begins
    /// @param cliff Duration of the cliff period in seconds
    /// @param duration Total duration of the vesting period in seconds
    /// @param claimed Amount of tokens already claimed
    /// @param lastClaimTime Timestamp of the last claim
    /// @param claimCooldown Minimum time interval between claims in seconds
    /// @param minClaimAmount Minimum amount that can be claimed in a single transaction
    /// @param created Indicates whether the vesting schedule has been created
    struct VestingInfo {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliff;
        uint256 duration;
        uint256 claimed;
        uint256 lastClaimTime;
        uint256 claimCooldown;
        uint256 minClaimAmount;
        bool created;
    }

    /// @notice Parameters for creating a new vesting schedule in startVesting function
    /// @param beneficiary Address that will receive vested tokens
    /// @param totalAmount Total number of tokens to be vested
    /// @param startTime Timestamp when vesting begins
    /// @param cliff Duration of the cliff period in seconds
    /// @param duration Total duration of the vesting period in seconds
    /// @param claimCooldown Minimum time interval between claims in seconds
    /// @param minClaimAmount Minimum amount that can be claimed in a single transaction
    struct VestingParams {
        address beneficiary;
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliff;
        uint256 duration;
        uint256 claimCooldown;
        uint256 minClaimAmount;
    }

    /// @notice Emitted when a new vesting schedule is created
    /// @param beneficiary Address of the beneficiary
    /// @param amount Total number of tokens to be vested
    /// @param creationTime Timestamp when the vesting schedule was created
    event VestingCreated(address indexed beneficiary, uint256 amount, uint256 creationTime);

    /// @notice Emitted when tokens are withdrawn from the contract
    /// @param to Address receiving the withdrawn tokens
    /// @param amount Number of tokens withdrawn
    event TokensWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when a beneficiary claims vested tokens
    /// @param beneficiary Address of the beneficiary
    /// @param amount Number of tokens claimed
    /// @param timestamp Timestamp when the claim was made
    event Claim(address indexed beneficiary, uint256 amount, uint256 timestamp);

    /// @notice Reverts if the vesting schedule does not exist for the beneficiary
    error VestingNotFound();

    /// @notice Reverts if the claim is not yet available
    /// @param blockTimestamp Current block timestamp
    /// @param availableFrom Timestamp when the claim becomes available
    error ClaimNotAvailable(uint256 blockTimestamp, uint256 availableFrom);

    /// @notice Reverts if there are no tokens available to claim
    error NothingToClaim();

    /// @notice Reverts if the contract does not have enough tokens to allocate
    /// @param availableBalance Number of tokens currently available in the contract
    /// @param totalAmount Number of tokens required for vesting
    error InfsufficientBalance(uint256 availableBalance, uint256 totalAmount);

    /// @notice Reverts if a vesting schedule already exists for the beneficiary
    error VestingAlreadyExist();

    /// @notice Reverts if the specified amount is zero
    error AmountCantBeZero();

    /// @notice Reverts if the vesting start time is not in the future
    /// @param startTime The specified start time
    /// @param blockTimestamp The current block timestamp
    error StartTimeShouldBeFuture(uint256 startTime, uint256 blockTimestamp);

    /// @notice Reverts if the vesting duration is zero
    error DurationCantBeZero();

    /// @notice Reverts if the claim cooldown period is longer than the vesting duration
    error CooldownCantBeLongerThanDuration();

    /// @notice Reverts if the beneficiary address is invalid
    error InvalidBeneficiary();

    /// @notice Reverts if the claimable amount is less than the minimum claim amount
    /// @param minClaimAmount The minimum claimable amount
    /// @param claimable The actual claimable amount
    error BelowMinimalClaimAmount(uint256 minClaimAmount, uint256 claimable);

    /// @notice Reverts if the required cooldown period between claims has not passed
    /// @param blockTimestamp The current block timestamp
    /// @param lastClaimTime The timestamp of the last claim
    error CooldownNotPassed(uint256 blockTimestamp, uint256 lastClaimTime);

    /// @notice Reverts if there are no tokens available to withdraw
    error NothingToWithdraw();

    /// @notice Claims all tokens currently available for the caller according to their vesting schedule
    function claim() external;

    /// @notice Creates a new vesting schedule for a beneficiary
    /// @param params Struct containing the parameters for the new vesting schedule
    function startVesting(VestingParams calldata params) external;

    /// @notice Returns the total amount of tokens vested for a beneficiary at the current time
    /// @param _claimer Address of the beneficiary
    /// @return Amount of tokens vested
    function vestedAmount(address _claimer) external view returns (uint256);

    /// @notice Returns the amount of tokens that can currently be claimed by a beneficiary
    /// @param _claimer Address of the beneficiary
    /// @return Amount of tokens claimable
    function claimableAmount(address _claimer) external view returns (uint256);

    /// @notice Withdraws all unallocated tokens from the contract to the specified address
    /// @param _to Address to receive the withdrawn tokens
    function withdrawUnallocated(address _to) external;

    /// @notice Returns the ABI-encoded initialization data for the contract
    /// @param _deployManager Address of the deploy manager
    /// @param _token Address of the ERC20 token
    /// @param _owner Address of the contract owner
    /// @return ABI-encoded initialization data
    function getInitData(address _deployManager, address _token, address _owner) external view returns (bytes memory);
}