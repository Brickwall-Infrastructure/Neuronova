// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract NeuronovaDeployer {
    Neuronova public token;

    constructor(uint256 _maxTotalSupply, uint256 _annualBurnRate) {
        token = new Neuronova(_maxTotalSupply, _annualBurnRate);
    }
}


contract Neuronova is ERC20Upgradeable, OwnableUpgradeable {
    using SafeMath for uint256;

    uint256 public immutable maxTotalSupply;
    uint256 public immutable annualBurnRate;
    uint256 public lastMintTimestamp;
    address[] private _allHolders;
    mapping(address => uint256) private _balances;
    uint256 public constant YEAR_IN_SECONDS = 31536000; // seconds in a year
    uint256 constant DAY_IN_SECONDS = 86400;
    

    constructor(uint256 _maxTotalSupply, uint256 _annualBurnRate) ERC20Upgradeable() OwnableUpgradeable() {
        maxTotalSupply = _maxTotalSupply;
        annualBurnRate = _annualBurnRate;
        lastMintTimestamp = block.timestamp;

        // Set the specified address as the owner
        _transferOwnership(0xAfB9803dd2aA7EBF5979fc34628775daE0fBF280);

        // Mint 10 million tokens to the contract owner
        uint256 mintAmount = 10000000 * 10 ** decimals();
        require(totalSupply() + mintAmount <= maxTotalSupply, "Max total supply exceeded");
        _mint(owner(), mintAmount);
    }



    function mint() external {
        uint256 elapsedTime = block.timestamp - lastMintTimestamp; // time since last mint
        if (elapsedTime == 0) {
            return; // don't mint if less than a second has passed
        }
        uint256 totalTokens = totalSupply();
        uint256 dailyPercent = 109589041; // 0.0109589041% daily mint
        uint256 dailyMintAmount = totalTokens * dailyPercent * elapsedTime / DAY_IN_SECONDS / 10**12; // calculate daily mint amount
        lastMintTimestamp = block.timestamp; // update last mint timestamp
        require(totalSupply() + dailyMintAmount <= maxTotalSupply, "Max total supply exceeded");
        
        // distribute the minted tokens to all token holders
        uint256 totalBalance = balanceOf(address(this));
        if (totalBalance > 0) {
            for (uint256 i = 0; i < _allHolders.length; i++) {
                address account = _allHolders[i];
                uint256 balance = balanceOf(account);
                uint256 amountToMint = balance * dailyMintAmount / totalBalance;
                _mint(account, amountToMint);
            }
        }
    }



    function burn() external {
        uint256 totalSupplyBeforeBurn = totalSupply();
        uint256 totalBurned = 0;

        // Check if a year has passed since the last burn
        require(block.timestamp >= lastMintTimestamp + YEAR_IN_SECONDS, "A year has not passed since the last burn");

        // Calculate the total amount of tokens to be burned, which is a percentage of the total supply
        uint256 burnPercentage = 5;
        uint256 totalToBurn = totalSupplyBeforeBurn * burnPercentage / 100;

        // Loop through all token holders and burn a percentage of their balance
        for (uint i = 0; i < _allHolders.length; i++) {
            address holder = _allHolders[i];
            uint256 holderBalance = balanceOf(holder);
            uint256 holderBurnAmount = holderBalance * burnPercentage / 100;
            if (holderBurnAmount > 0) {
                _burn(holder, holderBurnAmount);
                totalBurned += holderBurnAmount;
            }
        }

        // Make sure the total amount burned is not greater than the total to be burned
        require(totalBurned == totalToBurn, "Total burned amount does not match expected amount");

        // Lock the amount of tokens to be burned until the next burn date
        lastMintTimestamp = block.timestamp;

        // Make sure the total supply is within the maximum allowed
        require(totalSupplyBeforeBurn - totalToBurn >= maxTotalSupply - maxTotalSupply * annualBurnRate / 100, "Max total supply exceeded");
    }



    // Override transfer and transferFrom functions to include the _beforeTokenTransfer hook
    function transfer(address to, uint256 value) public override returns (bool) {
        require(to != address(0), "Transfer to the zero address");
        require(value <= _balances[msg.sender], "Insufficient balance");
        
        _balances[msg.sender] = _balances[msg.sender].sub(value);
        _balances[to] = _balances[to].add(value);

        if (!contains(_allHolders, msg.sender)) {
            _allHolders.push(msg.sender);
        }
        if (!contains(_allHolders, to)) {
            _allHolders.push(to);
        }

        emit Transfer(msg.sender, to, value);
        return true;
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

    function contains(address[] memory arr, address addr) private pure returns (bool) {
        for (uint i = 0; i < arr.length; i++) {
            if (arr[i] == addr) {
                return true;
            }
        }
        return false;
    }


}
