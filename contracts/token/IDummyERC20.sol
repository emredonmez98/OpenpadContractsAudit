// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDummyERC20 is IERC20 {
    function mint(address to, uint256 amount) external;

    function batchMint(address[] memory to, uint256[] memory amount) external;

    function burn(uint256 amount) external;

    function burnFrom(address from, uint256 amount) external;

    function batchBurnFrom(address[] memory from, uint256[] memory amount)
        external;
}
