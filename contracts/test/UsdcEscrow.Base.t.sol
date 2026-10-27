// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {UsdcEscrow} from "../UsdcEscrow.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";

/// @dev Shared base for all UsdcEscrow test suites.
///      No test/fuzz/invariant functions here — all categories inherit.
abstract contract UsdcEscrowBase is Test {
    // ── actors ──────────────────────────────────────────────────────────────
    address internal owner     = makeAddr("owner");
    address internal alice     = makeAddr("alice");   // depositor
    address internal bob       = makeAddr("bob");     // beneficiary
    address internal stranger  = makeAddr("stranger");

    // ── contracts ───────────────────────────────────────────────────────────
    MockERC20    internal usdc;
    UsdcEscrow   internal escrow;

    // ── constants ───────────────────────────────────────────────────────────
    uint256 internal constant AMOUNT   = 1_000e6;   // 1 000 USDC (6 dec)
    uint256 internal constant ONE_DAY  = 1 days;

    // ── helpers ─────────────────────────────────────────────────────────────

    /// Fund alice with `amount` mock-USDC and approve the escrow contract.
    function _fundAndApprove(address depositor, uint256 amount) internal {
        usdc.mint(depositor, amount);
        vm.prank(depositor);
        usdc.approve(address(escrow), amount);
    }

    /// Create an escrow from alice → bob with AMOUNT and deadline = now + ONE_DAY.
    /// Returns the escrow id.
    function _createEscrow() internal returns (uint256 id) {
        vm.prank(alice);
        id = escrow.createEscrow(bob, AMOUNT, block.timestamp + ONE_DAY);
    }

    /// Create + fund an escrow (alice → bob).
    function _createAndFund() internal returns (uint256 id) {
        id = _createEscrow();
        _fundAndApprove(alice, AMOUNT);
        vm.prank(alice);
        escrow.fund(id);
    }

    // ── setUp ───────────────────────────────────────────────────────────────
    function setUp() public virtual {
        usdc   = new MockERC20("Mock USDC", "mUSDC", 6);
        escrow = new UsdcEscrow(address(usdc), owner);
    }
}
