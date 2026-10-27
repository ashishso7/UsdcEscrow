// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {UsdcEscrowBase} from "./UsdcEscrow.Base.t.sol";
import {UsdcEscrow} from "../UsdcEscrow.sol";

contract UsdcEscrowFuzzTest is UsdcEscrowBase {

    // ── createEscrow: fuzz amount + deadline ─────────────────────────────────

    /// @dev Confirms createEscrow stores exactly the supplied values and
    ///      increments the id counter without arithmetic issues across the
    ///      full uint128/uint64 input ranges.
    function testFuzz_CreateEscrow_StoresValues(
        uint128 rawAmount,
        uint64  rawDelta     // seconds added to block.timestamp
    ) public {
        // bound inputs to valid ranges
        uint256 amount   = bound(uint256(rawAmount), 1, type(uint128).max);
        uint256 deadline = block.timestamp + bound(uint256(rawDelta), 1, 365 days);

        vm.prank(alice);
        uint256 id = escrow.createEscrow(bob, amount, deadline);

        UsdcEscrow.EscrowInfo memory info = escrow.getEscrow(id);
        assertEq(info.depositor,   alice);
        assertEq(info.beneficiary, bob);
        assertEq(info.amount,      amount);
        assertEq(info.deadline,    deadline);
        assertEq(uint8(info.status), uint8(UsdcEscrow.EscrowStatus.Pending));
    }

    /// @dev Confirms the escrow id increments monotonically over N sequential
    ///      createEscrow calls with varying parameters (no counter overflow risk
    ///      in practice, but confirmed for fuzz-driven amounts/deadlines).
    function testFuzz_CreateEscrow_IdMonotonicallyIncreases(
        uint8   n,           // 1..10 iterations
        uint64  rawDelta
    ) public {
        uint256 iters    = bound(uint256(n), 1, 10);
        uint256 deadline = block.timestamp + bound(uint256(rawDelta), 1, 365 days);

        uint256 lastId = 0;
        for (uint256 i = 0; i < iters; i++) {
            vm.prank(alice);
            uint256 id = escrow.createEscrow(bob, AMOUNT, deadline);
            assertEq(id, lastId + 1, "id not monotonically increasing");
            lastId = id;
        }
    }

    // ── fund + release: fuzz amount ──────────────────────────────────────────

    /// @dev Full happy-path fuzz: create → fund → release, checking that the
    ///      beneficiary receives exactly `amount` tokens with no rounding error.
    function testFuzz_FundAndRelease_ExactAmountTransferred(uint128 rawAmount) public {
        uint256 amount = bound(uint256(rawAmount), 1, type(uint128).max);

        // create with fuzzed amount
        uint256 deadline = block.timestamp + ONE_DAY;
        vm.prank(alice);
        uint256 id = escrow.createEscrow(bob, amount, deadline);

        // fund
        usdc.mint(alice, amount);
        vm.prank(alice);
        usdc.approve(address(escrow), amount);
        vm.prank(alice);
        escrow.fund(id);

        // release
        uint256 benBefore = usdc.balanceOf(bob);
        vm.prank(owner);
        escrow.release(id);

        assertEq(usdc.balanceOf(bob),              benBefore + amount, "beneficiary balance wrong");
        assertEq(usdc.balanceOf(address(escrow)),  0,                  "contract balance non-zero");
    }

    // ── reclaim: fuzz deadline delta ─────────────────────────────────────────

    /// @dev Confirms reclaim succeeds for ANY deadline in the past and returns
    ///      the exact token amount to the depositor.
    function testFuzz_Reclaim_AnyExpiredDeadline(uint32 extraSeconds) public {
        // warp at least 1 second past the deadline
        uint256 delta = bound(uint256(extraSeconds), 1, 365 days);

        uint256 id = _createAndFund();
        // jump to deadline + delta
        vm.warp(block.timestamp + ONE_DAY + delta);

        uint256 aliceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        escrow.reclaim(id);

        assertEq(usdc.balanceOf(alice), aliceBefore + AMOUNT, "depositor balance wrong");
        assertEq(usdc.balanceOf(address(escrow)), 0,          "contract balance non-zero");
    }
}
