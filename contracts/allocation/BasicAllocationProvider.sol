// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/allocation/IAllocationProvider.sol";

contract BasicAllocationProvider is IAllocationProvider, Ownable {
    mapping(address => uint256) public _allocations;
    uint256 public _totalAllocation;

    function grantAllocation(address _account, uint256 _amount)
        public
        onlyOwner
    {
        _grantAllocation(_account, _amount);
    }

    function _grantAllocation(address _account, uint256 _amount) internal {
        require(_account != address(0), "AllocationProvider: zero address");
        require(_amount > 0, "AllocationProvider: zero allocation");
        uint256 current = _allocations[_account];
        _allocations[_account] = _amount;
        _totalAllocation = _totalAllocation + _amount - current;
    }

    function revokeAllocation(address _account) public onlyOwner {
        require(
            _allocations[_account] > 0,
            "AllocationProvider: no allocation"
        );
        _totalAllocation = _totalAllocation - _allocations[_account];
        _allocations[_account] = 0;
    }

    function allocation() external view returns (uint256) {
        return _allocations[msg.sender];
    }

    function allocationOf(address _account) external view returns (uint256) {
        return _allocations[_account];
    }

    function totalAllocation() external view returns (uint256) {
        return _totalAllocation;
    }
}
