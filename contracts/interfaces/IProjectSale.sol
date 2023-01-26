// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

/**
 * @dev OpenPad Project Sale Interface
 */
abstract contract IProjectSale {
    uint256 public immutable registerStart;
    uint256 public immutable registerEnd;
    uint256 public immutable stakingRoundStart;
    uint256 public immutable stakingRoundEnd;
    uint256 public immutable publicRoundStart;
    uint256 public immutable publicRoundEnd;
    uint256 public immutable vestingStart;
    uint256 public immutable vestingEnd;

    constructor(
        uint256 _registerStart,
        uint256 _registerEnd,
        uint256 _stakingRoundStart,
        uint256 _stakingRoundEnd,
        uint256 _publicRoundStart,
        uint256 _publicRoundEnd,
        uint256 _vestingStart,
        uint256 _vestingEnd
    ) {
        registerStart = _registerStart;
        registerEnd = _registerEnd;
        stakingRoundStart = _stakingRoundStart;
        stakingRoundEnd = _stakingRoundEnd;
        publicRoundStart = _publicRoundStart;
        publicRoundEnd = _publicRoundEnd;
        vestingStart = _vestingStart;
        vestingEnd = _vestingEnd;
    }

    /**
     * @dev Emitted when `_account` registers to sale
     */
    event Registered(address _account);

    /**
     * @dev Emitted when `_account` deposits `_amount` USD pegged coin
     */
    event Deposit(address _account, uint256 _amount);

    /**
     * @dev Throws if block time isn't between `registerStart` and `registerEnd`
     */
    modifier onlyDuringRegisteration() {
        require(
            block.timestamp >= registerStart,
            "ProjectSale: registration period has not started yet"
        );
        require(
            block.timestamp <= registerEnd,
            "ProjectSale: registration period has ended"
        );
        _;
    }

    /**
     * @dev Returns true if time is between staking round
     * @return True if time is between staking round
     */
    function isStakingRound() public view returns (bool) {
        return
            block.timestamp >= stakingRoundStart &&
            block.timestamp <= stakingRoundEnd;
    }

    /**
     * @dev Returns true if time is between public round
     * @return True if time is between public round
     */
    function isPublicRound() public view returns (bool) {
        return
            block.timestamp >= publicRoundStart &&
            block.timestamp <= publicRoundEnd;
    }

    /**
     * @dev Register to sale
     *
     * Emits a {Registered} event.
     */
    function register() external virtual;

    /**
     * @dev Returns true if `_account` is registered
     * @param _account Account to check
     */
    function isRegistered(address _account)
        external
        view
        virtual
        returns (bool);

    /**
     * @dev Deposit USD
     * @param _amount Amount of USD to deposit.
     *
     * Emits a {Deposit} event.
     */
    function deposit(uint256 _amount) external virtual;

    /**
     * @dev Returns USD deposited by sender
     */
    function deposited() external view virtual returns (uint256);

    /**
     * @dev Returns USD deposited by `_account`
     * @param _account Account to check
     */
    function depositedOf(address _account)
        external
        view
        virtual
        returns (uint256);

    /**
     * @dev Returns depositable USD
     */
    function depositable() external view virtual returns (uint256);

    /**
     * @dev Returns depositable USD of `_account`
     * @param _account Account to check
     */
    function depositableOf(address _account)
        external
        view
        virtual
        returns (uint256);
}
