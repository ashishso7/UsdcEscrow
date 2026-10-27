// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UsdcEscrow is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum EscrowStatus {
        Pending,
        Funded,
        Released,
        Refunded
    }

    struct EscrowInfo {
        address depositor;
        address beneficiary;
        uint256 amount;
        uint256 deadline;
        EscrowStatus status;
    }

    error ZeroAddress();
    error ZeroAmount();
    error DeadlineInPast();
    error EscrowNotFound(uint256 id);
    error NotDepositor(uint256 id);
    error WrongStatus(uint256 id, EscrowStatus current, EscrowStatus expected);
    error DeadlineNotPassed(uint256 id);
    error DeadlineNotExpired(uint256 id);
    error OwnerActionExpired(uint256 id);
    error RenounceNotAllowed();
    error AmountMismatch(uint256 id, uint256 expected, uint256 received);

    event EscrowCreated(
        uint256 indexed id,
        address indexed depositor,
        address indexed beneficiary,
        uint256 amount,
        uint256 deadline
    );
    event EscrowFunded(uint256 indexed id, uint256 amount);
    event EscrowReleased(uint256 indexed id, address indexed beneficiary, uint256 amount);
    event EscrowRefunded(uint256 indexed id, address indexed depositor, uint256 amount);
    event EscrowFallbackRefunded(uint256 indexed id, address indexed depositor, uint256 amount);

    IERC20 public immutable usdc;
    uint256 private _escrowCounter;
    mapping(uint256 => EscrowInfo) private _escrows;

    constructor(address usdcToken, address initialOwner) Ownable(initialOwner) {
        if (usdcToken == address(0) || initialOwner == address(0)) revert ZeroAddress();
        usdc = IERC20(usdcToken);
    }

    function renounceOwnership() public pure override {
        revert RenounceNotAllowed();
    }

    function createEscrow(address beneficiary, uint256 amount, uint256 deadline) external returns (uint256 id) {
        if (beneficiary == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (deadline <= block.timestamp) revert DeadlineInPast();

        id = ++_escrowCounter;

        _escrows[id] = EscrowInfo({
            depositor: msg.sender,
            beneficiary: beneficiary,
            amount: amount,
            deadline: deadline,
            status: EscrowStatus.Pending
        });

        emit EscrowCreated(id, msg.sender, beneficiary, amount, deadline);
    }

    function fund(uint256 escrowId) external nonReentrant {
        EscrowInfo storage escrow = _escrows[escrowId];
        if (escrow.depositor == address(0)) revert EscrowNotFound(escrowId);
        if (msg.sender != escrow.depositor) revert NotDepositor(escrowId);
        if (escrow.status != EscrowStatus.Pending) {
            revert WrongStatus(escrowId, escrow.status, EscrowStatus.Pending);
        }

        escrow.status = EscrowStatus.Funded;
        uint256 balanceBefore = usdc.balanceOf(address(this));
        usdc.safeTransferFrom(msg.sender, address(this), escrow.amount);
        uint256 received = usdc.balanceOf(address(this)) - balanceBefore;
        if (received != escrow.amount) revert AmountMismatch(escrowId, escrow.amount, received);

        emit EscrowFunded(escrowId, escrow.amount);
    }

    function release(uint256 escrowId) external onlyOwner nonReentrant {
        EscrowInfo storage escrow = _escrows[escrowId];
        if (escrow.depositor == address(0)) revert EscrowNotFound(escrowId);
        if (block.timestamp > escrow.deadline) revert OwnerActionExpired(escrowId);
        if (escrow.status != EscrowStatus.Funded) {
            revert WrongStatus(escrowId, escrow.status, EscrowStatus.Funded);
        }

        uint256 amount = escrow.amount;
        escrow.amount = 0;
        escrow.status = EscrowStatus.Released;

        usdc.safeTransfer(escrow.beneficiary, amount);

        emit EscrowReleased(escrowId, escrow.beneficiary, amount);
    }

    function emergencyRelease(uint256 escrowId) external onlyOwner nonReentrant {
        EscrowInfo storage escrow = _escrows[escrowId];
        if (escrow.depositor == address(0)) revert EscrowNotFound(escrowId);
        if (block.timestamp <= escrow.deadline) revert DeadlineNotExpired(escrowId);
        if (escrow.status != EscrowStatus.Funded) {
            revert WrongStatus(escrowId, escrow.status, EscrowStatus.Funded);
        }

        uint256 amount = escrow.amount;
        escrow.amount = 0;
        escrow.status = EscrowStatus.Released;

        usdc.safeTransfer(escrow.beneficiary, amount);

        emit EscrowReleased(escrowId, escrow.beneficiary, amount);
    }

    function refund(uint256 escrowId) external onlyOwner nonReentrant {
        EscrowInfo storage escrow = _escrows[escrowId];
        if (escrow.depositor == address(0)) revert EscrowNotFound(escrowId);
        if (block.timestamp > escrow.deadline) revert OwnerActionExpired(escrowId);
        if (escrow.status != EscrowStatus.Funded) {
            revert WrongStatus(escrowId, escrow.status, EscrowStatus.Funded);
        }

        uint256 amount = escrow.amount;
        escrow.amount = 0;
        escrow.status = EscrowStatus.Refunded;

        usdc.safeTransfer(escrow.depositor, amount);

        emit EscrowRefunded(escrowId, escrow.depositor, amount);
    }

    function reclaim(uint256 escrowId) external nonReentrant {
        EscrowInfo storage escrow = _escrows[escrowId];
        if (escrow.depositor == address(0)) revert EscrowNotFound(escrowId);
        if (msg.sender != escrow.depositor) revert NotDepositor(escrowId);
        if (escrow.status != EscrowStatus.Funded) {
            revert WrongStatus(escrowId, escrow.status, EscrowStatus.Funded);
        }
        if (block.timestamp <= escrow.deadline) revert DeadlineNotPassed(escrowId);

        uint256 amount = escrow.amount;
        escrow.amount = 0;
        escrow.status = EscrowStatus.Refunded;

        usdc.safeTransfer(escrow.depositor, amount);

        emit EscrowRefunded(escrowId, escrow.depositor, amount);
    }

    function fallbackRefund(uint256 escrowId) external onlyOwner nonReentrant {
        EscrowInfo storage escrow = _escrows[escrowId];
        if (escrow.depositor == address(0)) revert EscrowNotFound(escrowId);
        if (escrow.status != EscrowStatus.Funded) {
            revert WrongStatus(escrowId, escrow.status, EscrowStatus.Funded);
        }

        uint256 amount = escrow.amount;
        escrow.amount = 0;
        escrow.status = EscrowStatus.Refunded;

        usdc.safeTransfer(escrow.depositor, amount);

        emit EscrowRefunded(escrowId, escrow.depositor, amount);
        emit EscrowFallbackRefunded(escrowId, escrow.depositor, amount);
    }

    function getEscrow(uint256 escrowId) external view returns (EscrowInfo memory) {
        EscrowInfo memory escrow = _escrows[escrowId];
        if (escrow.depositor == address(0)) revert EscrowNotFound(escrowId);
        return escrow;
    }
}
