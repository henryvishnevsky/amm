//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./Token.sol";

// [] Manage Pool
// [] Manage Deposit
// [] Facilitates Swaps (Trades)
// [] Manage Withdrawals

contract AMM {
    Token public token1;
    Token public token2;

    uint256 public token1Balance;
    uint256 public token2Balance;
    uint256 public K;

    uint256 public totalShares;
    mapping(address => uint256) public shares;
    uint256 constant PRECISION = 10**18;

    event Swap(
        address user,
        address tokenGive,
        uint256 tokenGiveAmount,
        address tokenGet,
        uint256 tokenGetAmount,
        uint256 token1Balance,
        uint256 token2Balance,
        uint256 timestamp

    );

    constructor(Token _token1, Token _token2) {
        token1 = _token1;
        token2 = _token2;
    }

    function addLiquidity(uint256 _token1Amount, uint256 _token2Amount) external {
        // Deposit Tokens
        require(
            token1.transferFrom(msg.sender, address(this), _token1Amount),
            "failed to transfer token1"
        );

        require(
            token2.transferFrom(msg.sender, address(this), _token2Amount),
            "failed to transfer token2"
        );       

        // Issue Shares
        uint256 share; 

        // If adding liquidity for the first time make share 100
        if (totalShares == 0) {
            share = 100 * PRECISION;
        } else {
            uint256 share1 = (totalShares * _token1Amount) / token1Balance;
            uint256 share2 = (totalShares * _token2Amount) / token2Balance;
            require(
                (share1 / 10**3) == (share2 / 10**3), 
                "Must provide equal token amounts"
            );

            share = share1; 
        }

        // Manage Pool
        token1Balance += _token1Amount;
        token2Balance += _token2Amount;
        K = token1Balance * token2Balance; 

        // Update shares
        totalShares += share;
        shares[msg.sender] += share;
    }

    //Determine amount of token2 need when depositing liquidity for token 1
    function calculateToken2Deposit(uint256 _token1Amount) 
        public 
        view 
        returns(uint256 token2Amount) 
    {
        token2Amount = (token2Balance * _token1Amount) / token1Balance; 
    }

    //Determine amount of token1 need when depositing liquidity for token 2
    function calculateToken1Deposit(uint256 _token2Amount) 
        public 
        view 
        returns(uint256 token1Amount) 
    {
        token1Amount = (token1Balance * _token2Amount) / token2Balance; 
    }

    // Returns amount of token2 received when swapping token1
    function calculateToken1Swap(uint256 _token1Amount)
        public
        view
        returns (uint256 token2Amount)
    {
        uint256 token1After = token1Balance +_token1Amount;
        uint256 token2After = K / token1After;
        token2Amount = token2Balance - token2After;

        // Don't let pool go to 0
        if (token2Amount == token2Balance) {
            token2Amount--;
        }

        require(token2Amount < token2Balance, "swap amount is to big");
    }

    function swapToken1(uint256 _token1Amount) 
        external 
        returns(uint256 token2Amount)
    { 
        //Calculate Token 2 Amount
        token2Amount = calculateToken1Swap(_token1Amount);

        // Do Swap
        // 1. Transfer token1 tokens out of user wallet to cotract
        token1.transferFrom(msg.sender, address(this), _token1Amount);
        // 2. Update the token1 balance in the contract
        token1Balance += _token1Amount;
        // 3. Update the token2 balance in the contract
        token1Balance -= token2Amount;
        // 4. Transfer token2 tokens from cotract to user wallet 
        token2.transfer(msg.sender, token2Amount);

        // Emit an event
        emit Swap(
            msg.sender,
            address(token1),
            _token1Amount,
            address(token2),
            token2Amount,
            token1Balance,
            token2Balance,
            block.timestamp
        );
    }

    // Returns amount of token1 received when swapping token2
    function calculateToken2Swap(uint256 _token2mount)
        public
        view
        returns (uint256 token1Amount)
    {
        uint256 token2After = token2Balance + _token2mount;
        uint256 token1After = K / token2After;
        token1Amount = token1Balance - token1After;

        // Don't let pool go to 0
        if (token1Amount == token1Balance) {
            token1Amount--;
        }

        require(token1Amount < token1Balance, "swap amount is to big");
    }

    function swapToken2(uint256 _token2Amount) 
        external 
        returns(uint256 token1Amount)
    { 
        //Calculate Token 1 Amount
        token1Amount = calculateToken2Swap(_token2Amount);

        // Do Swap
        // 1. Transfer token2 tokens out of user wallet to cotract
        token2.transferFrom(msg.sender, address(this), _token2Amount);
        // 2. Update the token2 balance in the contract
        token2Balance += _token2Amount;
        // 3. Update the token1 balance in the contract
        token1Balance -= token1Amount;
        // 4. Transfer token1 tokens from cotract to user wallet 
        token1.transfer(msg.sender, token1Amount);

        // Emit an event
        emit Swap(
            msg.sender,
            address(token2),
            _token2Amount,
            address(token1),
            token1Amount,
            token2Balance,
            token1Balance,
            block.timestamp
        );
    }

}

