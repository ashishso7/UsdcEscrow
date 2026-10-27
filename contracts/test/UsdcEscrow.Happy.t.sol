// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {UsdcEscrowBase} from "./UsdcEscrow.Base.t.sol";
import {UsdcEscrow} from "../UsdcEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UsdcEscrowHappyTest is UsdcEscrowBase {

    // ── Deployment ───────────────────────────────────────────────────────────

    function test_Deploy_SetsUsdcAndOwner() public view {
        assertEq(address(escrow.usdc()), address(usdc));
        assertEq(escrow.owner(), owner);
    }

    // ── createEscrow ─────────────────────────────────────────────────────────

    function test_CreateEscrow_StoresCorrectFields() public {
        uint256 deadline = block.timestamp + ONE_DAY;
        vm.prank(alice);
        uint256 id = escrow.createEscrow(bob, AMOUNT, deadline);

        UsdcEscrow.EscrowInfo memory info = escrow.getEscrow(id);
        assertEq(info.depositor,    alice);
        assertEq(info.beneficiary,  bob);
        assertEq(info.amount,       AMOUNT);
        assertEq(info.deadline,     deadline);
        assertEq(uint8(info.status), uint8(UsdcEscrow.EscrowStatus.Pending));
    }

    function test_CreateEscrow_ReturnsIncrementingIds() public {
        vm.startPrank(alice);
        uint256 id1 = escrow.createEscrow(bob, AMOUNT, block.timestamp + ONE_DAY);
        uint256 id2 = escrow.createEscrow(bob, AMOUNT, block.timestamp + ONE_DAY);
        vm.stopPrank();
        assertEq(id1, 1);
        assertEq(id2, 2);
    }

    // ── EscrowCreated event ──────────────────────────────────────────────────

    function test_CreateEscrow_EmitsEscrowCreated() public {
        uint256 deadline = block.timestamp + ONE_DAY;
        vm.prank(alice);
        vm.expectEmit(true, true, true, true, address(escrow));
        emit UsdcEscrow.EscrowCreated(1, alice, bob, AMOUNT, deadline);
        escrow.createEscrow(bob, AMOUNT, deadline);
    }

    // ── fund ─────────────────────────────────────────────────────────────────

    function test_Fund_SetsStatusToFunded() public {
        uint256 id = _createEscrow();
        _fundAndApprove(alice, AMOUNT);
        vm.prank(alice);
        escrow.fund(id);

        UsdcEscrow.EscrowInfo memory info = escrow.getEscrow(id);
        assertEq(uint8(info.status), uint8(UsdcEscrow.EscrowStatus.Funded));
        // amount field still set (only zeroed on release/refund)
        assertEq(info.amount, AMOUNT);
    }

    function test_Fund_TransfersTokensToContract() public {
        uint256 id = _createEscrow();
        _fundAndApprove(alice, AMOUNT);
        uint256 before = usdc.balanceOf(address(escrow));
        vm.prank(alice);
        escrow.fund(id);
        assertEq(usdc.balanceOf(address(escrow)), before + AMOUNT);
        assertEq(usdc.balanceOf(alice), 0);
    }

    // ── EscrowFunded event ───────────────────────────────────────────────────

    function test_Fund_EmitsEscrowFunded() public {
        uint256 id = _createEscrow();
        _fundAndApprove(alice, AMOUNT);
        vm.prank(alice);
        vm.expectEmit(true, false, false, true, address(escrow));
        emit UsdcEscrow.EscrowFunded(id, AMOUNT);
        escrow.fund(id);
    }

    // ── Lifecycle 1: createEscrow → fund → release ───────────────────────────

    function test_Lifecycle_Release_SendsToBeneficiary() public {
        uint256 id = _createAndFund();

        uint256 benBefore = usdc.balanceOf(bob);
        vm.prank(owner);
        escrow.release(id);

        assertEq(usdc.balanceOf(bob), benBefore + AMOUNT);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(uint8(escrow.getEscrow(id).status), uint8(UsdcEscrow.EscrowStatus.Released));
        assertEq(escrow.getEscrow(id).amount, 0);
    }

    function test_Release_EmitsEscrowReleased() public {
        uint256 id = _createAndFund();
        vm.prank(owner);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit UsdcEscrow.EscrowReleased(id, bob, AMOUNT);
        escrow.release(id);
    }

    // ── Lifecycle 2: createEscrow → fund → refund ────────────────────────────

    function test_Lifecycle_Refund_SendsToDepositor() public {
        uint256 id = _createAndFund();

        uint256 aliceBefore = usdc.balanceOf(alice);
        vm.prank(owner);
        escrow.refund(id);

        assertEq(usdc.balanceOf(alice), aliceBefore + AMOUNT);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(uint8(escrow.getEscrow(id).status), uint8(UsdcEscrow.EscrowStatus.Refunded));
        assertEq(escrow.getEscrow(id).amount, 0);
    }

    function test_Refund_EmitsEscrowRefunded() public {
        uint256 id = _createAndFund();
        vm.prank(owner);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit UsdcEscrow.EscrowRefunded(id, alice, AMOUNT);
        escrow.refund(id);
    }

    // ── Lifecycle 3: createEscrow → fund → reclaim (past deadline) ───────────

    function test_Lifecycle_Reclaim_SendsToDepositorAfterDeadline() public {
        uint256 id = _createAndFund();
        // warp past the deadline
        vm.warp(block.timestamp + ONE_DAY + 1);

        uint256 aliceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        escrow.reclaim(id);

        assertEq(usdc.balanceOf(alice), aliceBefore + AMOUNT);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(uint8(escrow.getEscrow(id).status), uint8(UsdcEscrow.EscrowStatus.Refunded));
    }

    function test_Reclaim_EmitsEscrowRefunded() public {
        uint256 id = _createAndFund();
        vm.warp(block.timestamp + ONE_DAY + 1);
        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit UsdcEscrow.EscrowRefunded(id, alice, AMOUNT);
        escrow.reclaim(id);
    }

    // ── Lifecycle 4: fallbackRefund ──────────────────────────────────────────

    function test_Lifecycle_FallbackRefund_SendsToDepositor() public {
        uint256 id = _createAndFund();

        uint256 aliceBefore = usdc.balanceOf(alice);
        vm.prank(owner);
        escrow.fallbackRefund(id);

        assertEq(usdc.balanceOf(alice), aliceBefore + AMOUNT);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(uint8(escrow.getEscrow(id).status), uint8(UsdcEscrow.EscrowStatus.Refunded));
    }

    function test_FallbackRefund_EmitsBothEvents() public {
        uint256 id = _createAndFund();
        vm.prank(owner);
        // EscrowRefunded first
        vm.expectEmit(true, true, false, true, address(escrow));
        emit UsdcEscrow.EscrowRefunded(id, alice, AMOUNT);
        // EscrowFallbackRefunded second
        vm.expectEmit(true, true, false, true, address(escrow));
        emit UsdcEscrow.EscrowFallbackRefunded(id, alice, AMOUNT);
        escrow.fallbackRefund(id);
    }

    // ── Lifecycle 5: emergencyRelease (past deadline) ────────────────────────

    function test_Lifecycle_EmergencyRelease_SendsToBeneficiaryAfterDeadline() public {
        uint256 id = _createAndFund();
        vm.warp(block.timestamp + ONE_DAY + 1);

        uint256 benBefore = usdc.balanceOf(bob);
        vm.prank(owner);
        escrow.emergencyRelease(id);

        assertEq(usdc.balanceOf(bob), benBefore + AMOUNT);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(uint8(escrow.getEscrow(id).status), uint8(UsdcEscrow.EscrowStatus.Released));
    }

    function test_EmergencyRelease_EmitsEscrowReleased() public {
        uint256 id = _createAndFund();
        vm.warp(block.timestamp + ONE_DAY + 1);
        vm.prank(owner);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit UsdcEscrow.EscrowReleased(id, bob, AMOUNT);
        escrow.emergencyRelease(id);
    }

    // ── renounceOwnership ────────────────────────────────────────────────────

    function test_RenounceOwnership_AlwaysReverts() public {
        vm.prank(owner);
        vm.expectRevert(UsdcEscrow.RenounceNotAllowed.selector);
        escrow.renounceOwnership();
    }
}
