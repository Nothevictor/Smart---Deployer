// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./AutoVestingSplitter.sol";
import "../IUtilityContract.sol";

contract CrowdFunding is Ownable, Initializable, IUtilityContract {
    uint256 public goal;
    uint256 public totalRaised;
    uint256 public deadline;
    address public vestingContract;
    bool public goalReached;
    address public fundraiser;
    uint64 public vestingDuration;
    address public smartDeployer;
    address public vestingMaster;

    mapping(address => uint256) public contributions;

    error CampaignEnded();
    error CampaignNotEnded();
    error GoalAlreadyReached();
    error InsufficientContribution();
    error NoContribution();
    error VestingNotSet();
    error TransferFailed();
    error InvalidParameters();
    error NotFundraiser();
    error GoalNotReached();
    error VestingDeploymentFailed();
    error InvalidContractAddress();

    event Contributed(address indexed contributor, uint256 amount, uint256 timestamp);
    event Refunded(address indexed contributor, uint256 amount, uint256 timestamp);
    event GoalReached(uint256 totalRaised, uint256 timestamp);
    event FundsTransferredToVesting(address indexed vestingContract, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed fundraiser, uint256 amount, uint256 timestamp);

    constructor() {
        _disableInitializers();
    }

    
    function initialize(bytes calldata _initData) external override initializer {
        (
            uint256 _goal,
            uint256 _duration,
            address _fundraiser,
            uint64 _vestingDuration,
            address _smartDeployer,
            address _vestingMaster,
            address _owner
        ) = abi.decode(_initData, (uint256, uint256, address, uint64, address, address, address));

        require(_goal > 0, "Goal must be greater than zero");
        require(_duration > 0, "Duration must be greater than zero");
        require(_fundraiser != address(0), "Invalid fundraiser address");
        require(_vestingDuration > 0, "Vesting duration must be greater than zero");
        require(_smartDeployer != address(0), "Invalid SmartDeployer address");
        require(_vestingMaster != address(0), "Invalid vesting master address");
        require(_owner != address(0), "Invalid owner address");

        
        require(isContract(_smartDeployer), "SmartDeployer is not a contract");
        require(isContract(_vestingMaster), "Vesting master is not a contract");

        goal = _goal;
        deadline = block.timestamp + _duration;
        fundraiser = _fundraiser;
        vestingDuration = _vestingDuration;
        smartDeployer = _smartDeployer;
        vestingMaster = _vestingMaster;

        _transferOwnership(_owner);
    }

    
    function getInitData(
        uint256 _goal,
        uint256 _duration,
        address _fundraiser,
        uint64 _vestingDuration,
        address _smartDeployer,
        address _vestingMaster,
        address _owner
    ) external pure returns (bytes memory) {
        return abi.encode(_goal, _duration, _fundraiser, _vestingDuration, _smartDeployer, _vestingMaster, _owner);
    }

    
    function contribute() external payable {
        require(block.timestamp <= deadline, CampaignEnded());
        require(!goalReached, GoalAlreadyReached());
        require(msg.value > 0, InsufficientContribution());

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit Contributed(msg.sender, msg.value, block.timestamp);

        
        if (totalRaised >= goal) {
            goalReached = true;
            emit GoalReached(totalRaised, block.timestamp);
            _transferToVesting();
        }
    }

    
    function refund() external {
        require(block.timestamp <= deadline, CampaignNotEnded());
        require(!goalReached, GoalAlreadyReached());
        require(contributions[msg.sender] > 0, NoContribution());

        uint256 amount = contributions[msg.sender];
        contributions[msg.sender] = 0;
        totalRaised -= amount;

        (bool sent, ) = msg.sender.call{value: amount, gas: 30000}("");
        require(sent, TransferFailed());

        emit Refunded(msg.sender, amount, block.timestamp);
    }

    
    function finalizeCampaign() external {
        require(block.timestamp > deadline, CampaignNotEnded());
        require(!goalReached, GoalAlreadyReached());
        require(contributions[msg.sender] > 0, NoContribution());

        uint256 amount = contributions[msg.sender];
        contributions[msg.sender] = 0;
        totalRaised -= amount;

        (bool sent, ) = msg.sender.call{value: amount, gas: 30000}("");
        require(sent, TransferFailed());

        emit Refunded(msg.sender, amount, block.timestamp);
    }

    
    function withdraw() external {
        require(msg.sender == fundraiser, NotFundraiser());
        require(goalReached, GoalNotReached());
        require(vestingContract != address(0), VestingNotSet());

        AutoVestingSplitter vesting = AutoVestingSplitter(vestingContract);
        address vestingWallet = vesting.getVestingWallet(fundraiser);
        require(vestingWallet != address(0), "Vesting wallet not found");
        require(isContract(vestingWallet), "Vesting wallet is not a contract");

        VestingWallet wallet = VestingWallet(payable(vestingWallet));
        uint256 releasable = wallet.releasable();
        require(releasable > 0, "No ETH available to withdraw");

        wallet.release();
        emit Withdrawn(msg.sender, releasable, block.timestamp);
    }

    
    function _transferToVesting() internal {
        require(address(this).balance >= totalRaised, "Insufficient balance");

        
        AutoVestingSplitter vestingMasterInstance = AutoVestingSplitter(vestingMaster);
        address[] memory accounts = new address[](1);
        uint256[] memory shares = new uint256[](1);
        accounts[0] = fundraiser;
        shares[0] = 100;

        bytes memory vestingInitData = vestingMasterInstance.getInitData(
            accounts,
            shares,
            vestingDuration,
            fundraiser
        );

        
        (bool success, bytes memory result) = smartDeployer.call(
            abi.encodeWithSignature("deploy(address,bytes)", vestingMaster, vestingInitData)
        );
        require(success, VestingDeploymentFailed());

        
        address vestingClone = abi.decode(result, (address));
        require(vestingClone != address(0), "Invalid vesting clone address");
        require(isContract(vestingClone), "Vesting clone is not a contract");

        vestingContract = vestingClone;

       
        uint256 amountToTransfer = totalRaised > goal ? goal : totalRaised;

        
        (bool sent, ) = vestingContract.call{value: amountToTransfer, gas: 30000}("");
        require(sent, TransferFailed());

       
        if (totalRaised > goal) {
            (bool refund, ) = owner().call{value: totalRaised - goal, gas: 30000}("");
            require(refund, TransferFailed());
        }

        emit FundsTransferredToVesting(vestingContract, amountToTransfer, block.timestamp);
    }

   
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}