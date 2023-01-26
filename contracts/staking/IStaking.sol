// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

/**
 * @dev Interface of OPN Staking.
 */
interface IStaking {
    /**
     * @dev Emitted when a user stakes `_amount` of tokens.
     */
    event Staked(address _from, uint256 _amount);

    /**
     * @dev Emitted when a user withdraws `_amount` of tokens.
     */
    event Withdrawn(address _from, uint256 _amount);

    /**
     * @dev Emitted when a user claims rewards.
     */
    event RewardClaimed(address _from, uint256 _amount);

    /**
     * @dev Stakes `_amount` of tokens.
     * @param _amount Amount of tokens to stake.
     *
     * Emits a {Staked} event.
     */
    function stake(uint256 _amount) external;

    /**
     * @dev Withdraws `_amount` of tokens.
     * @param _amount Amount of tokens to withdraw.
     *
     * Emits a {Withdrawn} event.
     */
    function withdraw(uint256 _amount) external;

    /**
     * @dev Claims rewards.
     *
     * Emits a {RewardClaimed} event.
     */
    function claimReward() external;

    /**
     * @dev Returns the amount of tokens staked by `_address`.
     * @param _address Address to check.
     */
    function stakedOf(address _address) external view returns (uint256);

    /**
     * @dev Returns the amount of rewards earned by `_address`.
     * @param _address Address to check.
     */
    function rewardOf(address _address) external view returns (uint256);

    /**
     * @dev Returns the total amount of tokens staked.
     */
    function totalStaked() external view returns (uint256);

    /**
     * @dev Returns the total amount of rewards a wallet has generated. Including claimed rewards.
     */
    function getTotalRewardsGenerated(address _address) external view returns(uint256);

    /**
     * @dev Returns the number of participants.
     */
    function numberOfParticipants() external view returns (uint256);

    /**
     * @dev Returns the addresses between `_start` and `_end`.
     */
    function addresses(uint256 _start, uint256 _end) external view returns (address[] memory);
}
