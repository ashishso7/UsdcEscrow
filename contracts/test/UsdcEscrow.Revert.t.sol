// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {UsdcEscrowBase} from "./UsdcEscrow.Base.t.sol";
import {UsdcEscrow} from "../UsdcEscrow.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract UsdcEscrowRevertTest is UsdcEscrowBase {

    // ══════════════════════════════════════════════════════════════════════
    //  createEscrow — revert paths
    // ══════════════════════════════════════════════════════════════════════

    function test_CreateEscrow_RevertIf_ZeroBeneficiary() public {
        vm.prank(alice);
        vm.expectRevert(UsdcEscrow.ZeroAddress.selector);
        escrow.createEscrow(address(0), AMOUNT, block.timestamp + ONE_DAY);
    }

    function test_CreateEscrow_RevertIf_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(UsdcEscrow.ZeroAmount.selector);
        escrow.createEscrow(bob, 0, block.timestamp + ONE_DAY);
    }

    function test_CreateEscrow_RevertIf_DeadlineInPast() public {
        vm.prank(alice);
        vm.expectRevert(UsdcEscrow.DeadlineInPast.selector);
        // deadline == block.timestamp is also in the past (strict <)
        escrow.createEscrow(bob, AMOUNT, block.timestamp);
    }

    function test_CreateEscrow_RevertIf_DeadlineStrictlyPast() public {
        vm.prank(alice);
        vm.expectRevert(UsdcEscrow.DeadlineInPast.selector);
        escrow.createEscrow(bob, AMOUNT, block.timestamp - 1);
    }

    // ══════════════════════════════════════════════════════════════════════
    //  fund — revert paths
    // ══════════════════════════════════════════════════════════════════════

    function test_Fund_RevertIf_NotDepositor() public {
        uint256 id = _createEscrow();
        _fundAndApprove(stranger, AMOUNT);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(UsdcEscrow.NotDepositor.selector, id));
        escrow.fund(id);
    }

    function test_Fund_RevertIf_EscrowNotPending() public {
        uint256 id = _createAndFund(); // status → Funded
        _fundAndApprove(alice, AMOUNT);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                UsdcEscrow.WrongStatus.selector,
                id,
                UsdcEscrow.EscrowStatus.Funded,
                UsdcEscrow.EscrowStatus.Pending
            )
        );
        escrow.fund(id);
    }

    function test_Fund_RevertIf_EscrowNotFound() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(UsdcEscrow.EscrowNotFound.selector, 999));
        escrow.fund(999);
    }

    function test_Fund_RevertIf_InsufficientApproval() public {
        uint256 id = _createEscrow();
        // Mint tokens but do NOT approve → transferFrom reverts
        usdc.mint(alice, AMOUNT);
        // approval is zero, SafeERC20 will revert on the transferFrom
        vm.prank(alice);
        vm.expectRevert();
        escrow.fund(id);
    }

    // ══════════════════════════════════════════════════════════════════════
    //  release — revert paths
    // ══════════════════════════════════════════════════════════════════════

    function test_Release_RevertIf_NotOwner() public {
        uint256 id = _createAndFund();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        escrow.release(id);
    }

    function test_Release_RevertIf_NotFunded() public {
        // Escrow in Pending status → WrongStatus
        uint256 id = _createEscrow();
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                UsdcEscrow.WrongStatus.selector,
                id,
                UsdcEscrow.EscrowStatus.Pending,
                UsdcEscrow.EscrowStatus.Funded
            )
        );
        escrow.release(id);
    }

    function test_Release_RevertIf_AfterDeadline() public {
        uint256 id = _createAndFund();
        vm.warp(block.timestamp + ONE_DAY + 1);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(UsdcEscrow.OwnerActionExpired.selector, id));
        escrow.release(id);
    }

    // ══════════════════════════════════════════════════════════════════════
    //  refund — revert paths
    // ══════════════════════════════════════════════════════════════════════

    function test_Refund_RevertIf_NotOwner() public {
        uint256 id = _createAndFund();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        escrow.refund(id);
    }

    function test_Refund_RevertIf_NotFunded() public {
        uint256 id = _createEscrow();
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                UsdcEscrow.WrongStatus.selector,
                id,
                UsdcEscrow.EscrowStatus.Pending,
                UsdcEscrow.EscrowStatus.Funded
            )
        );
        escrow.refund(id);
    }

    function test_Refund_RevertIf_AfterDeadline() public {
        uint256 id = _createAndFund();
        vm.warp(block.timestamp + ONE_DAY + 1);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(UsdcEscrow.OwnerActionExpired.selector, id));
        escrow.refund(id);
    }

    // ══════════════════════════════════════════════════════════════════════
    //  reclaim — revert paths
    // ══════════════════════════════════════════════════════════════════════

    function test_Reclaim_RevertIf_NotDepositor() public {
        uint256 id = _createAndFund();
        vm.warp(block.timestamp + ONE_DAY + 1);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(UsdcEscrow.NotDepositor.selector, id));
        escrow.reclaim(id);
    }

    function test_Reclaim_RevertIf_NotFunded() public {
        // Pending → WrongStatus
        uint256 id = _createEscrow();
        vm.warp(block.timestamp + ONE_DAY + 1);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                UsdcEscrow.WrongStatus.selector,
                id,
                UsdcEscrow.EscrowStatus.Pending,
                UsdcEscrow.EscrowStatus.Funded
            )
        );
        escrow.reclaim(id);
    }

    function test_Reclaim_RevertIf_BeforeDeadline() public {
        uint256 id = _createAndFund();
        // deadline is now + ONE_DAY; we stay before it
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(UsdcEscrow.DeadlineNotPassed.selector, id));
        escrow.reclaim(id);
    }

    // ══════════════════════════════════════════════════════════════════════
    //  fallbackRefund — revert paths
    // ══════════════════════════════════════════════════════════════════════

    function test_FallbackRefund_RevertIf_NotOwner() public {
        uint256 id = _createAndFund();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        escrow.fallbackRefund(id);
    }

    function test_FallbackRefund_RevertIf_NotFunded() public {
        uint256 id = _createEscrow(); // Pending
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                UsdcEscrow.WrongStatus.selector,
                id,
                UsdcEscrow.EscrowStatus.Pending,
                UsdcEscrow.EscrowStatus.Funded
            )
        );
        escrow.fallbackRefund(id);
    }

    // ══════════════════════════════════════════════════════════════════════
    //  emergencyRelease — revert paths
    // ══════════════════════════════════════════════════════════════════════

    function test_EmergencyRelease_RevertIf_NotOwner() public {
        uint256 id = _createAndFund();
        vm.warp(block.timestamp + ONE_DAY + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        escrow.emergencyRelease(id);
    }

    function test_EmergencyRelease_RevertIf_BeforeDeadline() public {
        uint256 id = _createAndFund();
        // deadline has NOT passed yet
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(UsdcEscrow.DeadlineNotExpired.selector, id));
        escrow.emergencyRelease(id);
    }

    function test_EmergencyRelease_RevertIf_NotFunded() public {
        uint256 id = _createEscrow(); // Pending
        vm.warp(block.timestamp + ONE_DAY + 1);
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                UsdcEscrow.WrongStatus.selector,
                id,
                UsdcEscrow.EscrowStatus.Pending,
                UsdcEscrow.EscrowStatus.Funded
            )
        );
        escrow.emergencyRelease(id);
    }

    // ══════════════════════════════════════════════════════════════════════
    //  renounceOwnership
    // ══════════════════════════════════════════════════════════════════════

    function test_RenounceOwnership_RevertForOwner() public {
        vm.prank(owner);
        vm.expectRevert(UsdcEscrow.RenounceNotAllowed.selector);
        escrow.renounceOwnership();
    }

    function test_RenounceOwnership_RevertForStranger() public {
        vm.prank(stranger);
        // pure override reverts before the Ownable check
        vm.expectRevert(UsdcEscrow.RenounceNotAllowed.selector);
        escrow.renounceOwnership();
    }

    // ══════════════════════════════════════════════════════════════════════
    //  getEscrow — revert on missing id
    // ══════════════════════════════════════════════════════════════════════

    function test_GetEscrow_RevertIf_NotFound() public {
        vm.expectRevert(abi.encodeWithSelector(UsdcEscrow.EscrowNotFound.selector, 42));
        escrow.getEscrow(42);
    }
}
