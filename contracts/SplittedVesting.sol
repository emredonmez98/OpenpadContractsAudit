// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

// @audit-issue add function to get all tokens back to initial owner
// @audit-issue which to montly linear
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "contracts/libraries/OpenpadPaymentSplitter.sol";
import "contracts/interfaces/IVesting.sol";

contract SplittedVesting is OpenpadPaymentSplitter, Ownable, Pausable, IVesting {
    VestingWallet private immutable vestingWallet;
    IERC20 private immutable token;

    constructor(
        address _token,
        uint64 _cliff,
        uint64 _durationInSec
    ) OpenpadPaymentSplitter() {
        require(_token != address(0), "Token address cannot be 0");
        require(_cliff >= block.timestamp, "Cliff cannot be in the past");
        require(_durationInSec > 0, "Duration cannot be 0");

        vestingWallet = new VestingWallet(
            address(this),
            _cliff,
            _durationInSec
        );
        token = IERC20(_token);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function claim() public override whenNotPaused {
        vestingWallet.release(address(token));
        uint256 payment = releasable(token, msg.sender);
        release(token, msg.sender);
        emit Claimed(msg.sender, payment);
    }

    function claimableOf(address _account) public view returns (uint256) {
        uint256 vestedAmount = vestingWallet.vestedAmount(
            address(token),
            uint64(block.timestamp)
        );
        return _shareOf(_account, vestedAmount) - claimedOf(_account);
    }

    function _shareOf(address _account, uint256 _amount)
        internal
        view
        returns (uint256)
    {
        return (_amount * shares(_account)) / totalShares();
    }

    function totalClaimableOf(address _account) public view returns (uint256) {
        uint256 vestingEnd = vestingWallet.start() + vestingWallet.duration();
        uint256 saleAmount = vestingWallet.vestedAmount(
            address(token),
            uint64(vestingEnd)
        );
        return _shareOf(_account, saleAmount);
    }

    function claimedOf(address _account) public view returns (uint256) {
        return released(token, _account);
    }

    function getVestingWallet() external view returns (address) {
        return address(vestingWallet);
    }

    function getTokenAddress() external view returns (address) {
        return address(token);
    }
}
