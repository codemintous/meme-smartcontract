// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract TokenLaunchpad {
    struct TokenInfo {
        address tokenAddress;
        address owner;
        uint256 pricePerToken;
        uint256 totalSupply;
    }

    mapping(address => TokenInfo) public launchedTokens;
    address[] public allTokens;

    event TokenLaunched(address indexed creator, address token, uint256 supply, uint256 price);
    event TokensPurchased(address indexed buyer, address token, uint256 amount, uint256 cost);
    event TokensSold(address indexed seller, address token, uint256 amount, uint256 ethReturned);

    function launchToken(string memory name, string memory symbol, uint256 supply, uint256 price) public {
        require(supply > 0, "Supply must be greater than zero");
        require(price > 0, "Price must be greater than zero");   



        ERC20Token newToken = new ERC20Token(name, symbol, supply, msg.sender);
        launchedTokens[address(newToken)] = TokenInfo(address(newToken), msg.sender, price, supply);
        allTokens.push(address(newToken));

        emit TokenLaunched(msg.sender, address(newToken), supply, price);
    }

    function buyTokens(address token, uint256 amount) public payable {
        TokenInfo storage info = launchedTokens[token];
        require(info.tokenAddress != address(0), "Token not found");
        require(msg.value >= (amount * info.pricePerToken), "Incorrect ETH sent");

        ERC20Token erc20 = ERC20Token(token);
        require(erc20.allowance(info.owner, address(this)) >= amount, "Not enough allowance");

        erc20.transferFrom(info.owner, msg.sender, amount);
        payable(info.owner).transfer(msg.value);  

        emit TokensPurchased(msg.sender, token, amount, msg.value);
    }

    function sellTokens(address token, uint256 amount) public {
        TokenInfo storage info = launchedTokens[token];
        require(info.tokenAddress != address(0), "Token not found");

        uint256 ethToReturn = amount * info.pricePerToken;
        require(address(this).balance == ethToReturn, "Not enough ETH in contract");

        ERC20 erc20 = ERC20(token);
        require(erc20.allowance(msg.sender, address(this)) >= amount, "Allowance too low");

        // Transfer tokens from user to the creator
        require(erc20.transferFrom(msg.sender, info.owner, amount), "Token transfer failed");

        // Send ETH to user
        payable(msg.sender).transfer(ethToReturn);

        emit TokensSold(msg.sender, token, amount, ethToReturn);
    }



    function addLiquidityToDex(
        address router,
        address token,
        uint256 tokenAmount
    ) external payable {
        require(router != address(0), "Router address is zero");
        require(tokenAmount > 0 && msg.value > 0, "Invalid amounts");

        ERC20 tokenContract = ERC20(token);
        require(tokenContract.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");

        tokenContract.approve(router, tokenAmount);

        IUniswapV2Router02 dexRouter = IUniswapV2Router02(router);
        dexRouter.addLiquidityETH{value: msg.value}(
            token,
            tokenAmount,
            0,
            0,
            msg.sender,
            block.timestamp + 300
        );
    }

    function getAllTokens() public view returns (address[] memory) {
        return allTokens;
    }

    // Receive ETH so contract can send it back to sellers
    receive() external payable {}
}

contract ERC20Token is ERC20, Ownable {
    
    constructor(string memory name, string memory symbol, uint256 initialSupply, address creator)
        ERC20(name, symbol)
        Ownable(creator)
    {
        _mint(creator, initialSupply * 10 ** decimals());

        // Approve TokenLaunchpad (msg.sender) to transfer tokens on behalf of creator
        _approve(creator, msg.sender, initialSupply * 10 ** decimals());
    }
}
