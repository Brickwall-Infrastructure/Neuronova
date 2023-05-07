// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Neuronova is ERC20Upgradeable, OwnableUpgradeable {
    uint256 public immutable maxTotalSupply;
    uint256 public immutable annualBurnRate;
    uint256 public lastMintTimestamp;
    uint256 public constant YEAR_IN_SECONDS = 31536000; // seconds in a year
    

    constructor(uint256 _maxTotalSupply, uint256 _annualBurnRate) ERC20Upgradeable() {
        maxTotalSupply = _maxTotalSupply;
        annualBurnRate = _annualBurnRate;
        lastMintTimestamp = block.timestamp;
    }

    function mint() external onlyOwner {
        uint256 elapsedTime = block.timestamp - lastMintTimestamp; // time since last mint
        if (elapsedTime == 0) {
            return; // don't mint if less than a second has passed
        }
        uint256 ownerBalance = balanceOf(owner());
        uint256 proportionToMint = elapsedTime * 4 / YEAR_IN_SECONDS; // proportion of owner balance to mint
        uint256 mintAmount = ownerBalance * proportionToMint / 100; // calculate amount to mint
        lastMintTimestamp = block.timestamp; // update last mint timestamp
        require(totalSupply() + mintAmount <= maxTotalSupply, "Max total supply exceeded");
        _mint(owner(), mintAmount); // mint the tokens to the owner
    }

    function burn(uint256 amount) external {
        uint256 senderBalance = balanceOf(msg.sender);
        uint256 totalSupplyBeforeBurn = totalSupply();

        // Check if a year has passed since the last burn
        require(block.timestamp >= lastMintTimestamp + YEAR_IN_SECONDS, "A year has not passed since the last burn");

        // Calculate 5% of the balance of the sender's address at the time of the last burn
        uint256 burnAmount = senderBalance * 5 / 100;

        // Lock the amount of tokens to be burned until the next burn date
        lastMintTimestamp = block.timestamp;

        // Burn the calculated amount of tokens
        require(amount <= burnAmount, "Burn amount exceeds 5% of the sender's balance at the last burn");
        require(totalSupplyBeforeBurn - amount >= maxTotalSupply - maxTotalSupply * annualBurnRate / 100, "Max total supply exceeded");
        _burn(msg.sender, amount);
    }


    // Override transfer and transferFrom functions to include the _beforeTokenTransfer hook
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _beforeTokenTransfer(msg.sender, recipient, amount);
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _beforeTokenTransfer(sender, recipient, amount);
        return super.transferFrom(sender, recipient, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);
        // additional logic for token transfer
    }

    // Override approve function to prevent potential ERC20 approve front-running attack
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    // Add an increaseAllowance function to prevent potential ERC20 approve front-running attack
    function increaseAllowance(address spender, uint256 addedValue) public override returns (bool) {
        _approve(msg.sender, spender, allowance(msg.sender, spender) + addedValue);
        return true;
    }

    // Add a decreaseAllowance function to prevent potential ERC20 approve front-running attack
    function decreaseAllowance(address spender, uint256 subtractedValue) public override returns (bool) {
        uint256 currentAllowance = allowance(msg.sender, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    // Override the allowance function to add a custom message to the revert error
    function allowance(address owner, address spender) public view override returns (uint256) {
        return super.allowance(owner, spender);
    }

    // Override the decimals function to return 18
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    // Override the version function to return the current version of the contract
    function version() public pure returns (string memory) {
        return "1.0.0";
    }

    function name() public pure override returns (string memory) {
        return "Neuronova Infrastructure Token";
    }

    function symbol() public pure override returns (string memory) {
        return "NIT";
    }

}
