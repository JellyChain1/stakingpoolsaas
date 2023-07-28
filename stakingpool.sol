// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract StakingPool {
    address public stakingToken;
    address public owner;
    uint256 public rewardAmount;
    uint256 public rewardInterval;
    uint256 public lastRewardTime;
    
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public stakingTimes;
    
    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    
    uint256 public constant stakingPeriod = 30 days;
    uint256 public constant unstakeLockPeriod = 2 hours;

    constructor(
        address _stakingToken,
        uint256 _rewardAmount,
        uint256 _rewardInterval
    ) {
        stakingToken = _stakingToken;
        owner = msg.sender;
        rewardAmount = _rewardAmount;
        rewardInterval = _rewardInterval;
        lastRewardTime = block.timestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(
            IERC20(stakingToken).balanceOf(msg.sender) >= amount,
            "Insufficient balance"
        );

        updateReward(msg.sender);

        IERC20(stakingToken).transfer(address(this), amount);
        stakedBalances[msg.sender] += amount;
        
        // Record the staking time for the user
        stakingTimes[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(stakedBalances[msg.sender] >= amount, "Insufficient staked balance");
        uint256 unstakeTime = stakingTimes[msg.sender] + unstakeLockPeriod;
        require(block.timestamp >= unstakeTime, "Unstaking is locked");

        updateReward(msg.sender);

        stakedBalances[msg.sender] -= amount;
        IERC20(stakingToken).transfer(msg.sender, amount);

        // Reset the staking time to allow users to stake again
        stakingTimes[msg.sender] = 0;

        emit Withdrawn(msg.sender, amount);
    }

    function updateReward(address account) internal {
        uint256 currentTime = block.timestamp;
        uint256 timeSinceLastReward = currentTime - lastRewardTime;
        uint256 rewardPerInterval = rewardAmount / rewardInterval;
        uint256 intervalsPassed = timeSinceLastReward / rewardInterval;
        uint256 rewardToMint = intervalsPassed * rewardPerInterval;

        if (rewardToMint > 0) {
            // Check if the 30-day staking period is over for the user
            if (stakingTimes[account] + stakingPeriod <= currentTime) {
                IERC20(stakingToken).transfer(account, rewardToMint);
            }
        }

        lastRewardTime += intervalsPassed * rewardInterval;
    }

    function getStakedBalance(address account) external view returns (uint256) {
        return stakedBalances[account];
    }
}
