// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721ABurnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ApyTopLifetimePass is ERC721A, ERC721ABurnable, Ownable {
    uint256 public mintPrice = 100000000000000000;

    uint256 public maxSupply = 1024;

    string public metadataURI = "https://api.apy.top/pass/lifetimePass/";

    address public contractReceiver;

    constructor() ERC721A("ApyTopLifetimePass", "ATLP") {
        contractReceiver = msg.sender;
    }

    // metadata uri

    function _baseURI() internal view override returns (string memory) {
        return metadataURI;
    }

    function setBaseURI(string calldata _uri) public onlyOwner {
        metadataURI = _uri;
    }

    // mint price

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    // receiver

    function setContractReceiver(address _receiver) external onlyOwner {
        contractReceiver = _receiver;
    }

    // max supply

    function setMaxSupply(uint256 _supply) external onlyOwner {
        maxSupply = _supply;
    }

    // pass management

    function mint() external payable {
        require(totalSupply() < maxSupply, "sold out");
        require(msg.value >= mintPrice, "insufficient value");

        _mint(msg.sender, 1);
    }

    function mintByOwner(uint256 quantity) external onlyOwner {
        _mint(msg.sender, quantity);
    }

    function airdropByOwner(
        address[] calldata _addresses,
        uint8[] calldata _counts
    ) external onlyOwner {
        for (uint32 i = 0; i < _addresses.length; ++i) {
            _mint(_addresses[i], _counts[i]);
        }
    }

    function extract() external onlyOwner {
        payable(contractReceiver).transfer(address(this).balance);
    }
}
