// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

interface IVesting {
    event Claimed(address account, uint256 amount);

    /**
     * @dev Transfers currently claimable tokens to the sender emits
     * {Claimed} event.
     */
    function claim() external;

    /**
     * @dev Returns amount of tokens that can be claimed by `_account`
     */
    function claimableOf(address _account) external view returns (uint256);

    /**
     * @dev Returns total amount of tokens that can be claimed by `_account`
     */
    function totalClaimableOf(address _account) external view returns (uint256);

    /**
     * @dev Returns amount of tokens that has been claimed by `_account`
     */
    function claimedOf(address _account) external view returns (uint256);
}
