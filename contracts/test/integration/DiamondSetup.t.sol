// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/Diamond.sol";
import "diamond-3-hardhat/contracts/facets/DiamondCutFacet.sol";
import "diamond-3-hardhat/contracts/facets/DiamondLoupeFacet.sol";
import "diamond-3-hardhat/contracts/interfaces/IDiamondCut.sol";
import "diamond-3-hardhat/contracts/interfaces/IDiamondLoupe.sol";

/**
 * @title Diamond Setup Fixture
 * @notice Reusable deployment state for Diamond integration testing.
 * @dev Other integration tests will inherit from this contract to get a pre-deployed Diamond.
 */
abstract contract DiamondSetup is Test {
    Diamond public diamond;
    DiamondCutFacet public cutFacet;
    DiamondLoupeFacet public loupeFacet;

    address public admin = address(0xAD);
    address public user = address(0x22);

    /**
     * @notice Deploys and configures the Diamond proxy with core system facets
     */
    function setUp() public virtual {
        // 1. Deploy the DiamondCutFacet (needed for the Diamond constructor)
        cutFacet = new DiamondCutFacet();

        // 2. Deploy the core Diamond proxy, passing the admin and cutFacet
        vm.prank(admin);
        diamond = new Diamond(admin, address(cutFacet));

        // 3. Deploy the DiamondLoupeFacet (needed for system introspection/checks)
        loupeFacet = new DiamondLoupeFacet();

        // 4. Register the Loupe functions in the Diamond via diamondCut
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](4);

        selectors[0] = IDiamondLoupe.facets.selector;
        selectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[2] = IDiamondLoupe.facetAddresses.selector;
        selectors[3] = IDiamondLoupe.facetAddress.selector;

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        vm.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }
}