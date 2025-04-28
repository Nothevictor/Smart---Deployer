// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

interface IUtilityContract {
    function initialize(bytes calldata initData) external;
}

contract ERC721Airdroper is ERC721Upgradeable, OwnableUpgradeable, IUtilityContract {
    uint256 public nextTokenId;
    address public airdropReceiver;

    constructor() {
        _disableInitializers();
    }

    function initialize(bytes calldata _initData) external override initializer {
        (string memory name, string memory symbol, address _airdropReceiver) = abi.decode(_initData, (string, string, address));
        require(_airdropReceiver != address(0), "Invalid airdrop receiver address");

        __ERC721_init(name, symbol);
        __Ownable_init(msg.sender);

        nextTokenId = 1;
        airdropReceiver = _airdropReceiver;
    }

    function airdrop(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(amount <= 1000, "Amount too large"); // Добавлен лимит

        for (uint256 i = 0; i < amount; i++) {
            _safeMint(airdropReceiver, nextTokenId);
            nextTokenId++;
        }
    }

    function airdropToMultiple(address[] calldata receivers) external onlyOwner {
        require(receivers.length > 0, "No receivers specified");
        require(receivers.length <= 1000, "Too many receivers"); // Добавлен лимит

        for (uint256 i = 0; i < receivers.length; i++) {
            require(receivers[i] != address(0), "Invalid receiver address");
            _safeMint(receivers[i], nextTokenId);
            nextTokenId++;
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "ipfs://QmExampleBaseURI/";
    }
}

contract DeployManager is OwnableUpgradeable {
    event NewContractAdded(address indexed contractAddress, uint256 fee, bool isActive, uint256 timestamp);
    event ContractFeeUpdated(address indexed contractAddress, uint256 oldFee, uint256 newFee, uint256 timestamp);
    event ContractStatusUpdated(address indexed contractAddress, bool isActive, uint256 timestamp);
    event NewDeployment(address indexed deployer, address indexed contractAddress, uint256 fee, uint256 timestamp);

    constructor(address initialOwner) {
        __Ownable_init(initialOwner);
    }

    struct ContractInfo {
        uint256 fee;
        bool isActive;
        uint256 registredAt;
    }

    mapping(address => address[]) public deployedContracts;
    mapping(address => ContractInfo) public contractsData;

    error ContractNotActive();
    error NotEnoughFunds();
    error ContractNotRegistered();
    error InitializationFailed();

    function deploy(address _utilityContract, bytes calldata _initData) external payable returns (address) {
        ContractInfo memory info = contractsData[_utilityContract];

        require(info.isActive, ContractNotActive());
        require(msg.value >= info.fee, NotEnoughFunds());
        require(info.registredAt > 0, ContractNotRegistered());

        address clone = Clones.clone(_utilityContract);

        try IUtilityContract(clone).initialize(_initData) {
        
        } catch {
            revert InitializationFailed();
        }

        if (msg.value > info.fee) {
            (bool refundSent, ) = msg.sender.call{value: msg.value - info.fee}("");
            require(refundSent, "Failed to refund excess");
        }

        (bool sent, ) = owner().call{value: info.fee}("");
        require(sent, "Failed to send Ether");

        deployedContracts[msg.sender].push(clone);

        emit NewDeployment(msg.sender, clone, info.fee, block.timestamp);

        return clone;
    }

    function addNewContract(address _contractAddress, uint256 _fee, bool _isActive) external onlyOwner {
        require(_contractAddress != address(0), "Invalid contract address");

        contractsData[_contractAddress] = ContractInfo({
            fee: _fee,
            isActive: _isActive,
            registredAt: block.timestamp
        });

        emit NewContractAdded(_contractAddress, _fee, _isActive, block.timestamp);
    }

    function updateFee(address _contractAddress, uint256 _newFee) external onlyOwner {
        require(contractsData[_contractAddress].registredAt > 0, ContractNotRegistered());
        uint256 oldFee = contractsData[_contractAddress].fee;
        contractsData[_contractAddress].fee = _newFee;
        emit ContractFeeUpdated(_contractAddress, oldFee, _newFee, block.timestamp);
    }

    function deactivateContract(address _contractAddress) external onlyOwner {
        require(contractsData[_contractAddress].registredAt > 0, ContractNotRegistered());
        contractsData[_contractAddress].isActive = false;
        emit ContractStatusUpdated(_contractAddress, false, block.timestamp);
    }

    function activateContract(address _contractAddress) external onlyOwner {
        require(contractsData[_contractAddress].registredAt > 0, ContractNotRegistered());
        contractsData[_contractAddress].isActive = true;
        emit ContractStatusUpdated(_contractAddress, true, block.timestamp);
    }
}