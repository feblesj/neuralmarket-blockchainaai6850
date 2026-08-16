// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function decimals() external view returns (uint8);
}

contract AIDataOracle {
    AggregatorV3Interface public feed;
    address public admin;
    uint256 public maxStale = 3 hours;

    event FeedUpdated(address indexed newFeed);

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    constructor(address feed_) {
        feed = AggregatorV3Interface(feed_);
        admin = msg.sender;
    }

    function setFeed(address feed_) external onlyAdmin {
        feed = AggregatorV3Interface(feed_);
        emit FeedUpdated(feed_);
    }

    function latestData() public view returns (int256 answer, uint8 decimals) {
        (, int256 a, , uint256 updatedAt, ) = feed.latestRoundData();
        require(a > 0, "bad answer");
        require(block.timestamp - updatedAt <= maxStale, "stale data");
        return (a, feed.decimals());
    }
}

contract MockAggregator is AggregatorV3Interface {
    int256 private _answer;
    uint8 private _decimals;
    uint256 private _updatedAt;

    constructor(int256 answer_, uint8 decimals_) {
        _answer = answer_;
        _decimals = decimals_;
        _updatedAt = block.timestamp;
    }

    function setAnswer(int256 answer_) external {
        _answer = answer_;
        _updatedAt = block.timestamp;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, _answer, _updatedAt, _updatedAt, 1);
    }
}