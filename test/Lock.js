const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenLaunchpad", function () {
  let TokenLaunchpad, ERC20Token;
  let tokenLaunchpad, erc20Token;
  let owner, user1, user2;
  let tokenAddress;
  const TOKEN_NAME = "Test Token";
  const TOKEN_SYMBOL = "TEST";
  const TOTAL_SUPPLY = ethers.parseEther("1000000"); // 1 million tokens with 18 decimals
  const TOKEN_PRICE = ethers.parseEther("0.0001"); // Price in ETH per token

  beforeEach(async function () {
    // Get signers
    [owner, user1, user2] = await ethers.getSigners();
    
    // Deploy the ERC20Token contract
    ERC20Token = await ethers.getContractFactory("ERC20Token");
    
    // Deploy the TokenLaunchpad contract
    TokenLaunchpad = await ethers.getContractFactory("TokenFactory");
    tokenLaunchpad = await TokenLaunchpad.deploy();
    await tokenLaunchpad.deployed();
  });

  describe("Launch Token", function () {
    it("Should launch a new token successfully", async function () {
      // Launch a new token
      const tx = await tokenLaunchpad.launchToken(TOKEN_NAME, TOKEN_SYMBOL, TOTAL_SUPPLY, TOKEN_PRICE);
      const receipt = await tx.wait();
      
      // Get the token address from the emitted event
      const event = receipt.events.find(e => e.event === "TokenLaunched");
      tokenAddress = event.args.token;
      
      // Verify the token info is stored correctly
      const tokenInfo = await tokenLaunchpad.launchedTokens(tokenAddress);
      expect(tokenInfo.tokenAddress).to.equal(tokenAddress);
      expect(tokenInfo.pricePerToken.toString()).to.equal(TOKEN_PRICE.toString());
      expect(tokenInfo.totalSupply.toString()).to.equal(TOTAL_SUPPLY.toString());
      
      // Verify the token is added to allTokens array
      const allTokens = await tokenLaunchpad.getAllTokens();
      expect(allTokens[0]).to.equal(tokenAddress);
    });
  });

  describe("Buy Tokens", function () {
    beforeEach(async function () {
      // Launch a token first
      const tx = await tokenLaunchpad.launchToken(TOKEN_NAME, TOKEN_SYMBOL, TOTAL_SUPPLY, TOKEN_PRICE);
      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === "TokenLaunched");
      tokenAddress = event.args.token;
      
      // Create instance of the token
      erc20Token = await ERC20Token.attach(tokenAddress);
    });

    it("Should allow users to buy tokens with correct ETH amount", async function () {
      const tokensToBuy = ethers.parseEther("1000"); // 1000 tokens
      
      // Calculate required ETH: (amount * price) / 1e18
      const requiredEth = tokensToBuy * TOKEN_PRICE / ethers.parseEther("1");
      
      // User1 buys tokens
      await tokenLaunchpad.connect(user1).buyTokens(tokenAddress, tokensToBuy, {
        value: requiredEth
      });
      
      // Verify user received the tokens
      const balance = await erc20Token.balanceOf(user1.address);
      expect(balance.toString()).to.equal(tokensToBuy.toString());
      
      // Verify user's tracked balance in the launchpad
      const trackedBalance = await tokenLaunchpad.userTokenBalances(user1.address, tokenAddress);
      expect(trackedBalance.toString()).to.equal(tokensToBuy.toString());
    });

    it("Should revert if insufficient ETH is sent", async function () {
      const tokensToBuy = ethers.parseEther("1000"); // 1000 tokens
      
      // Calculate required ETH but send less
      const requiredEth = tokensToBuy * TOKEN_PRICE / ethers.parseEther("1");
      const lessThanRequired = requiredEth - ethers.parseEther("0.00001");
      
      // Transaction should revert
      await expect(
        tokenLaunchpad.connect(user1).buyTokens(tokenAddress, tokensToBuy, {
          value: lessThanRequired
        })
      ).to.be.revertedWith("Incorrect ETH sent");
    });
  });

  describe("Sell Tokens", function () {
    beforeEach(async function () {
      // Launch a token
      const tx = await tokenLaunchpad.launchToken(TOKEN_NAME, TOKEN_SYMBOL, TOTAL_SUPPLY, TOKEN_PRICE);
      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === "TokenLaunched");
      tokenAddress = event.args.token;
      
      // Create instance of the token
      erc20Token = await ERC20Token.attach(tokenAddress);
      
      // User1 buys tokens first
      const tokensToBuy = parseEther("1000"); // 1000 tokens
      const requiredEth = tokensToBuy * TOKEN_PRICE / ethers.parseEther("1");
      await tokenLaunchpad.connect(user1).buyTokens(tokenAddress, tokensToBuy, {
        value: requiredEth
      });
    });

    it("Should allow users to sell tokens and receive ETH", async function () {
      const tokensToSell = ethers.parseEther("500"); // 500 tokens
      
      // Get user's ETH balance before selling
      const balanceBefore = await ethers.provider.getBalance(user1.address);
      
      // User1 sells tokens
      const tx = await tokenLaunchpad.connect(user1).sellTokens(tokenAddress, tokensToSell);
      const receipt = await tx.wait();
      
      // Calculate gas used
      const gasUsed = receipt.gasUsed * receipt.effectiveGasPrice;
      
      // Get user's ETH balance after selling
      const balanceAfter = await ethers.provider.getBalance(user1.address);
      
      // Calculate expected ETH return
      const expectedEthReturn = tokensToSell * TOKEN_PRICE / ethers.parseEther("1");
      
      // Verify user received the correct amount of ETH (accounting for gas)
      const ethReceived = balanceAfter - balanceBefore + gasUsed;
      expect(ethReceived.toString()).to.equal(expectedEthReturn.toString());
      
      // Verify user's token balance decreased
      const tokenBalance = await erc20Token.balanceOf(user1.address);
      expect(tokenBalance.toString()).to.equal(ethers.parseEther("500").toString()); // Should have 500 tokens left
      
      // Verify user's tracked balance in the launchpad decreased
      const trackedBalance = await tokenLaunchpad.userTokenBalances(user1.address, tokenAddress);
      expect(trackedBalance.toString()).to.equal(ethers.parseEther("500").toString());
    });

    it("Should revert if user tries to sell more tokens than they have", async function () {
      const tokensToSell = ethers.parseEther("1500"); // More than the 1000 tokens they bought
      
      // Transaction should revert
      await expect(
        tokenLaunchpad.connect(user1).sellTokens(tokenAddress, tokensToSell)
      ).to.be.revertedWith("Not enough tokens in your wallet");
    });
  });

  describe("Add Liquidity to DEX", function () {
    let mockRouter;
    
    beforeEach(async function () {
      // Deploy a mock router contract for testing
      const MockRouter = await ethers.getContractFactory("MockUniswapV2Router02");
      mockRouter = await MockRouter.deploy();
      await mockRouter.deployed();
      
      // Launch a token
      const tx = await tokenLaunchpad.launchToken(TOKEN_NAME, TOKEN_SYMBOL, TOTAL_SUPPLY, TOKEN_PRICE);
      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === "TokenLaunched");
      tokenAddress = event.args.token;
      
      // Create instance of the token
      erc20Token = await ERC20Token.attach(tokenAddress);
    });

    it("Should add liquidity to DEX successfully", async function () {
      // User1 buys tokens first
      const tokensToBuy = ethers.parseEther("10000"); // 10000 tokens
      const requiredEth = tokensToBuy.mul(TOKEN_PRICE).div(parseEther("1"));
      await tokenLaunchpad.connect(user1).buyTokens(tokenAddress, tokensToBuy, {
        value: requiredEth
      });
      
      // Approve the launchpad to spend tokens
      await erc20Token.connect(user1).approve(tokenLaunchpad.address, ethers.parseEther("5000"));
      
      // Add liquidity to DEX
      const ethAmount = ethers.parseEther("1");
      const tokenAmount = ethers.parseEther("5000");
      
      await tokenLaunchpad.connect(user1).addLiquidityToDex(
        mockRouter.address,
        tokenAddress,
        tokenAmount,
        { value: ethAmount }
      );
      
      // Verify the router received approval for tokens (this would be tested with a real mock implementation)
      // Verify the liquidity was added successfully (this would be tested with a real mock implementation)
    });
  });
});