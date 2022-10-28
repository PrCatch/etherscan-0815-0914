// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface ERANFT {
    function claim(address to, uint256 tokenId) external;
}
