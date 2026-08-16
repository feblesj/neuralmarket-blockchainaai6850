// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NeuralStaking is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public constant COOLDOWN = 2 days;

    uint256 public rewardRatePerSec;
    uint256 public lastUpdate;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;
    address public admin;

    struct StakeInfo {
        uint256 amount;
        uint256 rewardPerTokenPaid;
        uint256 rewards;
        uint256 unlockAt;
        uint256 pending;
    }

    mapping(address => StakeInfo) public stakes;

    event Staked(address indexed user, uint256 amount);
    event CooldownStarted(address indexed user, uint256 amount, uint256 unlockAt);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 rate);

    modifier onlyAdmin() { require(msg.sender == admin, "not admin"); _; }

    constructor(address token_, uint256 rewardRatePerSec_) {
        token = IERC20(token_);
        rewardRatePerSec = rewardRatePerSec_;
        lastUpdate = block.timestamp;
        admin = msg.sender;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return rewardPerTokenStored
            + ((block.timestamp - lastUpdate) * rewardRatePerSec * 1e18) / totalStaked;
    }

    function earned(address user) public view returns (uint256) {
        StakeInfo memory s = stakes[user];
        return s.rewards
            + (s.amount * (rewardPerToken() - s.rewardPerTokenPaid)) / 1e18;
    }

    function _updateReward(address user) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdate = block.timestamp;
        if (user != address(0)) {
            stakes[user].rewards = earned(user);
            stakes[user].rewardPerTokenPaid = rewardPerTokenStored;
        }
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "amount=0");
        _updateReward(msg.sender);
        totalStaked += amount;
        stakes[msg.sender].amount += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function startCooldown(uint256 amount) external nonReentrant {
        StakeInfo storage s = stakes[msg.sender];
        require(amount > 0 && amount <= s.amount, "bad amount");
        _updateReward(msg.sender);
        s.amount -= amount;
        totalStaked -= amount;
        s.pending += amount;
        s.unlockAt = block.timestamp + COOLDOWN;
        emit CooldownStarted(msg.sender, amount, s.unlockAt);
    }

    function withdraw() external nonReentrant {
        StakeInfo storage s = stakes[msg.sender];
        require(s.pending > 0, "nothing pending");
        require(block.timestamp >= s.unlockAt, "cooldown");
        uint256 amt = s.pending;
        s.pending = 0;
        token.safeTransfer(msg.sender, amt);
        emit Withdrawn(msg.sender, amt);
    }

    function claim() external nonReentrant {
        _updateReward(msg.sender);
        uint256 r = stakes[msg.sender].rewards;
        require(r > 0, "no rewards");
        stakes[msg.sender].rewards = 0;
        token.safeTransfer(msg.sender, r);
        emit RewardPaid(msg.sender, r);
    }

    function setRewardRate(uint256 rate) external onlyAdmin {
        _updateReward(address(0));
        rewardRatePerSec = rate;
        emit RewardRateUpdated(rate);
    }

    function fund(uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
    }
}