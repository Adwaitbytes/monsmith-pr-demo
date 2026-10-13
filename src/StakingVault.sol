// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title StakingVault
/// @notice Stake MON, earn a share of the fees paid into the vault.
contract StakingVault {
    address public immutable owner;
    uint256 public feeBps = 50;
    uint256 public totalStaked;

    mapping(address => uint256) public stakeOf;

    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);

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
}
