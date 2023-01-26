// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "contracts/kyc/IKYCProvider.sol";

contract BasicKYCProvider is AccessControl, IKYCProvider {
    using EnumerableSet for EnumerableSet.AddressSet;

    event Whitelisted(address indexed _account, uint256 _timestamp);
    event Blacklisted(address indexed _account, uint256 _timestamp);

    bytes32 public constant KYC_MANAGER = keccak256("KYC_MANAGER");

    EnumerableSet.AddressSet private whitelist;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(KYC_MANAGER, msg.sender);
    }

    function makeManager(address _account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        grantRole(KYC_MANAGER, _account);
    }

    function revokeManager(address _account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokeRole(KYC_MANAGER, _account);
    }

    function addToWhitelist(address _account) public onlyRole(KYC_MANAGER) {
        bool added = whitelist.add(_account);
        if (added) {
            emit Whitelisted(_account, block.timestamp);
        }
    }

    function removeFromWhitelist(address _account)
        public
        onlyRole(KYC_MANAGER)
    {
        bool removed = whitelist.remove(_account);
        if (removed) {
            emit Blacklisted(_account, block.timestamp);
        }
    }

    function isWhitelisted(address _account) external view returns (bool) {
        return whitelist.contains(_account);
    }

    function whitelisted() external view returns (address[] memory) {
        address[] memory _whitelist = new address[](whitelist.length());
        for (uint256 i = 0; i < whitelist.length(); i++) {
            _whitelist[i] = whitelist.at(i);
        }
        return _whitelist;
    }
}
