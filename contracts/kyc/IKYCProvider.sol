// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

interface IKYCProvider {
    /**
     * @dev Returns true if `_account` is KYC approved
     * @param _account Account to check
     */
    function isWhitelisted(address _account) external view returns (bool);
}
