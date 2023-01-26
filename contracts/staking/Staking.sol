// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "contracts/staking/IStaking.sol";

abstract contract Staking is IStaking, Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    IERC20 public immutable token;

    uint256 private rewardRate;
    uint256 private lastUpdateTime;
    uint256 private rewardPerTokenStored;

    address private stakingBank;

    mapping(address => uint256) private userRewardPerTokenPaid;
    mapping(address => uint256) private rewards;

    uint256 private _totalStaked;
    EnumerableMap.AddressToUintMap private _balances;

    constructor(
        address _stakingToken,
        address _stakingBank,
        uint256 _rewardRate
    ) {
        require(
            _stakingToken != address(0),
            "Staking token address cannot be 0"
        );
        require(_stakingBank != address(0), "Staking bank address cannot be 0");

        token = IERC20(_stakingToken);
        stakingBank = _stakingBank;
        rewardRate = _rewardRate;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function updateStakingBank(address _stakingBank) public onlyOwner {
        require(_stakingBank != address(0), "Staking bank address cannot be 0");
        stakingBank = _stakingBank;
    }

    function updateRewardRate(uint256 _rate)
        public
        onlyOwner
        updateReward(address(0))
    {
        rewardRate = _rate;
    }

    function rewardPerToken() private view returns (uint256) {
        if (_totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                (block.timestamp)
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(_totalStaked)
            );
    }

    function earned(address account) private view returns (uint256) {
        (bool contains, uint256 balance) = _balances.tryGet(account);
        if (!contains) {
            return 0;
        }
        return
            balance
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function stake(uint256 _amount)
        external
        override
        nonReentrant
        updateReward(msg.sender)
    {
        require(_amount > 0, "Stake amount must be greater than 0.");
        _totalStaked = _totalStaked.add(_amount);

        (bool contains, uint256 balance) = _balances.tryGet(msg.sender);
        if (contains) {
            _balances.set(msg.sender, balance.add(_amount));
        } else {
            _balances.set(msg.sender, _amount);
        }
        token.safeTransferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount)
        external
        override
        nonReentrant
        updateReward(msg.sender)
    {
        (bool contains, uint256 balance) = _balances.tryGet(msg.sender);
        require(contains, "Staking: no balance for account");
        require(
            _amount <= balance,
            "Staking: withdraw amount must be less than or equal to balance"
        );
        require(_amount > 0, "Staking: withdraw amount must be greater than 0");

        token.safeTransfer(msg.sender, _amount);
        if (_amount == balance) {
            _balances.remove(msg.sender);
        } else {
            _balances.set(msg.sender, balance.sub(_amount));
        }
        _totalStaked = _totalStaked.sub(_amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function claimReward()
        external
        override
        nonReentrant
        updateReward(msg.sender)
    {
        uint256 rewardAmount = rewards[msg.sender];
        if (rewardAmount > 0) {
            rewards[msg.sender] = 0;
            token.safeTransferFrom(stakingBank, msg.sender, rewardAmount);
            emit RewardClaimed(msg.sender, rewardAmount);
        }
    }

    function stakedOf(address _account)
        external
        view
        override
        returns (uint256)
    {
        (bool contains, uint256 balance) = _balances.tryGet(_account);
        if (contains) {
            return balance;
        }
        return 0;
    }

    function rewardOf(address _account)
        external
        view
        override
        returns (uint256)
    {
        return earned(_account);
    }

    function totalStaked() external view override returns (uint256) {
        return _totalStaked;
    }

    function currentlyStaked()
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256 length = _balances.length(); //@audit Possible DoS because of length size
        address[] memory accounts = new address[](length);
        uint256[] memory balances = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            (accounts[i], balances[i]) = _balances.at(i);
        }
        return (accounts, balances);
    }

    function getTotalRewardsGenerated(address _address)
        external
        pure
        returns (uint256)
    {
        require(_address != address(0), "Address cannot be 0");
        revert("Not implemented");
    }
}
