// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/DFLToken.sol";

/**
 * @title DeFi Labs Token Unit Tests
 * @author Your Name / Portfolio
 * @notice Tests security boundaries, edge cases, and EIP-2612 permit signatures of DFLToken.
 */
contract DFLTokenTest is Test {
    DFLToken public token;

    // Test accounts
    address public admin = address(0xAD);
    address public minter = address(0x11);
    address public user = address(0x22);
    address public spender = address(0x33);

    // Access control roles from OpenZeppelin's AccessControl
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @notice Set up the test environment before each test run
     */
    function setUp() public {
        // Deploy token, granting Admin role to the admin address
        token = new DFLToken(admin);

        // Grant MINTER_ROLE to the minter address from the admin account
        vm.prank(admin);
        token.grantRole(MINTER_ROLE, minter);
    }

    // ====================================================================
    // 1. SECURITY & ACCESS CONTROL TESTS
    // ====================================================================

    /**
     * @notice Test that an authorized minter can successfully mint tokens
     */
    function test_OnlyMinterCanMint() public {
        uint256 mintAmount = 1000 * 1e18;

        // Prank as the authorized minter
        vm.prank(minter);
        token.mint(user, mintAmount);

        assertEq(token.balanceOf(user), mintAmount);
    }

    /**
     * @notice Edge Case & Security: Verify unauthorized mint reverts with exact AccessControl error
     */
    function test_UnauthorizedMintReverts() public {
        uint256 mintAmount = 1000 * 1e18;

        // Try to mint from an unauthorized account (user)
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                user,
                MINTER_ROLE
            )
        );
        vm.prank(user);
        token.mint(user, mintAmount);
    }

    /**
     * @notice Test that admin can grant and revoke the minter role
     */
    function test_AdminCanManageRoles() public {
        // Revoke role
        vm.prank(admin);
        token.revokeRole(MINTER_ROLE, minter);

        // Verify former minter can no longer mint
        vm.expectRevert();
        vm.prank(minter);
        token.mint(user, 100 * 1e18);
    }

    // ====================================================================
    // 2. EDGE CASES TESTS
    // ====================================================================

    /**
     * @notice Edge Case: Minting 0 tokens should succeed but emit events and keep balances at 0
     */
    function test_MintZeroTokensSucceeds() public {
        vm.prank(minter);
        token.mint(user, 0);
        assertEq(token.balanceOf(user), 0);
    }

    /**
     * @notice Edge Case: Standard transfer to address(0) must revert
     */
    function test_TransferToZeroAddressReverts() public {
        uint256 amount = 100 * 1e18;

        vm.prank(minter);
        token.mint(user, amount);

        vm.prank(user);
        // Using native Solidity try/catch to handle the reverting external call safely
        try token.transfer(address(0), amount) returns (bool success) {
            // If the call somehow succeeds, we force fail the test
            assertTrue(success);
            fail("Transfer to zero address should have reverted");
        } catch (bytes memory reason) {
            // Verify that the revert reason matches the expected OpenZeppelin custom error
            bytes memory expectedError = abi.encodeWithSignature(
                "ERC20InvalidReceiver(address)",
                address(0)
            );
            assertEq(reason, expectedError);
        }
    }

    // ====================================================================
    // 3. ADVANCED CRYPTOGRAPHY: EIP-2612 PERMIT SIGNATURE TESTS
    // ====================================================================

    /**
     * @notice Cryptography: Test gasless approval using valid EIP-2612 Permit signature
     */
    function test_EIP2612Permit() public {
        // Generate a private key for the owner (vm.addr generates corresponding address)
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);

        uint256 value = 500 * 1e18;
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1 hours;

        // Build EIP-712 structured data digest for the permit signature
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );

        // Sign the digest off-chain using the private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Execute permit on the token contract (spender can execute this, paying the gas!)
        token.permit(owner, spender, value, deadline, v, r, s);

        // Assert allowance updated correctly
        assertEq(token.allowance(owner, spender), value);
    }

    /**
     * @notice Cryptography: Verify expired permit deadline reverts
     */
    function test_ExpiredPermitReverts() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);

        uint256 deadline = block.timestamp - 1; // Expired 1 second ago

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                100,
                0,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert(
            abi.encodeWithSignature("ERC2612ExpiredSignature(uint256)", deadline)
        );
        token.permit(owner, spender, 100, deadline, v, r, s);
    }

    // ====================================================================
    // 4. ADVANCED SECURITY: REPLAY PROTECTION & PRIVILEGE CONTAINMENT
    // ====================================================================

    /**
     * @notice Security: Test that admin role is correctly initialized on deployment
     */
    function test_AdminRoleInitializedOnDeployment() public view {
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, admin));
    }

    /**
     * @notice Security: Verify that a Minter cannot escalate privileges or grant roles
     */
    function test_MinterCannotGrantRole() public {
        // Minter tries to grant MINTER_ROLE to the user account
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                minter,
                DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(minter);
        token.grantRole(MINTER_ROLE, user);
    }
    /**
     * @notice Security: Test Signature Replay Protection
     * @dev Re-using the exact same valid signature must revert because the nonce increments
     */
    function test_PermitSignatureReplayReverts() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);

        uint256 value = 100 * 1e18;
        uint256 nonce = token.nonces(owner); // Starts at 0
        uint256 deadline = block.timestamp + 1 hours;

        // 1. Generate valid signature for nonce 0
        bytes32 structHash1 = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest1 = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash1)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest1);

        // First execution of permit: Should succeed, nonces[owner] becomes 1
        token.permit(owner, spender, value, deadline, v, r, s);
        assertEq(token.allowance(owner, spender), value);
        assertEq(token.nonces(owner), 1);

        // 2. Calculate the exact "garbage" address that contract will recover during replay.
        // During the replay, the contract will hash the data using nonce = 1.
        bytes32 structHash2 = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                1, // Current on-chain nonce is now 1
                deadline
            )
        );
        bytes32 digest2 = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash2)
        );

        // Mathematically recover the wrong signer that ecrecover will yield on-chain
        address recoveredSigner = ecrecover(digest2, v, r, s);

        // Second execution with the EXACT same signature: Must revert with expected custom error parameters
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC2612InvalidSigner(address,address)",
                recoveredSigner, // The garbage address recovered on-chain
                owner            // The expected owner
            )
        );
        token.permit(owner, spender, value, deadline, v, r, s);
    }

}