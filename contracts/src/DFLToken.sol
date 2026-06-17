// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title DeFi Labs Governance & Utility Token
 * @author 0xAvp
 * @notice Production-ready ERC-20 token with EIP-2612 permit support and role-based minting.
 * @dev Inherits OpenZeppelin's ERC20, ERC20Permit, and AccessControl.
 *      The Diamond contract (or Liquidity Portal facet) must be granted the MINTER_ROLE
 *      to mint new tokens in exchange for deposited testnet gas.
 */
contract DFLToken is ERC20, ERC20Permit, ERC20Burnable, AccessControl {
    /// @notice Access control role for accounts/contracts allowed to mint new tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @notice Initializes the DFL token contract
     * @dev Grants the DEFAULT_ADMIN_ROLE to the deployer.
     *      Initializes the ERC-20 standard fields and EIP-712 domain separator for permits.
     * @param defaultAdmin Address of the deployer/multisig to manage access control roles
     */
    constructor(address defaultAdmin)
    ERC20("DeFi Labs Token", "DFL")
    ERC20Permit("DeFi Labs Token")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    /**
     * @notice Mints new DFL tokens to a specified recipient
     * @dev Only accounts or contracts with the MINTER_ROLE can call this function.
     *      Typically called by the Diamond proxy contract when gas is deposited.
     * @param to Address of the recipient who will receive the minted tokens
     * @param amount Amount of DFL tokens to mint (in wei)
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice Boilerplate override to resolve interface compatibility conflicts
     * @dev Compiles standard ERC-165 interface detection between AccessControl and ERC-20.
     * @param interfaceId The interface identifier to check
     * @return True if the contract supports the interface, false otherwise
     */
    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(AccessControl)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}