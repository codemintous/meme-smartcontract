// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./agentToken.sol";

/**
 * @title AgentFactory
 * @dev Contract for creating and managing AI agent tokens
 */
contract AgentFactory is Ownable {
    // Struct to store agent details
    struct AgentInfo {
        string name;
        address tokenAddress;
        string symbol;
    }
    
    // Constants
    uint256 public constant INITIAL_SUPPLY = 100; // 100 tokens initial supply
    
    // State variables
    mapping(string => address) public nameToAgentToken;
    mapping(address => string) public agentTokenToName; 
    AgentInfo[] public agents;
    
    // Events
    event AgentCreated(string name, string symbol, address tokenAddress);
    event TokensMinted(string agentName, uint256 amount);
    event TokensBurned(string agentName, uint256 amount);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Creates a new AI agent with its own ERC20 token
     * @param name Name of the agent/token
     * @param symbol Symbol for the token
     */
    function createAgent(string memory name, string memory symbol) external {
        // Check if agent name is already registered
        require(nameToAgentToken[name] == address(0), "Agent name already taken");
        
        // Create a new AgentToken contract for this agent
        AgentToken newAgentToken = new AgentToken(
            name,
            symbol,
            INITIAL_SUPPLY,
            address(this), // Factory is the owner of the token contract
            address(this)  // Factory is also the platform address
        );
        
        // Store the agent information
        address tokenAddress = address(newAgentToken);
        nameToAgentToken[name] = tokenAddress;
        agentTokenToName[tokenAddress] = name;
        
        // Add to the list of agents
        agents.push(AgentInfo({
            name: name,
            tokenAddress: tokenAddress,
            symbol: symbol
        }));
        
        emit AgentCreated(name, symbol, tokenAddress);
    }
    
    /**
     * @dev Mint tokens for a specific agent (they stay in the contract)
     * @param agentName Name of the agent
     * @param amount Amount of tokens to mint
     */
    function mintAgentTokens(string memory agentName, uint256 amount) external onlyOwner {
        address tokenAddress = nameToAgentToken[agentName];
        require(tokenAddress != address(0), "Agent not found");
        
        AgentToken agentToken = AgentToken(tokenAddress);
        agentToken.mint(amount);
        
        emit TokensMinted(agentName, amount);
    }
    
    /**
     * @dev Burn tokens from a specific agent's contract balance
     * @param agentName Name of the agent
     * @param amount Amount of tokens to burn
     */
    function burnAgentTokens(string memory agentName, uint256 amount) external onlyOwner {
        address tokenAddress = nameToAgentToken[agentName];
        require(tokenAddress != address(0), "Agent not found");
        
        AgentToken agentToken = AgentToken(tokenAddress);
        agentToken.burn(amount);
        
        emit TokensBurned(agentName, amount);
    }
    
    /**
     * @dev Get all created agents
     * @return Array of AgentInfo structs
     */
    function getAllAgents() external view returns (AgentInfo[] memory) {
        return agents;
    }
    
    /**
     * @dev Get total number of agents
     * @return Number of agents created
     */
    function getAgentCount() external view returns (uint256) {
        return agents.length;
    }
    
    /**
     * @dev Get agent info by index
     * @param index Index of the agent in the array
     * @return Agent information
     */
    function getAgentByIndex(uint256 index) external view returns (AgentInfo memory) {
        require(index < agents.length, "Index out of bounds");
        return agents[index];
    }
    
    /**
     * @dev Get agent token address by name
     * @param name Name of the agent
     * @return Token contract address
     */
    function getAgentAddressByName(string memory name) external view returns (address) {
        return nameToAgentToken[name];
    }
}