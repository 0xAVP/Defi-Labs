// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DiamondSetup.t.sol";
import "../../src/DFLToken.sol";
import "../../src/facets/AdminFacet.sol";
import "../../src/facets/LiquidityPortalFacet.sol";

/**
 * @title Liquidity Portal Integration Tests
 * @author 0xAvp
 * @notice Verifies the complete lifecycle of gas deposits, dynamic scarcity pricing,
 *         and unified gas withdrawals inside the EIP-2535 Diamond proxy.
 */
contract LiquidityPortalTest is DiamondSetup {
    DFLToken public dflToken;
    AdminFacet public adminFacet;
    LiquidityPortalFacet public portalFacet;

    // Interface casts of the Diamond proxy
    AdminFacet public adminContract;
    LiquidityPortalFacet public portal;

    event GasDeposited(address indexed user, uint256 ethAmount, uint256 dflAmount, uint256 effectiveDifficulty);
    event GasRedeemedLocal(address indexed user, uint256 dflAmount, uint256 ethAmount, uint256 effectiveDifficulty);

    /**
     * @notice Set up the test state, deploying DFLToken, facets, and executing the cuts
     */
    function setUp() public override {
        super.setUp();

        dflToken = new DFLToken(admin);
        adminFacet = new AdminFacet();
        portalFacet = new LiquidityPortalFacet();

        // Register AdminFacet and LiquidityPortalFacet functions in the Diamond proxy
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);

        // Admin selectors
        bytes4[] memory adminSelectors = new bytes4[](4);
        adminSelectors[0] = AdminFacet.setChainConfig.selector;
        adminSelectors[1] = AdminFacet.setWithdrawFee.selector;
        adminSelectors[2] = AdminFacet.setDflToken.selector;
        adminSelectors[3] = AdminFacet.setPaused.selector;

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(adminFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: adminSelectors
        });

        // Portal selectors
        bytes4[] memory portalSelectors = new bytes4[](4);
        portalSelectors[0] = LiquidityPortalFacet.depositGas.selector;
        portalSelectors[1] = LiquidityPortalFacet.getDflValue.selector;
        portalSelectors[2] = LiquidityPortalFacet.getGasValue.selector;
        portalSelectors[3] = LiquidityPortalFacet.redeemGas.selector;

        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(portalFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: portalSelectors
        });

        vm.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        // Initialize interfaces
        adminContract = AdminFacet(address(diamond));
        portal = LiquidityPortalFacet(address(diamond));

        // Configure AppStorage parameters via AdminFacet
        vm.startPrank(admin);
        adminContract.setDflToken(address(dflToken));
        adminContract.setChainConfig(uint64(block.chainid), 100, 10 ether); // Target balance = 10 ETH
        adminContract.setWithdrawFee(500); // 5.00% withdrawal fee (spread)
        vm.stopPrank();

        // Grant MINTER_ROLE of DFLToken to the DIAMOND PROXY
        vm.prank(admin);
        dflToken.grantRole(keccak256("MINTER_ROLE"), address(diamond));
    }

    // ====================================================================
    // INTEGRATION TESTS
    // ====================================================================

    /**
     * @notice Test dynamic pricing during deposit when the pool is empty
     */
    function test_DepositWhenPoolIsEmptyMintsDouble() public {
        uint256 depositAmount = 1 ether;
        vm.deal(user, depositAmount);

        (uint256 expectedDfl, uint256 expectedDiff) = portal.getDflValue(depositAmount);
        assertEq(expectedDiff, 200); // 2.0x multiplier
        assertEq(expectedDfl, 2 ether); // 2 DFL

        vm.prank(user);
        portal.depositGas{value: depositAmount}();

        assertEq(dflToken.balanceOf(user), 2 ether);
        assertEq(address(diamond).balance, depositAmount);
    }

    /**
     * @notice Test local redeem: verifies burning DFL returns native gas with withdrawal penalty (spread)
     * @dev Step 1: Seed pool with target liquidity (10 ETH) to ensure stable math.
     *      Step 2: User deposits 1 ETH. Since pool is at target, difficulty is 100 (1.0x).
     *              User receives exactly 1 DFL.
     *      Step 3: User immediately redeems 1 DFL.
     *              Since pool is balanced, withdraw difficulty is 100 + 5% penalty = 105.
     *              User must receive exactly 0.9523 ETH, proving loop protection works!
     */
    function test_LocalRedeemAppliesSpreadAndWithdrawsGas() public {
        // Seed the Diamond Proxy with target liquidity (10 ETH)
        vm.deal(address(diamond), 10 ether);

        uint256 depositAmount = 1 ether;
        vm.deal(user, depositAmount);

        // 1. User deposits 1 ETH and gets exactly 1 DFL (since pool is funded)
        vm.prank(user);
        portal.depositGas{value: depositAmount}();
        uint256 userDflBalance = dflToken.balanceOf(user);
        assertEq(userDflBalance, 1 ether);

        // 2. User approves Diamond Proxy to spend/burn their DFL tokens
        vm.prank(user);
        dflToken.approve(address(diamond), userDflBalance);

        // 3. Query expected gas payout and effective difficulty before redeeming
        //    Expected difficulty = 100 (base) + 5% penalty = 105
        (uint256 expectedGas, uint256 expectedDiff) = portal.getGasValue(userDflBalance);
        assertEq(expectedDiff, 105);
        assertEq(expectedGas, (userDflBalance * 100) / expectedDiff);

        uint256 userEthBalanceBefore = user.balance;

        // 4. Perform local redeem (passing 0 as destination chain selector)
        vm.prank(user);
        portal.redeemGas(0, userDflBalance);

        // 5. Assert DFL was burned and native ETH was returned to the user
        assertEq(dflToken.balanceOf(user), 0);
        assertEq(user.balance, userEthBalanceBefore + expectedGas);

        // Assert user lost exactly the spread fee (received less than 1 ETH back)
        assertTrue(expectedGas < depositAmount);
    }

    /**
     * @notice Security: Verify that non-configured chains revert during depositGas
     */
    function test_DepositOnUnconfiguredChainReverts() public {
        vm.prank(admin);
        adminContract.setChainConfig(uint64(block.chainid), 0, 0);

        vm.deal(user, 1 ether);
        vm.expectRevert(Portal__ChainNotConfigured.selector);
        vm.prank(user);
        portal.depositGas{value: 1 ether}();
    }
}