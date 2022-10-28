
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract BOBS is ERC721, Ownable {
    using Strings for uint;
    using Counters for Counters.Counter;
    enum SaleStatus{ PAUSED, PRESALE, PUBLIC }

    Counters.Counter private _tokenIds;

    uint public constant COLLECTION_SIZE = 5050;
    
    uint public constant TOKENS_PER_TRAN_LIMIT = 2;
    uint public constant TOKENS_PER_PERSON_PUB_LIMIT = 2;
    uint public constant TOKENS_PER_PERSON_WL_LIMIT = 3;
    uint public constant PRESALE_MINT_PRICE = 0.009 ether;
    uint public MINT_PRICE = 0.019 ether;
    SaleStatus public saleStatus = SaleStatus.PAUSED;
    bytes32 public merkleRoot = 0x22163b9f3b6a8f3bffebb48b903f332b64772a5756b0a7d3efa129440b77c77e;
    string private _baseURL;
    string public preRevealURL = "ipfs://bafyreiausodfnvrgyjlfblkwxxld3b7dfy6yaidekq4n4iq7jhgviajtma/metadata.json";
    mapping(address => uint) private _mintedCount;
    mapping(address => uint) private _whitelistMintedCount;

    constructor() ERC721("BOBS", "bobs"){}
    
    
    function contractURI() public pure returns (string memory) {
        return "https://zerocodenft.azurewebsites.net/api/marketplacecollections/879e7111-1116-4c2c-25ac-08da7efdc38f";
    }
    
    /// @notice Update the merkle tree root
    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
    }
    
    /// @notice Reveal metadata for all the tokens
    function reveal(string memory uri) external onlyOwner {
        _baseURL = uri;
    }
    
    /// @notice Set Pre Reveal URL
    function setPreRevealUrl(string memory url) external onlyOwner {
        preRevealURL = url;
    }
    

    function totalSupply() external view returns (uint) {
        return _tokenIds.current();
    }

    /// @dev override base uri. It will be combined with token ID
    function _baseURI() internal view override returns (string memory) {
        return _baseURL;
    }

    /// @notice Update current sale stage
    function setSaleStatus(SaleStatus status) external onlyOwner {
        saleStatus = status;
    }

    /// @notice Update public mint price
    function setPublicMintPrice(uint price) external onlyOwner {
        MINT_PRICE = price;
    }

    /// @notice Withdraw contract balance
    function withdraw() external onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No balance");
        payable(owner()).transfer(balance);
    }

    /// @notice Allows owner to mint tokens to a specified address
    function airdrop(address to, uint count) external onlyOwner {
        require(_tokenIds.current() + count <= COLLECTION_SIZE, "Request exceeds collection size");
        _mintTokens(to, count);
    }

    /// @notice Get token URI. In case of delayed reveal we give user the json of the placeholer metadata.
    /// @param tokenId token ID
    function tokenURI(uint tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory baseURI = _baseURI();

        return bytes(baseURI).length > 0 
            ? string(abi.encodePacked(baseURI, "/", tokenId.toString(), ".json")) 
            : preRevealURL;
    }
    
    function calcTotal(uint count) public view returns(uint) {
        require(saleStatus != SaleStatus.PAUSED, "BOBS: Sales are off");

        

        
        uint price = saleStatus == SaleStatus.PRESALE 
            ? PRESALE_MINT_PRICE 
            : MINT_PRICE;

        return count * price;
    }
    
    
    function redeem(bytes32[] calldata merkleProof, uint count) external payable {
        require(saleStatus != SaleStatus.PAUSED, "BOBS: Sales are off");
        require(_tokenIds.current() + count <= COLLECTION_SIZE, "BOBS: Number of requested tokens will exceed collection size");
        require(count <= TOKENS_PER_TRAN_LIMIT, "BOBS: Number of requested tokens exceeds allowance (2)");
        require(msg.value >= calcTotal(count), "BOBS: Ether value sent is not sufficient");
        if(saleStatus == SaleStatus.PRESALE) {
            require(_whitelistMintedCount[msg.sender] + count <= TOKENS_PER_PERSON_WL_LIMIT, "BOBS: Number of requested tokens exceeds allowance (3)");
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "BOBS: You are not whitelisted");
            _whitelistMintedCount[msg.sender] += count;
        }
        else {
            require(_mintedCount[msg.sender] + count <= TOKENS_PER_PERSON_PUB_LIMIT, "BOBS: Number of requested tokens exceeds allowance (2)");
            _mintedCount[msg.sender] += count;
        }
        _mintTokens(msg.sender, count);
    }
    
    /// @dev Perform actual minting of the tokens
    function _mintTokens(address to, uint count) internal {
        for(uint index = 0; index < count; index++) {

            _tokenIds.increment();
            uint newItemId = _tokenIds.current();

            _safeMint(to, newItemId);
        }
    }
}
