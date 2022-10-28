// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./nf-token-metadata.sol";
import "./ownable.sol";

/**
 * @dev This is an example contract implementation of NFToken with metadata extension.
 */
contract MyArtSale is
  NFTokenMetadata,
  Ownable
{
   mapping(uint256 => address) private _owners;

  /**
   * @dev Contract constructor. Sets metadata extension `name` and `symbol`.
   */
  constructor()
  {
    nftName = "MFP";
    nftSymbol = "DAYOU";
  }

  /**
   * @dev Mints a new NFT.
   * @param _to The address that will own the minted NFT.
   * @param _tokenId of the NFT to be minted by the msg.sender.
   * @param _uri String representing RFC 3986 URI.
   */
  function mint(
    address _to,
    uint256 _tokenId,
    string calldata _uri
  )
    external
    onlyOwner
  {
    super._mint(_to, _tokenId);
    super._setTokenUri(_tokenId, _uri);
  }
  


}