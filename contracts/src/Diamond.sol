// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LibDiamond } from "diamond-3-hardhat/contracts/libraries/LibDiamond.sol";
import { IDiamondCut } from "diamond-3-hardhat/contracts/interfaces/IDiamondCut.sol";

    error Diamond__FunctionDoesNotExist(bytes4 selector);

/**
 * @title EIP-2535 Diamond Proxy Contract
 * @author 0xAvp
 * @notice The core gateway contract. It holds all state and assets,
 *         routing all calls to facets via delegatecall.
 */
contract Diamond {

    /**
     * @notice Initializes the Diamond proxy by setting the owner and adding the initial DiamondCut facet
     * @dev The constructor executes the first "diamondCut" to register the upgrade function itself.
     * @param _contractOwner Address of the deployer/multisig to manage the Diamond
     * @param _diamondCutFacet Address of the pre-deployed DiamondCutFacet contract
     */
    constructor(address _contractOwner, address _diamondCutFacet) payable {
        // Set the owner in LibDiamond storage
        LibDiamond.setContractOwner(_contractOwner);

        // Prepare the first "diamondCut" to add the diamondCut function itself
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);

        // Selector of the "diamondCut" function
        functionSelectors[0] = IDiamondCut.diamondCut.selector;

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // Execute the cut to register DiamondCutFacet in the proxy
        LibDiamond.diamondCut(cut, address(0), "");
    }

    /**
     * @notice Fallback function that intercepts any incoming call and routes it to the matching facet
     * @dev Uses inline assembly to execute delegatecall and return values or revert.
     */
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;

        // Point to the system Diamond storage slot using assembly
        assembly {
            ds.slot := position
        }

        // Retrieve the facet address associated with the incoming function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;

        // Security check: Revert if the called function is not registered in the Diamond
        if (facet == address(0)) {
            revert Diamond__FunctionDoesNotExist(msg.sig);
        }

        // Execute the external function on the facet using delegatecall
        assembly {
        // Copy incoming function selector and arguments into memory
            calldatacopy(0, 0, calldatasize())

        // Execute the call on the facet, sharing the storage of this proxy
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)

        // Copy the return data
            returndatacopy(0, 0, returndatasize())

        // Return or revert depending on the execution outcome
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @notice Allows the contract to receive native ETH
     */
    receive() external payable {}
}