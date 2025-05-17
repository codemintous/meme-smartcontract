// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AgentToken
 * @dev ERC20 token for AI agents with image management functionality
 */
contract AgentToken is ERC20, Ownable {
    address public platformAddress;
    uint256 public constant IMAGE_FEE = 1 * 10**18; // 1 token to add an image
    
    struct ImageInfo {
        string imageLink;
        string description;
        address creator;
    }
    
    ImageInfo[] public images;
    mapping(address => ImageInfo[]) public creatorToImages;
    address[] public creators;
    
    event ImageAdded(address indexed creator, string imageLink, string description);
    event TokensMinted(uint256 amount);
    event TokensBurned(uint256 amount);
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address _owner,
        address _platformAddress
    ) ERC20(name, symbol) Ownable(_owner) {
        platformAddress = _platformAddress;
        _mint(address(this), initialSupply * 10**decimals());
    }
    
    /**
     * @dev Add an image by burning the required token fee
     * @param imageLink Link to the image
     * @param description Description of the image
     */
    function addImage(string memory imageLink, string memory description) external {
        // Check if contract itself has enough tokens
        require(balanceOf(address(this)) >= IMAGE_FEE, "Contract has insufficient tokens for adding image");
        
        // Burn the tokens from the contract's balance
        _burn(address(this), IMAGE_FEE);
        
        ImageInfo memory newImage = ImageInfo({
            imageLink: imageLink,
            description: description,
            creator: msg.sender
        });
        
        images.push(newImage);
        
        if (creatorToImages[msg.sender].length == 0) {
            creators.push(msg.sender);
        }
        
        creatorToImages[msg.sender].push(newImage);
        emit ImageAdded(msg.sender, imageLink, description);
    }
    
    /**
     * @dev Mint new tokens to the contract's balance (can be called by anyone)
     * @param amount Amount of tokens to mint
     */
    function mint(uint256 amount) external {
        _mint(address(this), amount * 10**decimals());
        emit TokensMinted(amount);
    }
    
    /**
     * @dev Burn tokens from the contract's balance (can be called by anyone)
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external {
        require(balanceOf(address(this)) >= amount * 10**decimals(), "Contract has insufficient tokens for burning");
        _burn(address(this), amount * 10**decimals());
        emit TokensBurned(amount);
    }
    
    /**
     * @dev Get all images
     * @return Array of ImageInfo structs
     */
    function getAllImages() external view returns (ImageInfo[] memory) {
        return images;
    }
    
    /**
     * @dev Get images by creator
     * @param creator Address of the creator
     * @return Array of ImageInfo structs
     */
    function getImagesByCreator(address creator) external view returns (ImageInfo[] memory) {
        return creatorToImages[creator];
    }
    
    /**
     * @dev Get number of creators
     * @return Number of unique creators
     */
    function getCreatorCount() external view returns (uint256) {
        return creators.length;
    }
    
    /**
     * @dev Get creator address by index
     * @param index Index of the creator in the array
     * @return Creator address
     */
    function getCreatorByIndex(uint256 index) external view returns (address) {
        require(index < creators.length, "Index out of bounds");
        return creators[index];
    }
    
    /**
     * @dev Withdraw tokens to owner (can only be called by owner)
     */
    function withdrawTokens() external onlyOwner {
        uint256 balance = balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        _transfer(address(this), owner(), balance);
    }
}