// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vesting is IUtilityContract, Ownable {
    constructor() Ownable(msg.sender) {}

    IERC20 public token;
    bool private initialized;
    bool private vestingStarted;
    uint256 public claimCooldown;
    uint256 public minClaimAmount;

    struct BeneficiaryInfo {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliff;
        uint256 duration;
        uint256 claimed;
        uint256 lastClaimTime;
    }

    mapping(address => BeneficiaryInfo) public beneficiaries;

    error AlreadyInitialized();
    error VestingAlreadyStarted();
    error VestingNotStarted();
    error ClaimerIsNotBeneficiary();
    error CliffNotReached();
    error TransferFailed();
    error NothingToClaim();
    error CooldownNotPassed();
    error BelowMinClaimAmount();
    error InsufficientTokenBalance();
    error InvalidBeneficiaryData();
    error InvalidParameters();
    error InsufficientTokensOnContract();

    event Claim(address indexed beneficiary, uint256 amount, uint256 timestamp);
    event Initialized(address indexed token, uint256 cooldown, uint256 minClaimAmount);
    event VestingStarted(address[] beneficiaries, uint256 totalTokens);
    event BeneficiaryAdded(address indexed beneficiary, uint256 totalAmount, uint256 startTime, uint256 cliff, uint256 duration);
    event ClaimParametersUpdated(uint256 newCooldown, uint256 newMinClaimAmount);

    modifier notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }

    modifier vestingNotStarted() {
        require(!vestingStarted, VestingAlreadyStarted());
        _;
    }


    function initialize(bytes memory _initData) external notInitialized returns (bool) {
        (address _token, uint256 _cooldown, uint256 _minClaimAmount) = abi.decode(_initData, (address, uint256, uint256));

        require(_token != address(0), "Invalid token address");

        token = IERC20(_token);
        claimCooldown = _cooldown;
        minClaimAmount = _minClaimAmount;

        initialized = true;
        emit Initialized(_token, _cooldown, _minClaimAmount);

        _transferOwnership(msg.sender);

        return true;
    }


    function startVesting(bytes memory _vestingData) external onlyOwner vestingNotStarted {
        (
            address[] memory _beneficiaries,
            uint256[] memory _totalAmounts,
            uint256[] memory _startTimes,
            uint256[] memory _cliffs,
            uint256[] memory _durations
        ) = abi.decode(_vestingData, (address[], uint256[], uint256[], uint256[], uint256[]));

        require(_beneficiaries.length == _totalAmounts.length &&
                _beneficiaries.length == _startTimes.length &&
                _beneficiaries.length == _cliffs.length &&
                _beneficiaries.length == _durations.length, "Array length mismatch");
        require(_beneficiaries.length > 0, "No beneficiaries provided");

        uint256 totalTokens = 0;
        for (uint256 i = 0; i < _totalAmounts.length; i++) {
            totalTokens += _totalAmounts[i];
        }

        require(token.balanceOf(address(this)) >= totalTokens, InsufficientTokensOnContract());

      
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            require(_beneficiaries[i] != address(0), "Invalid beneficiary address");
            require(_totalAmounts[i] > 0, "Invalid total amount");
            require(_durations[i] > 0, "Invalid duration");
            require(_startTimes[i] >= block.timestamp, "Start time must be in future");
            require(_cliffs[i] <= _durations[i], "Cliff exceeds duration");

            beneficiaries[_beneficiaries[i]] = BeneficiaryInfo({
                totalAmount: _totalAmounts[i],
                startTime: _startTimes[i],
                cliff: _cliffs[i],
                duration: _durations[i],
                claimed: 0,
                lastClaimTime: 0
            });

            emit BeneficiaryAdded(_beneficiaries[i], _totalAmounts[i], _startTimes[i], _cliffs[i], _durations[i]);
        }

        vestingStarted = true;
        emit VestingStarted(_beneficiaries, totalTokens);
    }

    function claim() public {
        require(vestingStarted, VestingNotStarted());
        BeneficiaryInfo storage info = beneficiaries[msg.sender];
        require(info.totalAmount > 0, ClaimerIsNotBeneficiary());
        require(block.timestamp > info.startTime + info.cliff, CliffNotReached());
        require(block.timestamp >= info.lastClaimTime + claimCooldown, CooldownNotPassed());

        uint256 claimable = claimableAmount(msg.sender);
        require(claimable >= minClaimAmount, BelowMinClaimAmount());
        require(claimable > 0, NothingToClaim());
        require(token.balanceOf(address(this)) >= claimable, InsufficientTokenBalance());

        info.claimed += claimable;
        info.lastClaimTime = block.timestamp;

        require(token.transfer(msg.sender, claimable), TransferFailed());

        emit Claim(msg.sender, claimable, block.timestamp);
    }

    function vestedAmount(address _beneficiary) internal view returns (uint256) {
        BeneficiaryInfo memory info = beneficiaries[_beneficiary];
        if (info.totalAmount == 0 || block.timestamp < info.startTime + info.cliff) return 0;

        uint256 passedTime = block.timestamp - (info.startTime + info.cliff);
        if (passedTime >= info.duration) return info.totalAmount;
        return (info.totalAmount * passedTime) / info.duration;
    }

    function claimableAmount(address _beneficiary) public view returns (uint256) {
        BeneficiaryInfo memory info = beneficiaries[_beneficiary];
        if (info.totalAmount == 0 || block.timestamp < info.startTime + info.cliff) return 0;

        return vestedAmount(_beneficiary) - info.claimed;
    }

    function setClaimParameters(uint256 _newCooldown, uint256 _newMinClaimAmount) external onlyOwner {
        claimCooldown = _newCooldown;
        minClaimAmount = _newMinClaimAmount;
        emit ClaimParametersUpdated(_newCooldown, _newMinClaimAmount);
    }

    function getInitData(
        address _token,
        uint256 _cooldown,
        uint256 _minClaimAmount
    ) external pure returns (bytes memory) {
        return abi.encode(_token, _cooldown, _minClaimAmount);
    }

    function getVestingData(
        address[] memory _beneficiaries,
        uint256[] memory _totalAmounts,
        uint256[] memory _startTimes,
        uint256[] memory _cliffs,
        uint256[] memory _durations
    ) external pure returns (bytes memory) {
        return abi.encode(_beneficiaries, _totalAmounts, _startTimes, _cliffs, _durations);
    }
}