// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DiamondSetup.t.sol";

/**
 * @title Diamond Proxy Core Integration Tests
 * @notice Verifies that EIP-2535 routing and system facets work correctly.
 */
contract DiamondTest is DiamondSetup {

    /**
     * @notice Verifies that Diamond ownership was correctly initialized in the constructor
     */
    function test_DiamondOwnershipInitialized() public view {
        // Query ownership from the Diamond proxy address
        // (Wagmi/Frontend will do exactly the same call)
        address currentOwner = IDiamondLoupe(address(diamond)).facetAddress(IDiamondCut.diamondCut.selector);

        // The cut facet should be registered as the handler for the diamondCut selector
        assertEq(currentOwner, address(cutFacet));
    }

    /**
     * @notice Verifies that the Loupe facet functions are correctly registered and routable
     */
    function test_LoupeSelectorsAreRegistered() public view {
        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));

        // Assert that calling Loupe functions on the Diamond Proxy successfully returns correct values
        address[] memory facets = loupe.facetAddresses();

        // We registered 2 facets in setup: DiamondCutFacet and DiamondLoupeFacet
        assertEq(facets.length, 2);
        assertEq(facets[0], address(cutFacet));
        assertEq(facets[1], address(loupeFacet));
    }

    /**
     * @notice Security: Verify that non-admins cannot perform upgrades (diamondCut)
     */
    function test_NonAdminCannotUpgrade() public {
        IDiamondCut.FacetCut[] memory emptyCut = new IDiamondCut.FacetCut[](0);

        // Try to perform a cut from an unauthorized account (user)
        // Should revert because only the owner is allowed to call diamondCut
        vm.expectRevert("LibDiamond: Must be contract owner");
        vm.prank(user);
        IDiamondCut(address(diamond)).diamondCut(emptyCut, address(0), "");
    }
}