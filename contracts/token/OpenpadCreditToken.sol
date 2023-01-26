// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract OpenpadCreditToken is ERC20, ERC20Burnable, AccessControl  {
    bytes32 public constant PROJECT_SALE_ROLE = keccak256("PROJECT_SALE_ROLE");

    constructor() ERC20("OpenpadCreditToken", "OCT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROJECT_SALE_ROLE, msg.sender);
    }

    function grantProjectSale(address _projectSale) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(PROJECT_SALE_ROLE, _projectSale);
    }

    function revokeProjectSale(address _projectSale) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(PROJECT_SALE_ROLE, _projectSale);
    }

    function mint(address to, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        onlyRole(PROJECT_SALE_ROLE)
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}