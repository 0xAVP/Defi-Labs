// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IDFLToken Interface
 * @notice Extends standard IERC20 to include minting and burning permissions.
 */
interface IDFLToken is IERC20 {
    /**
     * @notice Mints new tokens to a specified recipient.
     * @dev Restrict access via MINTER_ROLE in the implementation.
     * @param to The recipient address.
     * @param amount The amount of tokens to mint (in wei).
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Burns tokens from a specified account.
     * @dev Requires prior allowance approval.
     * @param account The account to burn tokens from.
     * @param value The amount of tokens to burn (in wei).
     */
    function burnFrom(address account, uint256 value) external;
}