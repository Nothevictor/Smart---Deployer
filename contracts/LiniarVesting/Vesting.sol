// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../UtilityContract/AbstractUtilityContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {VestingLib} from "./VestingLib.sol";
import "./IVesting.sol";

/// @title Vesting Contract
/// @notice Manages token vesting schedules for beneficiaries
/// @dev Inherits IVesting, AbstractUtilityContract, Ownable
contract Vesting is IVesting, AbstractUtilityContract, Ownable {
    using VestingLib for IVesting.VestingInfo;

    /// @notice Initializes the contract with deploy manager, token, and owner
    constructor() payable Ownable(msg.sender) {}

    /// @notice The ERC20 token that is being vested
    IERC20 public token;

    /// @notice The total amount of tokens that have been allocated for vesting
    uint256 public allocatedTokens;

    /// @notice A mapping of beneficiary addresses to their vesting information
    mapping(address => IVesting.VestingInfo) public vestings;

    /// @inheritdoc IVesting
    function claim() public {
        address claimer = msg.sender;
        VestingInfo storage vesting = vestings[claimer];
        if (!vesting.created) revert VestingNotFound();
        uint256 blockTimestamp = block.timestamp;

        if (blockTimestamp < vesting.startTime + vesting.cliff) {
            revert ClaimNotAvailable(blockTimestamp, vesting.startTime + vesting.cliff);
        }

        if (blockTimestamp <= vesting.lastClaimTime + vesting.claimCooldown) {
            revert CooldownNotPassed(blockTimestamp, vesting.lastClaimTime);
        }

        uint256 claimable = vesting.claimableAmount();

        if (claimable == 0) revert NothingToClaim();
        if (claimable < vesting.minClaimAmount) {
            revert BelowMinimalClaimAmount(vesting.minClaimAmount, claimable);
        }

        unchecked {
            vesting.claimed = vesting.claimed + claimable;
            vesting.lastClaimTime = blockTimestamp;
            allocatedTokens = allocatedTokens - claimable;
        }

        require(token.transfer(claimer, claimable));

        emit Claim(claimer, claimable, blockTimestamp);
    }

    /// @inheritdoc IVesting
    function startVesting(IVesting.VestingParams calldata params) external onlyOwner {
        if (params.beneficiary == address(0)) revert InvalidBeneficiary();
        if (params.duration == 0) revert DurationCantBeZero();
        if (params.totalAmount == 0) revert AmountCantBeZero();

        uint256 blockTimestamp = block.timestamp;

        if (params.startTime < blockTimestamp) {
            revert StartTimeShouldBeFuture(params.startTime, blockTimestamp);
        }
        if (params.claimCooldown > params.duration) {
            revert CooldownCantBeLongerThanDuration();
        }

        uint256 availableBalance = token.balanceOf(address(this)) - allocatedTokens;

        if (availableBalance < params.totalAmount) {
            revert InfsufficientBalance(availableBalance, params.totalAmount);
        }

        VestingInfo storage vesting = vestings[params.beneficiary];

        if (vesting.created) {
            if (vesting.totalAmount != vesting.claimed) revert VestingAlreadyExist();
        }

        vesting.totalAmount = params.totalAmount;
        vesting.startTime = params.startTime;
        vesting.cliff = params.cliff;
        vesting.duration = params.duration;
        vesting.claimCooldown = params.claimCooldown;
        vesting.minClaimAmount = params.minClaimAmount;
        vesting.claimed = 0;
        vesting.lastClaimTime = 0;
        vesting.created = true;

        unchecked {
            allocatedTokens = allocatedTokens + params.totalAmount;
        }

        emit VestingCreated(params.beneficiary, params.totalAmount, blockTimestamp);
    }

    /// @inheritdoc IVesting
    function withdrawUnallocated(address _to) external onlyOwner {
        uint256 available = token.balanceOf(address(this)) - allocatedTokens;

        if (available == 0) revert NothingToWithdraw();

        require(token.transfer(_to, available));

        emit TokensWithdrawn(_to, available);
    }

    /// @inheritdoc AbstractUtilityContract
    function initialize(bytes memory _initData) external override notInitialized returns (bool) {
        (address _deployManager, address _token, address _owner) = abi.decode(_initData, (address, address, address));

        setDeployManager(_deployManager);

        token = IERC20(_token);
        Ownable.transferOwnership(_owner);

        initialized = true;
        return true;
    }

    /// @inheritdoc IVesting
    function vestedAmount(address _claimer) public view returns (uint256) {
        return vestings[_claimer].vestedAmount();
    }

    /// @inheritdoc IVesting
    function claimableAmount(address _claimer) public view returns (uint256) {
        return vestings[_claimer].claimableAmount();
    }

    /// @inheritdoc IVesting
    function getInitData(address _deployManager, address _token, address _owner) external pure returns (bytes memory) {
        return abi.encode(_deployManager, _token, _owner);
    }
}