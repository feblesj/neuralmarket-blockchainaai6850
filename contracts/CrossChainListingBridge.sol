// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMessageEndpoint {
    function send(uint16 dstChainId, bytes calldata destination, bytes calldata payload) external payable;
}

contract CrossChainListingBridge {
    IMessageEndpoint public endpoint;
    address public owner;

    struct MirroredListing {
        uint256 srcListingId;
        address provider;
        uint256 price;
        string metadataURI;
        uint16 srcChainId;
    }

    uint256 public mirroredCount;
    mapping(uint256 => MirroredListing) public mirrored;
    mapping(uint16 => bytes) public trustedRemote;

    event ListingSent(uint256 indexed srcListingId, uint16 dstChainId);
    event ListingReceived(uint256 indexed localId, uint256 srcListingId, uint16 srcChainId);
    event TrustedRemoteSet(uint16 chainId, bytes remote);

    modifier onlyOwner() { require(msg.sender == owner, "not owner"); _; }

    constructor(address endpoint_) {
        endpoint = IMessageEndpoint(endpoint_);
        owner = msg.sender;
    }

    function setTrustedRemote(uint16 chainId, bytes calldata remote) external onlyOwner {
        trustedRemote[chainId] = remote;
        emit TrustedRemoteSet(chainId, remote);
    }

    function sendListing(
        uint16 dstChainId,
        uint256 srcListingId,
        address provider,
        uint256 price,
        string calldata metadataURI
    ) external payable {
        bytes memory payload = abi.encode(srcListingId, provider, price, metadataURI, _thisChainId());
        endpoint.send{value: msg.value}(dstChainId, trustedRemote[dstChainId], payload);
        emit ListingSent(srcListingId, dstChainId);
    }

    function lzReceive(uint16 srcChainId, bytes calldata srcAddress, bytes calldata payload) external {
        require(msg.sender == address(endpoint), "only endpoint");
        (uint256 srcId, address provider, uint256 price, string memory uri, uint16 originChain) =
            abi.decode(payload, (uint256, address, uint256, string, uint16));
        uint256 localId = ++mirroredCount;
        mirrored[localId] = MirroredListing(srcId, provider, price, uri, originChain);
        emit ListingReceived(localId, srcId, srcChainId);
    }

    function _thisChainId() internal view returns (uint16) {
        return uint16(block.chainid);
    }
}

contract MockEndpoint is IMessageEndpoint {
    function send(uint16 srcChainId, bytes calldata destination, bytes calldata payload) external payable {
        address dest = _toAddress(destination);
        CrossChainListingBridge(dest).lzReceive(srcChainId, abi.encodePacked(msg.sender), payload);
    }

    function _toAddress(bytes memory b) internal pure returns (address addr) {
        require(b.length >= 20, "bad addr");
        assembly { addr := mload(add(b, 20)) }
    }
}