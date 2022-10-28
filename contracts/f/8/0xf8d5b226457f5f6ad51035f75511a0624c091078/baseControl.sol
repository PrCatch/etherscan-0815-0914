// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./AccessControl.sol";
import "./Ownable.sol";

contract BaseControl is AccessControl, Ownable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setRole(bytes32 role_, address account_)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(role_, account_);
    }
}