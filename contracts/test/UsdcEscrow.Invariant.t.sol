// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {UsdcEscrowBase} from "./UsdcEscrow.Base.t.sol";
import {UsdcEscrow} from "../UsdcEscrow.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";

// ─────────────────────────────────────────────────────────────────────────────
//  Handler — plain contract; receives references from the outer setUp().
//  Drives valid state transitions and tracks funded escrow ids.
// ─────────────────────────────────────────────────────────────────────────────
contract EscrowHandler is Test {
    UsdcEscrow  internal escrow;
    MockERC20   internal usdc;

    address internal owner    = makeAddr("owner");
    address internal alice    = makeAddr("alice");
    address internal bob      = makeAddr("bob");

    uint256[] internal _fundedIds;

    constructor(UsdcEscrow _escrow, MockERC20 _usdc) {
        escrow = _escrow;
        usdc   = _usdc;
    }

    // ── actions ──────────────────────────────────────────────────────────────

    function action_CreateAndFund(uint96 rawAmount, uint32 rawDelta) external {
        uint256 amount   = bound(uint256(rawAmount), 1, 1_000_000e6);
        uint256 deadline = block.timestamp + bound(uint256(rawDelta), 1, 30 days);

        vm.prank(alice);
        uint256 id = escrow.createEscrow(bob, amount, deadline);

        usdc.mint(alice, amount);
        vm.prank(alice);
        usdc.approve(address(escrow), amount);
        vm.prank(alice);
        escrow.fund(id);

        _fundedIds.push(id);
    }

    function action_Release(uint256 seed) external {
        if (_fundedIds.length == 0) return;
        uint256 idx = seed % _fundedIds.length;
        uint256 id  = _fundedIds[idx];

        UsdcEscrow.EscrowInfo memory info = escrow.getEscrow(id);
        if (block.timestamp > info.deadline) return;

        vm.prank(owner);
        escrow.release(id);
        _removeFundedId(idx);
    }

    function action_Refund(uint256 seed) external {
        if (_fundedIds.length == 0) return;
        uint256 idx = seed % _fundedIds.length;
        uint256 id  = _fundedIds[idx];

        UsdcEscrow.EscrowInfo memory info = escrow.getEscrow(id);
        if (block.timestamp > info.deadline) return;

        vm.prank(owner);
        escrow.refund(id);
        _removeFundedId(idx);
    }

    function action_FallbackRefund(uint256 seed) external {
        if (_fundedIds.length == 0) return;
        uint256 idx = seed % _fundedIds.length;
        uint256 id  = _fundedIds[idx];

        vm.prank(owner);
        escrow.fallbackRefund(id);
        _removeFundedId(idx);
    }

    function action_Reclaim(uint256 seed, uint32 extraTime) external {
        if (_fundedIds.length == 0) return;
        uint256 idx = seed % _fundedIds.length;
        uint256 id  = _fundedIds[idx];

        UsdcEscrow.EscrowInfo memory info = escrow.getEscrow(id);
        uint256 target = info.deadline + bound(uint256(extraTime), 1, 1 days);
        if (block.timestamp <= info.deadline) vm.warp(target);

        vm.prank(alice);
        escrow.reclaim(id);
        _removeFundedId(idx);
    }

    function action_EmergencyRelease(uint256 seed, uint32 extraTime) external {
        if (_fundedIds.length == 0) return;
        uint256 idx = seed % _fundedIds.length;
        uint256 id  = _fundedIds[idx];

        UsdcEscrow.EscrowInfo memory info = escrow.getEscrow(id);
        uint256 target = info.deadline + bound(uint256(extraTime), 1, 1 days);
        if (block.timestamp <= info.deadline) vm.warp(target);

        vm.prank(owner);
        escrow.emergencyRelease(id);
        _removeFundedId(idx);
    }

    // ── view helpers ─────────────────────────────────────────────────────────

    function getFundedIds() external view returns (uint256[] memory) {
        return _fundedIds;
    }

    // ── internal ─────────────────────────────────────────────────────────────
    function _removeFundedId(uint256 idx) internal {
        _fundedIds[idx] = _fundedIds[_fundedIds.length - 1];
        _fundedIds.pop();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Invariant test contract — inherits UsdcEscrowBase for deploy + actors.
// ─────────────────────────────────────────────────────────────────────────────
contract UsdcEscrowInvariantTest is UsdcEscrowBase {
    EscrowHandler internal handler;

    function setUp() public override {
        // Deploy usdc + escrow via base setUp
        super.setUp();

        // Deploy handler, wiring it to the shared contracts
        handler = new EscrowHandler(escrow, usdc);
        targetContract(address(handler));
    }

    /// @dev Core conservation law:
    ///      sum of `escrow.amount` for all Funded escrows == contract USDC balance.
    function invariant_FundedEscrowSumEqualsContractBalance() public view {
        uint256[] memory ids = handler.getFundedIds();

        uint256 sumAmounts = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            UsdcEscrow.EscrowInfo memory info = escrow.getEscrow(ids[i]);
            assertEq(
                uint8(info.status),
                uint8(UsdcEscrow.EscrowStatus.Funded),
                "tracked id not in Funded status"
            );
            sumAmounts += info.amount;
        }

        assertEq(
            usdc.balanceOf(address(escrow)),
            sumAmounts,
            "contract USDC balance != sum of Funded escrow amounts"
        );
    }
}
