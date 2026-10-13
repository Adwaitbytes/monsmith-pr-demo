// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title StakingVault
/// @notice Stake MON, earn a share of the fees paid into the vault.
contract StakingVault {
    uint256 private constant PRECISION = 1e18;
    uint256 public constant MAX_FEE_BPS = 1_000;

    address public immutable owner;
    uint256 public feeBps = 50;
    uint256 public totalStaked;
    uint256 public rewardPerShare;
    uint256 public protocolFees;

    mapping(address => uint256) public stakeOf;
    mapping(address => uint256) public rewardOf;
    mapping(address => uint256) public rewardDebt;

    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);
    event Distributed(uint256 pool, uint256 fee);
    event RewardsClaimed(address indexed account, uint256 amount);
    event FeeChanged(uint256 feeBps);
    event FeesWithdrawn(uint256 amount);

    error NothingStaked();
    error NothingToClaim();
    error NoStakers();
    error TransferFailed();
    error NotOwner();
    error FeeTooHigh();

    constructor() {
        owner = msg.sender;
    }

    /// @dev Moves what an account earned since its last checkpoint into rewardOf.
    function _settle(address account) internal {
        uint256 accrued = (stakeOf[account] * rewardPerShare) / PRECISION;
        rewardOf[account] += accrued - rewardDebt[account];
    }

    function _checkpoint(address account) internal {
        rewardDebt[account] = (stakeOf[account] * rewardPerShare) / PRECISION;
    }

    function stake() external payable {
        _settle(msg.sender);
        stakeOf[msg.sender] += msg.value;
        totalStaked += msg.value;
        _checkpoint(msg.sender);
        emit Staked(msg.sender, msg.value);
    }

    function unstake(uint256 amount) external {
        uint256 staked = stakeOf[msg.sender];
        if (staked < amount || amount == 0) revert NothingStaked();

        _settle(msg.sender);
        stakeOf[msg.sender] = staked - amount;
        totalStaked -= amount;
        _checkpoint(msg.sender);

        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Unstaked(msg.sender, amount);
    }

    /// @notice Fees paid into the vault are shared pro rata between everyone staked right now.
    function distribute() external payable {
        if (totalStaked == 0) revert NoStakers();
        uint256 fee = (msg.value * feeBps) / 10_000;
        uint256 pool = msg.value - fee;
        protocolFees += fee;
        rewardPerShare += (pool * PRECISION) / totalStaked;
        emit Distributed(pool, fee);
    }

    /// @notice Pays out everything a staker has earned.
    function claimRewards() external {
        _settle(msg.sender);
        _checkpoint(msg.sender);
        uint256 reward = rewardOf[msg.sender];
        if (reward == 0) revert NothingToClaim();
        rewardOf[msg.sender] = 0;

        (bool ok, ) = msg.sender.call{value: reward}("");
        if (!ok) revert TransferFailed();
        emit RewardsClaimed(msg.sender, reward);
    }

    /// @notice The share of each distribution the protocol keeps.
    function setFee(uint256 newFeeBps) external {
        if (msg.sender != owner) revert NotOwner();
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeBps = newFeeBps;
        emit FeeChanged(newFeeBps);
    }

    function withdrawFees() external {
        if (msg.sender != owner) revert NotOwner();
        uint256 amount = protocolFees;
        protocolFees = 0;

        (bool ok, ) = owner.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit FeesWithdrawn(amount);
    }
}
