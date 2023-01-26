// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/token/IDummyERC20.sol";

contract DummyERC20 is IDummyERC20, ERC20, ERC20Burnable, Ownable {
    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
        _approve(to, owner(), amount);
    }

    function batchMint(address[] memory to, uint256[] memory amount)
        public
        onlyOwner
    {
        require(
            to.length == amount.length,
            "DummyERC20: account and amount length mismatch"
        );
        for (uint256 i = 0; i < to.length; i++) {
            mint(to[i], amount[i]);
        }
    }

    function burn(uint256 amount) public override(ERC20Burnable, IDummyERC20) {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override(ERC20Burnable, IDummyERC20)
    {
        super.burnFrom(account, amount);
    }

    function batchBurnFrom(address[] memory from, uint256[] memory amount)
        public
    {
        require(
            from.length == amount.length,
            "DummyERC20: account and amount length mismatch"
        );
        for (uint256 i = 0; i < from.length; i++) {
            burnFrom(from[i], amount[i]);
        }
    }
}
