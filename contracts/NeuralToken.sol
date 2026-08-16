// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

contract NeuralToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    uint256 public immutable cap;

    constructor(address initialOwner, uint256 cap_)
        ERC20("NeuralToken", "NRL")
        ERC20Permit("NeuralToken")
        Ownable(initialOwner)
    {
        require(cap_ > 0, "cap=0");
        cap = cap_;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= cap, "cap exceeded");
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner_)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner_);
    }
}