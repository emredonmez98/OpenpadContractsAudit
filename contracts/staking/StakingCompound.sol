// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "contracts/staking/IStaking.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

contract StakingCompound is
    IStaking,
    Ownable,
    Pausable,
    ReentrancyGuard,
    KeeperCompatibleInterface
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    event AutoCompounded(address _from, uint256 _amount);

    IERC20 public immutable token;

    address private feeRecipient;
    uint256 private stakeFee;
    uint256 private withdrawFee;

    uint256 private rewardRate;
    uint256 private lastUpdateTime;
    uint256 private rewardPerTokenStored;

    address private stakingBank;

    mapping(address => uint256) private userRewardPerTokenPaid;
    mapping(address => uint256) private userTotalRewardsGenerated;
    mapping(address => uint256) private rewards;

    uint256 private _totalStaked;
    EnumerableMap.AddressToUintMap private _balances;

    // Auto Compounding mechanism variables
    bool private iterationActive = false;
    uint256 private autoCompoundIndex;
    uint256 private addressCountPerIteartion = 100; 

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
        require(_stakingBank != address(0), "StakingCompund: staking bank address cannot be 0");
        stakingBank = _stakingBank;
    }

    function setFeeDetails(
        address _recipient,
        uint256 _stakeFee,//%100
        uint256 _withdrawFee//%100
    ) external onlyOwner {
        feeRecipient = _recipient;//@audit-info split to many addresses. Make payment splitter contract
        stakeFee = _stakeFee;
        withdrawFee = _withdrawFee;
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
            userTotalRewardsGenerated[account] += earned(account); //@audit-issue check again
        }
        _;
    }

    function stake(uint256 _amount)
        external
        override
        nonReentrant
        updateReward(msg.sender)
    {
        require(_amount > 0, "StakingCompound: stake amount must be greater than 0.");
        uint256 _feeAmount = (_amount * stakeFee) / 100;
        
        (bool contains, uint256 balance) = _balances.tryGet(msg.sender);
        if (contains) {
            _balances.set(msg.sender, balance.add(_amount - _feeAmount));
        } else {
            _balances.set(msg.sender, _amount - _feeAmount);
        }
        _totalStaked = _totalStaked.add(_amount - _feeAmount);
        
        token.safeTransferFrom(msg.sender, address(this), _amount);
        token.safeTransfer(feeRecipient, _feeAmount);

        emit Staked(msg.sender, _amount - _feeAmount);
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

        if (_amount == balance) {
            _balances.remove(msg.sender);
        } else {
            _balances.set(msg.sender, balance.sub(_amount));
        }
        _totalStaked = _totalStaked.sub(_amount);

        uint256 _feeAmount = (_amount * withdrawFee) / 100;
        token.safeTransfer(msg.sender, _amount - _feeAmount);
        token.safeTransfer(feeRecipient, _feeAmount);
        emit Withdrawn(msg.sender, _amount);
    }

    function claimReward() // @audit-info commission can be added here
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

    function autoCompound() public {
        uint256 usersLeft = _balances.length() - autoCompoundIndex;
        uint256 startIndex = autoCompoundIndex;
        uint256 remaingCount;
        if (usersLeft > addressCountPerIteartion) {
            iterationActive = true;
            autoCompoundIndex = autoCompoundIndex + addressCountPerIteartion;
            remaingCount = addressCountPerIteartion;
        } else {
            iterationActive = false;
            remaingCount = usersLeft;
            autoCompoundIndex = 0;
        }
        for (uint256 i = startIndex; i < startIndex + remaingCount; i++) {
            (address user, ) = _balances.at(i);
            _autoCompound(user);
        }
    }

    function _autoCompound(address _staker) internal updateReward(_staker) {
        uint256 userReward = earned(_staker); //@audit-issue add require for zero reward to save gas
        if (userReward > 0) {
            rewards[_staker] = 0;
            _totalStaked = _totalStaked.add(userReward);
            _balances.set(_staker, _balances.get(_staker).add(userReward));
            token.safeTransferFrom(stakingBank, address(this), userReward);
            emit AutoCompounded(_staker, userReward);
        }
    }

    function updateIterationNumber(uint256 iteration) external onlyOwner {
        addressCountPerIteartion = iteration;
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = iterationActive;
        return (upkeepNeeded, "");
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        if (iterationActive) {
            autoCompound();
        }
        // We don't use the performData in this example. The performData is generated by the Keeper's call to your checkUpkeep function
    }

    function numberOfParticipants() external view override returns (uint256) {
        return _balances.length();
    }

    function addresses(uint256 _start, uint256 _end) external override view returns (address[] memory) {
        uint256 length = _end - _start;
        address[] memory _addresses = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            (address user, ) = _balances.at(_start + i);
            _addresses[i] = user;
        }
        return _addresses;
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

    function getTotalRewardsGenerated(address _address)
        external
        view
        returns (uint256)
    {
        return userTotalRewardsGenerated[_address] + earned(_address);
    }

    function getAPR() external view returns (uint256) { //@audit - add apy
        if  (_totalStaked == 0) {
            return 0;
        }
        uint256 annualRewardPerToken = rewardRate
            .mul(365 * 24 * 60 * 60)
            .mul(1e18)
            .div(_totalStaked);
        uint256 percentage = annualRewardPerToken.mul(100);
        return percentage;
    }
}
