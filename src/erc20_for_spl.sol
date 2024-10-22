// SPDX-License-Identifier: MIT

pragma solidity >0.7.0;
pragma abicoder v2;

import { SPLToken } from './SPLToken.sol';
import  { Metaplex } from  './Metaplex.sol';

SPLToken constant _splToken = SPLToken(0xFf00000000000000000000000000000000000004);
Metaplex constant _metaplex = Metaplex(0xff00000000000000000000000000000000000005);

contract ERC20ForSpl {

    bytes32 immutable public tokenMint;
    bytes32 public addr;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event ApprovalSolana(address indexed owner, bytes32 indexed spender, uint64 amount);
    event TransferSolana(address indexed from, bytes32 indexed to, uint64 amount);

    constructor(bytes32 _tokenMint) {
        require(_splToken.getMint(_tokenMint).isInitialized, "ERC20: invalid token mint");
        require(_metaplex.isInitialized(_tokenMint), "ERC20: missing MetaPlex metadata");

        tokenMint = _tokenMint;
    }

    function name() public view returns (string memory) {
        return _metaplex.name(tokenMint);
    }

    function symbol() public view returns (string memory) {
        return _metaplex.symbol(tokenMint);
    }

    function decimals() public view returns (uint8) {
        return _splToken.getMint(tokenMint).decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _splToken.getMint(tokenMint).supply;
    }

    function balanceOf(address who) public view returns (uint256) {
        bytes32 account = _solanaAccount(who);
        return _splToken     .getAccount(account).amount;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        address owner = msg.sender;

        _approve(owner, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        address from = msg.sender;

        _transfer(from, to, amount);

        return true;
    }


    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        address spender = msg.sender;

        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);

        return true;
    }

    function burn(uint256 amount) public returns (bool) {
        address from = msg.sender;

        _burn(from, amount);

        return true;
    }


    function burnFrom(address from, uint256 amount) public returns (bool) {
        address spender = msg.sender;

        _spendAllowance(from, spender, amount);
        _burn(from, amount);

        return true;
    }

    
    function approveSolana(bytes32 spender, uint64 amount) public returns (bool) {
        address from = msg.sender;
        bytes32 fromSolana = _solanaAccount(from);

        if (amount > 0) {
            _splToken.approve(fromSolana, spender, amount);
        } else {
            _splToken.revoke(fromSolana);
        }

        emit Approval(from, address(0), amount);
        emit ApprovalSolana(from, spender, amount);

        return true;
    }

    function transferSolana(bytes32 to, uint64 amount) public returns (bool) {
        address from = msg.sender;
        bytes32 fromSolana = _solanaAccount(from);

        _splToken.transfer(fromSolana, to, uint64(amount));
        emit Transfer(from, address(0), amount);
        emit TransferSolana(from, to, amount);

        return true;
    }

    function claim(bytes32 from, uint64 amount) external returns (bool) {
        return claimTo(from, msg.sender, amount);
    }
    
    /**
     * @dev Transfers a specified amount of tokens from a Solana account to another Ethereum address.
     * 
     * Emits a `Transfer` event indicating the transfer.
     *
     * Requirements:
     * - The caller must have enough balance in its Solana account.
     * - The recipient's Ethereum address must be initialized.
     * - The amount to be transferred should not exceed the maximum value of uint64 (2^64-1).
     * 
     * @param from Solana address from which tokens are being sent.
     * @param to Ethereum address to which tokens are being sent.
     * @param amount Number of tokens to transfer.
     * @return Returns true if the operation was successful.
     */
    function claimTo(bytes32 from, address to, uint64 amount) public returns (bool) {
        bytes32 toSolana = _solanaAccount(to);

        if (_splToken.isSystemAccount(toSolana)) {
            _splToken.initializeAccount(_salt(to), tokenMint);
  
        }

        _splToken.transferWithSeed(_salt(msg.sender), from, toSolana, amount);

        emit Transfer(address(0), to, amount);

        return true;
    }

    event test(string);
    function testing(bytes32 from,bytes32 toSolana, uint64 amount) public {
        //bytes32 toSolana = _solanaAccount(to);

        // if (_splToken.isSystemAccount(toSolana)) {
        //     _splToken.initializeAccount(_salt(to), tokenMint);
        //     emit test("This Works Well");
  
        // }
        _splToken.transferWithSeed(_salt(msg.sender), from, toSolana, amount);
         emit test("This Works Well");
    }
  
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            _approve(owner, spender, currentAllowance - amount);
        }
    }

    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "ERC20: burn from the zero address");
        require(amount <= type(uint64).max, "ERC20: burn amount exceeds uint64 max");

        bytes32 fromSolana = _solanaAccount(from);

        require(_splToken.getAccount(fromSolana).amount >= amount, "ERC20: burn amount exceeds balance");
        _splToken.burn(tokenMint, fromSolana, uint64(amount));

        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        bytes32 fromSolana = _solanaAccount(from);
        bytes32 toSolana = _solanaAccount(to);

        require(amount <= type(uint64).max, "ERC20: transfer amount exceeds uint64 max");
        require(_splToken.getAccount(fromSolana).amount >= amount, "ERC20: transfer amount exceeds balance");

        if (_splToken.isSystemAccount(toSolana)) {
            _splToken.initializeAccount(_salt(to), tokenMint);
        }

        _splToken.transfer(fromSolana, toSolana, uint64(amount));

        emit Transfer(from, to, amount);
    }

    function _salt(address account) public pure returns (bytes32) {
        return bytes32(uint256(uint160(account)));
    }

    function _solanaAccount(address account) public pure returns (bytes32) {
        return _splToken.findAccount(_salt(account));
    }



    function mintToken(bytes32 minter, address to, uint64 amount) public returns (bool) {
        bytes32 toSolana = _solanaAccount(to);

        if (_splToken.isSystemAccount(toSolana)) {
            _splToken.initializeAccount(_salt(to), tokenMint);
  
        }

        _splToken.mintTo(minter,toSolana,amount);

        return true;
    }

    function getMintAuthority(bytes32 mint) public view returns (bytes32) {
        return _splToken.getMint(mint).mintAuthority;
    }

    function checking(bytes32 salt, bytes32 mint_authority) external returns(bytes32) {
        addr = _splToken.initializeAccount(salt,mint_authority);
        return addr;
    }

}