// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

import "contracts/staking/IStaking.sol";
import "contracts/allocation/BasicAllocationProvider.sol";

contract StakingAllocationProvider is BasicAllocationProvider {
    IStaking public immutable staking;

    uint256 private alfa;
    uint256 private beta;

    constructor(address _staking, uint256 _alfa, uint256 _beta) {
        staking = IStaking(_staking);
        alfa = _alfa;
        beta = _beta;
    }

    function takeSnapshot(address[] memory _wallets) public onlyOwner {
        uint256 quad;
        for (uint256 i = 0; i < _wallets.length; i++) {
            quad = quadAllocation(_wallets[i]);
            grantAllocation(_wallets[i], quad);
        }
    }

    function quadAllocation(address _wallet) public view returns (uint256) { //@audit-info should we reset when there is no stake
        uint256 param1 = (staking.stakedOf(_wallet) * alfa) / 1e18;
        uint256 param2 = (staking.getTotalRewardsGenerated(_wallet) * beta) /
            1e18;
        uint256 quad = sqrt((param1 + param2) * 1e18);
        return quad;
    }

    function sqrt(uint256 y) public pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
