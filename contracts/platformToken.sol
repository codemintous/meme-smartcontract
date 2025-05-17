// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MemeMinto is ERC20, ERC20Burnable, Ownable {
    // Events
    event TokensMinted(address indexed receiver, uint256 amount);
    event TokensBurned(address indexed burner, uint256 amount);
     event TokensTransferred(address indexed from, address indexed to, uint256 amount);
    constructor() ERC20("MemeMinto", "MEME") Ownable(msg.sender) {}
    
    // Free mint function - anyone can mint tokens
    function mintTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        _mint(msg.sender, amount);
        emit TokensMinted(msg.sender, amount);
    }
    
    // Owner can mint tokens to any address
    function mintTokensTo(address to, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
    
    // Override the burn function from ERC20Burnable to emit our event
    function burn(uint256 amount) public override {
        super.burn(amount);
        emit TokensBurned(msg.sender, amount);
    }
    
    // Override the burnFrom function from ERC20Burnable to emit our event
    function burnFrom(address account, uint256 amount) public override {
        super.burnFrom(account, amount);
        emit TokensBurned(account, amount);
    }
    
    // Check token balance of any address
    function getBalance(address user) external view returns (uint256) {
        return balanceOf(user);
    }
       function transferTokens(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        _transfer(msg.sender, to, amount);
        emit TokensTransferred(msg.sender, to, amount);
        return true;
    }
    
    // Function to receive ETH (for future expansion if needed)
    receive() external payable {}
}