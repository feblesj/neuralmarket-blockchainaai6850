// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts@5.0.2/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts@5.0.2/access/AccessControl.sol";
import "@openzeppelin/contracts@5.0.2/utils/ReentrancyGuard.sol";
import "./AIDataOracle.sol";

contract AIModelMarketplace is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant PROVIDER_ROLE = keccak256("PROVIDER_ROLE");

    IERC20 public immutable token;
    AIDataOracle public oracle;
    address public feeSink;
    uint96 public feeBps = 250;
    int256 public minQualityIndex;

    struct Listing {
        address provider;
        uint256 price;
        string metadataURI;
        bool active;
    }

    struct SealedBid {
        bytes32 commitment;
        bool revealed;
    }

    uint256 public nextListingId = 1;
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => mapping(address => bool)) public hasAccess;
    mapping(uint256 => mapping(address => SealedBid)) public bids;

    event Listed(uint256 indexed id, address indexed provider, uint256 price, string metadataURI);
    event Purchased(uint256 indexed id, address indexed buyer, uint256 price, uint256 fee);
    event AccessGranted(uint256 indexed id, address indexed user);
    event BidCommitted(uint256 indexed id, address indexed bidder, bytes32 commitment);
    event BidRevealed(uint256 indexed id, address indexed bidder, uint256 amount);
    event FeeUpdated(uint96 feeBps);
    event OracleUpdated(address oracle);
    event MinQualityUpdated(int256 minQualityIndex);

    constructor(address token_, address oracle_, address feeSink_, address governor_) {
        token = IERC20(token_);
        oracle = AIDataOracle(oracle_);
        feeSink = feeSink_;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, governor_);
    }

    function setFeeBps(uint96 newFeeBps) external onlyRole(GOVERNOR_ROLE) {
        require(newFeeBps <= 1000, "fee>10%");
        feeBps = newFeeBps;
        emit FeeUpdated(newFeeBps);
    }

    function setOracle(address oracle_) external onlyRole(GOVERNOR_ROLE) {
        oracle = AIDataOracle(oracle_);
        emit OracleUpdated(oracle_);
    }

    function setMinQualityIndex(int256 v) external onlyRole(GOVERNOR_ROLE) {
        minQualityIndex = v;
        emit MinQualityUpdated(v);
    }

    function registerProvider(address who) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(PROVIDER_ROLE, who);
    }

    function list(uint256 price, string calldata metadataURI)
        external
        onlyRole(PROVIDER_ROLE)
        returns (uint256 id)
    {
        require(price > 0, "price=0");
        (int256 quality, ) = oracle.latestData();
        require(quality >= minQualityIndex, "quality below threshold");
        id = nextListingId++;
        listings[id] = Listing(msg.sender, price, metadataURI, true);
        emit Listed(id, msg.sender, price, metadataURI);
    }

    function purchase(uint256 id) external nonReentrant {
        Listing memory l = listings[id];
        require(l.active, "inactive");
        require(!hasAccess[id][msg.sender], "already own");

        uint256 fee = (l.price * feeBps) / 10_000;
        uint256 toProvider = l.price - fee;

        token.safeTransferFrom(msg.sender, l.provider, toProvider);
        if (fee > 0) token.safeTransferFrom(msg.sender, feeSink, fee);

        hasAccess[id][msg.sender] = true;
        emit Purchased(id, msg.sender, l.price, fee);
        emit AccessGranted(id, msg.sender);
    }

    function commitBid(uint256 id, bytes32 commitment) external {
        require(listings[id].active, "inactive");
        bids[id][msg.sender] = SealedBid(commitment, false);
        emit BidCommitted(id, msg.sender, commitment);
    }

    function revealBid(uint256 id, uint256 amount, bytes32 salt) external nonReentrant {
        SealedBid storage b = bids[id][msg.sender];
        require(b.commitment != bytes32(0), "no bid");
        require(!b.revealed, "revealed");
        require(
            b.commitment == keccak256(abi.encodePacked(amount, salt, msg.sender)),
            "bad reveal"
        );
        b.revealed = true;

        Listing memory l = listings[id];
        require(l.active, "inactive");
        uint256 fee = (amount * feeBps) / 10_000;
        token.safeTransferFrom(msg.sender, l.provider, amount - fee);
        if (fee > 0) token.safeTransferFrom(msg.sender, feeSink, fee);

        hasAccess[id][msg.sender] = true;
        emit BidRevealed(id, msg.sender, amount);
        emit AccessGranted(id, msg.sender);
    }

    function grantAccess(uint256 id, address user) external {
        require(listings[id].provider == msg.sender, "not provider");
        hasAccess[id][user] = true;
        emit AccessGranted(id, user);
    }

    function canDecrypt(uint256 id, address user) external view returns (bool) {
        return hasAccess[id][user];
    }
}