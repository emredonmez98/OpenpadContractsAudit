// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/interfaces/IProjectSale.sol";
import "contracts/allocation/IAllocationProvider.sol";
import "contracts/kyc/IKYCProvider.sol";
import "contracts/SplittedVesting.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "contracts/allocation/StakingAllocationProvider.sol";

contract ProjectSale is IProjectSale, ReentrancyGuard, Pausable, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    enum SaleStatus {
        NOT_FINALIZED, 
        FINALIZED
    }

    SaleStatus private _saleStatus;
    uint256 private constant PUBLIC_ROUND_FEE = 5; // 5%
    uint256 private _totalFee;

    IKYCProvider public immutable kycProvider;
    IAllocationProvider public immutable allocationProvider;
    SplittedVesting public immutable splitter;

    address public immutable creditReserve;
    IERC20 public immutable creditToken;
    IERC20 public immutable usdToken;
    IERC20 public immutable projectToken;
    uint256 public immutable totalSaleValueCap;
    uint256 public immutable projectTokenPrice;
    uint256 public immutable projectTokenAmount;
    address public immutable saleClaimAddress;
    address public immutable feeClaimAddress;
    uint256 public totalSaleValue;

    EnumerableMap.AddressToUintMap private _depositBalances;

    address private _vestingContract;
    mapping(address => bool) private _isRegistered;

    constructor(
        uint256 _registerStart,
        uint256 _registerEnd,
        uint256 _stakingRoundStart,
        uint256 _stakingRoundEnd,
        uint256 _publicRoundStart,
        uint256 _publicRoundEnd,
        uint256 _vestingStart,
        uint256 _vestingEnd,
        address _allocationProvider,
        address _kycProvider,
        address _creditReserve,
        address _creditToken,
        address _usdToken,
        address _projectToken,
        uint256 _projectTokenPrice,
        uint256 _projectTokenAmount,
        uint256 _totalSaleValueCap,
        address _saleClaimAddress,
        address _feeClaimAddress
    )
        IProjectSale(
            _registerStart,
            _registerEnd,
            _stakingRoundStart,
            _stakingRoundEnd,
            _publicRoundStart,
            _publicRoundEnd,
            _vestingStart,
            _vestingEnd
        )
    {
        require(
            (_projectTokenPrice * _projectTokenAmount) / 1e18 ==
                _totalSaleValueCap,
            "ProjectSale: invalid sale value"
        );

        // Sale Details
        creditReserve = _creditReserve;
        creditToken = IERC20(_creditToken);
        usdToken = IERC20(_usdToken);
        projectToken = IERC20(_projectToken);
        totalSaleValueCap = _totalSaleValueCap;
        projectTokenPrice = _projectTokenPrice;
        projectTokenAmount = _projectTokenAmount;
        _saleStatus = SaleStatus.NOT_FINALIZED;

        // External providers for allocation and KYC
        kycProvider = IKYCProvider(_kycProvider);
        allocationProvider = IAllocationProvider(_allocationProvider); //@audit-issue fix this

        feeClaimAddress = _feeClaimAddress;
        saleClaimAddress = _saleClaimAddress;

        // Create the splitting vesting contract
        uint256 durationInSec = vestingEnd - vestingStart;
        splitter = new SplittedVesting(
            address(projectToken),
            uint64(vestingStart),
            uint64(durationInSec)
        );
        _vestingContract = address(splitter);
    }

    modifier onlyWhiteListed(address _account) {
        require(
            kycProvider.isWhitelisted(_account),
            "ProjectSale: account is not whitelisted"
        );
        _;
    }

    modifier onlyOnce() {
        require(_saleStatus == SaleStatus.NOT_FINALIZED, "ProjectSale: sale is finalized");
        _;
        _saleStatus = SaleStatus.FINALIZED;
    }

    function register()
        public
        override
        nonReentrant
        whenNotPaused
        onlyWhiteListed(msg.sender) // @audit-issue move to deposit. Can ile konus. kim icin allocation acacagiz
        onlyDuringRegisteration
    {
        require(!isRegistered(msg.sender), "ProjectSale: already registered");
        _isRegistered[msg.sender] = true;

        emit Registered(msg.sender);
    }

    function isRegistered(address _account)
        public
        view
        override
        returns (bool)
    {
        return _isRegistered[_account];
    }

    function _remaingAllocationOf(address _account)
        internal
        view
        returns (uint256)
    {
        uint256 remainingAllocation = allocationProvider.allocationOf(_account)
            .mul(totalSaleValueCap)
            .div(allocationProvider.totalAllocation());
        (bool success, uint256 _deposited) = _depositBalances.tryGet(_account);
        if (success) {
            return remainingAllocation.sub(_deposited);
        }
        return remainingAllocation;
    }

    function creditDeposit(uint256 _amount) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyWhiteListed(msg.sender) 
    {
        require(_amount > 0, "ProjectSale: amount is zero");
        require(
            (isStakingRound() && isRegistered(msg.sender)) || isPublicRound(),
            "ProjectSale: not allowed to deposit"
        );
        uint256 depositableAmount = creditToken.balanceOf(msg.sender);
        require(
            _amount <= depositableAmount,
            "ProjectSale: amount exceeds depositable amount"
        );

        (bool found, uint256 _deposited) = _depositBalances.tryGet(msg.sender);
        if (found) {
            _depositBalances.set(msg.sender, _deposited + _amount);
            splitter._updateShares(msg.sender, _deposited + _amount);
        } else {
            _depositBalances.set(msg.sender, _amount);
            splitter._addPayee(msg.sender, _amount);
        }
        totalSaleValue += _amount;
        creditToken.safeTransferFrom(msg.sender, creditReserve, _amount);
        usdToken.safeTransferFrom(creditReserve, saleClaimAddress, _amount);
    }

    /**
     * @dev Deposits from whitelisted account are alowed if it is staking round and
     * the account is registered or it is during public round.
     */
    function deposit(uint256 _amount)
        public
        override
        nonReentrant
        whenNotPaused
        onlyWhiteListed(msg.sender)
    {
        require(_amount > 0, "ProjectSale: amount is zero");
        require(
            (isStakingRound() && isRegistered(msg.sender)) || isPublicRound(),
            "ProjectSale: not allowed to deposit"
        );
        uint256 depositableAmount = depositableOf(msg.sender);
        require(
            _amount <= depositableAmount,
            "ProjectSale: amount exceeds depositable amount"
        );

        uint256 fee;
        if(isPublicRound()) {
            fee = (_amount * PUBLIC_ROUND_FEE) / 100; //@audit-issue add check for underflow
            _amount -= fee;
            _totalFee += fee; // @audit-issue unnecessary, remove.
        }//@audit-issue wrong calculation on fee, infinite allocation remaining. Take fee plus amount

        (bool found, uint256 _deposited) = _depositBalances.tryGet(msg.sender);
        if (found) {
            _depositBalances.set(msg.sender, _deposited + _amount);
            splitter._updateShares(msg.sender, _deposited + _amount);
        } else {
            _depositBalances.set(msg.sender, _amount);
            splitter._addPayee(msg.sender, _amount);
        }
        totalSaleValue += _amount;
        usdToken.safeTransferFrom(msg.sender, saleClaimAddress, _amount);
        usdToken.safeTransferFrom(msg.sender, feeClaimAddress, fee);
    }

    function deposited() public view override returns (uint256) {
        return depositedOf(msg.sender);
    }

    function depositedOf(address _account)
        public
        view
        override
        returns (uint256)
    {
        (bool success, uint256 _deposited) = _depositBalances.tryGet(_account);
        if (success) {
            return _deposited;
        }
        return 0;
    }

    function depositable() public view override returns (uint256) {
        return depositableOf(msg.sender);
    }

    function depositableOf(address _account)
        public
        view
        override
        returns (uint256)
    {
        if (!kycProvider.isWhitelisted(_account)) {
            return 0;
        }
        if (isRegistered(_account) && isStakingRound()) {
            return _remaingAllocationOf(_account);
        } else if (isPublicRound()) {
            return totalSaleValueCap - totalSaleValue;
        } else {
            return 0;
        }
    }

    function vestingContract() public view returns (bool, address) {
        if (_saleStatus == SaleStatus.NOT_FINALIZED) {
            return (false, address(0));
        }
        return (true, _vestingContract);
    }

    function finalizeSale() public onlyOwner onlyOnce {
        require(
            block.timestamp > publicRoundEnd,
            "ProjectSale: sale is not over"
        );
        _pause();

        // Transfer the tokens to the splitter
        uint256 tokensSold = totalSaleValue.div(projectTokenPrice).mul(1e18);
        projectToken.safeTransferFrom(
            msg.sender,
            address(splitter.getVestingWallet()),
            tokensSold
        );
    }
}
