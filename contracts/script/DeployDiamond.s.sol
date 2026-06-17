// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Diamond.sol";
import "../src/DFLToken.sol";
import "../src/facets/AdminFacet.sol";
import "../src/facets/LiquidityPortalFacet.sol";
import "diamond-3-hardhat/contracts/facets/DiamondCutFacet.sol";
import "diamond-3-hardhat/contracts/facets/DiamondLoupeFacet.sol";
import "diamond-3-hardhat/contracts/interfaces/IDiamondCut.sol";
import "diamond-3-hardhat/contracts/interfaces/IDiamondLoupe.sol";

/**
 * @title DeployDiamond
 * @author 0xAvp
 * @notice Deploys and configures the complete Diamond system, facets, and DFLToken.
 */
contract DeployDiamond is Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy DiamondCutFacet (system)
        DiamondCutFacet cutFacet = new DiamondCutFacet();

        // 2. Deploy core Diamond Proxy, passing deployer as owner
        Diamond diamond = new Diamond(deployerAddress, address(cutFacet));

        // 3. Deploy system and DeFi facets
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        AdminFacet adminFacet = new AdminFacet();
        LiquidityPortalFacet portalFacet = new LiquidityPortalFacet();

        // 4. Prepare Diamond Cut to register Loupe, Admin, and LiquidityPortal facets
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        // Define Loupe Selectors
        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = IDiamondLoupe.facets.selector;
        loupeSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        loupeSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        selectorsConvert(IDiamondLoupe.facetAddress.selector, loupeSelectors, 3);

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // Define Admin Selectors
        bytes4[] memory adminSelectors = new bytes4[](4);
        adminSelectors[0] = AdminFacet.setChainConfig.selector;
        adminSelectors[1] = AdminFacet.setWithdrawFee.selector;
        adminSelectors[2] = AdminFacet.setDflToken.selector;
        adminSelectors[3] = AdminFacet.setPaused.selector;

        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(adminFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: adminSelectors
        });

        // Define LiquidityPortal Selectors
        bytes4[] memory portalSelectors = new bytes4[](4);
        portalSelectors[0] = LiquidityPortalFacet.depositGas.selector;
        portalSelectors[1] = LiquidityPortalFacet.getDflValue.selector;
        portalSelectors[2] = LiquidityPortalFacet.getGasValue.selector;
        portalSelectors[3] = LiquidityPortalFacet.redeemGas.selector;

        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(portalFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: portalSelectors
        });

        // 5. Execute Diamond Cut to register facets in Proxy
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        // 6. Deploy DFLToken setting deployer as admin
        DFLToken dflToken = new DFLToken(deployerAddress);

        // 7. Grant MINTER_ROLE of DFLToken to the Diamond Proxy
        dflToken.grantRole(keccak256("MINTER_ROLE"), address(diamond));

        // 8. Configure Diamond AppStorage parameters via AdminFacet
        AdminFacet adminContract = AdminFacet(address(diamond));
        adminContract.setDflToken(address(dflToken));

        // Configure local network settings: Diff = 100 (1.0x), Target balance = 5 ETH
        adminContract.setChainConfig(uint64(block.chainid), 100, 5 ether);

        // Configure base withdrawal fee (spread) to 5.00% (500 basis points)
        adminContract.setWithdrawFee(500);

        vm.stopBroadcast();

        console.log("-----------------------------------------");
        console.log("DEPLOYS SUCCESSFUL:");
        console.log("Diamond Proxy Address: ", address(diamond));
        console.log("DFLToken Address:      ", address(dflToken));
        console.log("-----------------------------------------");
    }

    function selectorsConvert(bytes4 _selector, bytes4[] memory _selectors, uint256 _index) internal pure {
        _selectors[_index] = _selector;
    }
}