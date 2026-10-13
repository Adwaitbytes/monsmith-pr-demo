// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title StakingVault
/// @notice Stake MON, earn a share of the fees paid into the vault.
contract StakingVault {
    address public immutable owner;
    uint256 public feeBps = 50;
    uint256 public totalStaked;

    mapping(address => uint256) public stakeOf;
    mapping(address => uint256) public rewardOf;

    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);
    event RewardsClaimed(address indexed account, uint256 amount);
    event FeeChanged(uint256 feeBps);

    error NothingStaked();
    error TransferFailed();

    constructor() {
        owner = msg.sender;
    }

    function stake() external payable {
        stakeOf[msg.sender] += msg.value;
        totalStaked += msg.value;
        emit Staked(msg.sender, msg.value);
    }

    function unstake(uint256 amount) external {
        uint256 staked = stakeOf[msg.sender];
        if (staked < amount || amount == 0) revert NothingStaked();

        stakeOf[msg.sender] = staked - amount;
        totalStaked -= amount;

        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Unstaked(msg.sender, amount);
    }

    /// @notice Fees paid into the vault are shared pro rata between stakers.
    function distribute(address[] calldata stakers) external payable {
        uint256 fee = (msg.value * feeBps) / 10_000;
        uint256 pool = msg.value - fee;
        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            rewardOf[staker] += (pool * stakeOf[staker]) / totalStaked;
        }
    }

    /// @notice Pays out everything a staker has earned.
    function claimRewards() external {
        uint256 reward = rewardOf[msg.sender];
        if (reward == 0) revert NothingStaked();

        (bool ok, ) = msg.sender.call{value: reward}("");
        if (!ok) revert TransferFailed();

        rewardOf[msg.sender] = 0;
        emit RewardsClaimed(msg.sender, reward);
    }

    /// @notice The share of each distribution the protocol keeps.
    function setFee(uint256 newFeeBps) external {
        feeBps = newFeeBps;
        emit FeeChanged(newFeeBps);
    }
}
