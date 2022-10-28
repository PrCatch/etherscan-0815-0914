// SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.7.6;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableMapUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts/proxy/IBeacon.sol";

import "../interfaces/ITransferGatekeeper.sol";
import "../interfaces/IRoyaltyAwareNFT.sol";

/// @title BaseEnigmaNFT1155
///
/// @dev This contract is a ERC1155 burnable and upgradable based in openZeppelin v3.4.0.
///         Be careful when upgrade, you must respect the same storage.

abstract contract BaseEnigmaNFT1155 is IRoyaltyAwareNFT, ERC1155BurnableUpgradeable, OwnableUpgradeable {
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.UintToAddressMap;
    using StringsUpgradeable for uint256;

    /* Storage */
    // mapping from token ID to account balances.
    // FIXME: It doesn make much sense for the user one. Check if it can be removed without breaking storage layout
    mapping(uint256 => address) internal creators;
    //mapping for token royaltyFee
    mapping(uint256 => uint256) private _royaltyFee;
    //mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;
    //mapping for token owners
    EnumerableMapUpgradeable.UintToAddressMap private _tokenOwners;

    //tokens base uri
    string public tokenURIPrefix;

    string private _name;

    string private _symbol;

    //token id counter, increase by 1 for each new mint
    uint256 public newItemId;

    // Transfer Gatekeeper with logic to allow token transfers
    IBeacon public transferGatekeeperBeacon;

    /* events */
    event TokenBaseURI(string value);

    /* functions */

    /**
     * @notice Initialize NFT1155 contract.
     *
     * @param name_ the token name
     * @param symbol_ the token symbol
     * @param tokenURIPrefix_ the toke base uri
     */
    function _initialize(
        string memory name_,
        string memory symbol_,
        string memory tokenURIPrefix_
    ) internal initializer {
        __ERC1155_init(tokenURIPrefix_);
        __ERC1155Burnable_init();
        __Ownable_init();

        _name = name_;
        _symbol = symbol_;
        newItemId = 1;
        _setTokenURIPrefix(tokenURIPrefix_);
    }

    /// oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line
    constructor() initializer {}

    function name() external view virtual returns (string memory) {
        return _name;
    }

    function symbol() external view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Internal function to set the token URI for a given token.
     * Reverts if the token ID does not exist.
     * @param tokenId_ uint256 ID of the token to set its URI
     * @param uri_ string URI to assign
     */
    function _setTokenURI(uint256 tokenId_, string memory uri_) internal {
        _tokenURIs[tokenId_] = uri_;
    }

    /**
     * @notice Get the royalty associated with tokenID.
     * @param tokenId ID of the Token.
     * @return royaltyFee of given ID.
     */
    function royaltyFee(uint256 tokenId) external view virtual override returns (uint256) {
        return _royaltyFee[tokenId];
    }

    /**
     * @dev Internal function to set the token URI for all the tokens.
     * @param _tokenURIPrefix string memory _tokenURIPrefix of the tokens.
     */
    function _setTokenURIPrefix(string memory _tokenURIPrefix) internal {
        tokenURIPrefix = _tokenURIPrefix;
        emit TokenBaseURI(_tokenURIPrefix);
    }

    /**
     * @dev Returns an URI for a given token ID.
     * Throws if the token ID does not exist. May return an empty string.
     * @param tokenId uint256 ID of the token to query
     */
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        require(_exists(tokenId), "ERC1155Metadata: URI query for nonexistent token");
        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = tokenURIPrefix;

        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view override returns (string memory) {
        return tokenURI(id);
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _tokenOwners.contains(tokenId);
    }

    /**
     * @notice Get the balance of an account's Tokens.
     * @param account The address of the token holder
     * @param tokenId ID of the Token
     * @return The owner's balance of the Token type requested
     */

    function balanceOf(address account, uint256 tokenId) public view override returns (uint256) {
        require(_exists(tokenId), "ERC1155Metadata: balance query for nonexistent token");
        return super.balanceOf(account, tokenId);
    }

    /**
     * @notice call transfer fucntion after check transfer gatekeeper allowance
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        bytes memory allData = abi.encode("1155", tokenId, amount, data);
        ITransferGatekeeper transferGatekeeper = ITransferGatekeeper(transferGatekeeperBeacon.implementation());
        require(transferGatekeeper.canTransfer(from, to, _msgSender(), allData), "Transfer not approved");
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    /**
     * @notice call transfer fucntion after check transfer gatekeeper allowance
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        bytes memory allData = abi.encode("1155_batch", ids, amounts, data);
        ITransferGatekeeper transferGatekeeper = ITransferGatekeeper(transferGatekeeperBeacon.implementation());
        require(transferGatekeeper.canTransfer(from, to, _msgSender(), allData), "Batch transfer not approved");
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Internal function to mint a new token.
     * Reverts if the given token ID already exists.
     * @param supply_ uint256 supply of the token to be minted
     * @param uri_ string memory URI of the token to be minted
     * @param fee_ uint256 royalty of the token to be minted
     */
    function _mintNew(
        address recipient,
        uint256 tokenId,
        uint256 supply_,
        string memory uri_,
        uint256 fee_
    ) internal returns (uint256) {
        require(!_exists(tokenId), "ERC1155: token already minted");

        require(_tokenOwners.set(tokenId, recipient), "ERC1155: token already minted");
        require(supply_ != 0, "Supply should be positive");
        require(bytes(uri_).length > 0, "uri should be set");

        _mint(recipient, tokenId, supply_, "");
        _setTokenURI(tokenId, uri_);
        emit URI(uri_, tokenId);

        _royaltyFee[tokenId] = fee_;

        return tokenId;
    }

    function _increaseNextId() internal returns (uint256) {
        uint256 tokenCounter = newItemId;
        newItemId = newItemId + 1;
        return tokenCounter;
    }

    /**
     * @notice call burn function after check that token exists
     */
    function _burn(
        address account,
        uint256 tokenId,
        uint256 amount
    ) internal virtual override {
        require(_exists(tokenId), "ERC1155Metadata: burn query for nonexistent token");
        super._burn(account, tokenId, amount);
    }

    /**
     * @notice burn tokens to msg.sender
     */
    function burn(uint256 tokenId, uint256 amount) external {
        _burn(msg.sender, tokenId, amount);
    }

    /**
     * @dev external function to set the token URI for all the tokens.
     * @param baseURI_ string memory _tokenURIPrefix of the tokens.
     */
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _setTokenURIPrefix(baseURI_);
    }

    /**
     * @notice Set a transferGatekeeperBeacon that points to the gatekeeper implementation
     * @param transferGatekeeperBeacon_ The IBeacon instance
     */
    function setTransferGatekeeperBeacon(IBeacon transferGatekeeperBeacon_) external onlyOwner {
        transferGatekeeperBeacon = transferGatekeeperBeacon_;
    }
}
