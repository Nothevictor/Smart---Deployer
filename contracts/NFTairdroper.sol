// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract ERC721Airdroper is ERC721, Ownable {
    uint256 public nextTokenId;
    address public airdropReceiver;

    constructor(string memory name, string memory symbol, address _airdropReceiver)
        ERC721(name, symbol)
        Ownable(msg.sender)
    {
        require(_airdropReceiver != address(0), "Invalid airdrop receiver address");
        nextTokenId = 1;
        airdropReceiver = _airdropReceiver;
    }

    
    function airdrop(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");

        for (uint256 i = 0; i < amount; i++) {
            _safeMint(airdropReceiver, nextTokenId);
            nextTokenId++;
        }
    }

    
    function airdropToMultiple(address[] calldata receivers) external onlyOwner {
        require(receivers.length > 0, "No receivers specified");

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


contract ERC721AirdroperFactory {
    address[] public deployedAirdropers;
    event AirdroperCreated(address indexed airdroperAddress, string name, string symbol, address airdropReceiver);

    function createAirdroper(
        string calldata name,
        string calldata symbol,
        address airdropReceiver
    ) external returns (address) {
        require(airdropReceiver != address(0), "Invalid airdrop receiver address");

        ERC721Airdroper newAirdroper = new ERC721Airdroper(name, symbol, airdropReceiver);
        newAirdroper.transferOwnership(msg.sender);
        deployedAirdropers.push(address(newAirdroper));

        emit AirdroperCreated(address(newAirdroper), name, symbol, airdropReceiver);
        return address(newAirdroper);
    }

    function getDeployedAirdropers() external view returns (address[] memory) {
        return deployedAirdropers;
    }

    function getAirdroperCount() external view returns (uint256) {
        return deployedAirdropers.length;
    }
}