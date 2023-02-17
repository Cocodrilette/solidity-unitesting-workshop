// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

contract ERC20Token {
    // * state variables
    address owner;

    string public name;
    string public symbol;

    uint256 public totalSupply;
    uint8 public decimals = 18;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // * events
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    // * modifiers
    modifier OnlyOwner() {
        if (owner != msg.sender) revert("ERC20: Not an owner");
        _;
    }

    // * functions
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply
    ) {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        totalSupply = _initialSupply;

        _balances[msg.sender] = totalSupply;
    }

    function transfer(
        address _to,
        uint256 _value
    ) public OnlyOwner returns (bool success) {
        _balances[msg.sender] -= _value;
        _balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);

        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        uint256 _allowance = allowance(_from, msg.sender);

        if (_allowance == 0) revert("ERC20: Insufficient allowance");
        if (_value > _allowance) revert("ERC20: Value too high");

        _balances[_from] -= _value;
        _balances[_to] += _value;
        _allowances[_from][msg.sender] -= _value;

        emit Transfer(msg.sender, _to, _value);

        return true;
    }

    function approve(
        address _spender,
        uint256 _value
    ) public returns (bool success) {
        if (_value >= balanceOf(msg.sender))
            revert("ERC20: ERC20 Insufficient balance");

        _allowances[msg.sender][_spender] = _value;

        return true;
    }

    function allowance(
        address _owner,
        address _spender
    ) public view returns (uint256 remaining) {
        return _allowances[_owner][_spender];
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return _balances[_owner];
    }
}
