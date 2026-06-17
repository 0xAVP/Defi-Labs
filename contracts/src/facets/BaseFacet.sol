// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibAppStorage.sol";
import { LibDiamond } from "diamond-3-hardhat/contracts/libraries/LibDiamond.sol";

    error BaseFacet__SystemPaused();
    error BaseFacet__ReentrancyGuardTriggered();
    error BaseFacet__Unauthorized();

/**
 * @title Base Facet Contract
 * @author 0xAvp
 * @notice Abstract base contract providing shared modifiers and access controls for all Diamond facets.
 * @dev Facets should inherit from this contract to avoid code duplication and ensure uniform security controls.
 */
abstract contract BaseFacet {

    /**
     * @notice Prevents reentrancy attacks across all Diamond facets
     */
    modifier nonReentrant() {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        if (s.reentrancyStatus == 2) revert BaseFacet__ReentrancyGuardTriggered();
        s.reentrancyStatus = 2; // Set to Guarded
        _;
        s.reentrancyStatus = 1; // Reset to Active
    }

    /**
     * @notice Restricts execution to the Diamond owner using LibDiamond's native ownership check
     */
    modifier onlyOwner() {
        // We use the audited reference library from Nick Mudge to enforce ownership
        LibDiamond.enforceIsContractOwner();
        _;
    }

    /**
     * @notice Reverts if the system is globally paused
     */
    modifier whenNotPaused() {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        if (s.paused) revert BaseFacet__SystemPaused();
        _;
    }
}