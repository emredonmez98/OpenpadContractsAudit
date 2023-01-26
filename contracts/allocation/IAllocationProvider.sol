// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

interface IAllocationProvider {
    /**
     * @dev Returns alloaction in USD
     */
    function allocation() external view returns (uint256);

    /**
     * @dev Returns alloaction in USD of `_account`
     * @param _account Account to check
     */
    function allocationOf(address _account) external view returns (uint256);

    /**
     * @dev Returns total allocation in USD
     */
    function totalAllocation() external view returns (uint256);
}
