// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title This contract allow multiple user manage founds together.
/// @author https://github.com/cocodrilette
/// @notice This contract is indeed to be educational only. It is not a secure contract.
contract MultiSign {
    struct Transaction {
        address to;
        uint256 value;
        bool executed;
        bytes data;
    }

    /// @notice The required confirmations to execute a transaction
    uint256 public threshold;

    mapping(address => bool) private owners;
    uint256 public ownersCount;

    mapping(bytes32 => Transaction) public transactions;

    mapping(bytes32 => mapping(address => bool)) public confirmations;

    event TransactionCreated(bytes32 txId);
    event TransactionSubmitted(address destination, uint256 value);
    event TransactionConfirmed(address owner, bytes32 txId);
    // event TransactionExecuted(uint256 txId, address destination, uint256 value);

    error NotAnOwner(address account);

    modifier onlyOwners() {
        if (!isOwner(msg.sender)) revert NotAnOwner(msg.sender);
        _;
    }

    modifier validAddress(address _to) {
        if (_to == address(0) && _to == address(this))
            revert("MultiSign: Invalid address.");
        _;
    }

    modifier validData(bytes memory _data) {
        if (_data.length == 0) revert("MultiSign: Empty data is not valid.");
        _;
    }

    modifier isExistingTransaction(bytes32 _txId) {
        if (
            keccak256(abi.encode(transactions[_txId])) !=
            keccak256(abi.encode(transactions[bytes32(0x0)]))
        ) revert("MultiSign: Transaction does not exist.");
        _;
    }

    /// @param _owners: The user that can `submit`, `confirm` or `execute` transactions.
    /// @param _threshold: The required confirmation to excuted a transaction.
    constructor(address[] memory _owners, uint256 _threshold) {
        _setOwners(_owners);
        _setThreshold(_threshold);
    }

    function addTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    )
        internal
        onlyOwners
        validAddress(_to)
        validData(_data)
        returns (bytes32 _txId)
    {
        _txId = _getHashId(_to, _value, _data);

        transactions[_txId] = Transaction({
            to: _to,
            value: _value,
            executed: false,
            data: _data
        });

        emit TransactionCreated(_txId);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwners {
        _confirmTransaction(addTransaction(_to, _value, _data));
        emit TransactionSubmitted(_to, _value);
    }

    function confirmTransaction(bytes32 _txId) public onlyOwners {
        _confirmTransaction(_txId);
    }

    function _confirmTransaction(
        bytes32 _txId
    ) internal isExistingTransaction(_txId) {
        confirmations[_txId][msg.sender] = true;

        emit TransactionConfirmed(msg.sender, _txId);

        // if (getConfirmationsCount(_txId) >= required) {
        //     executeTransaction(_txId);
        // } else {
        //     emit TransactionConfirmed(msg.sender, _txId);
        // }
    }

    // function getConfirmationsCount(
    //     uint256 transactionId
    // ) public view returns (uint256) {
    //     uint256 confirmationsCount;
    //     for (uint256 i = 0; i < owners.length; i++) {
    //         if (confirmations[transactionId][owners[i]]) {
    //             confirmationsCount++;
    //         }
    //     }
    //     return confirmationsCount;
    // }

    // function isConfirmed(uint256 _txId) public view returns (bool) {
    //     if (getConfirmationsCount(_txId) < required) return false;
    //     return true;
    // }

    // function executeTransaction(uint256 _txId) public onlyOwners {
    //     Transaction storage _tx = transactions[_txId];
    //     if (!isConfirmed(_txId)) revert();
    //     if (_tx.value > address(this).balance) revert("INSUFFITIENT_FUNDS");
    //     _tx.executed = true;
    //     (bool s, ) = payable(_tx.to).call{value: _tx.value}(_tx.data);
    //     if (!s) revert("TRANSACTION_FAILED");

    //     emit TransactionExecuted(_txId, _tx.to, _tx.value);
    // }

    function isOwner(address _address) public view returns (bool _isOwner) {
        _isOwner = owners[_address];
    }

    function _setOwners(address[] memory _owners) private {
        if (_owners.length == 0) {
            revert(
                "MultiSign: No valid owners length. At least one is required."
            );
        }
        for (uint i = 0; i < _owners.length; i++) {
            owners[_owners[i]] = true;
            ownersCount++;
        }
    }

    function _setThreshold(uint256 _threshold) private {
        if (_threshold == 0)
            revert(
                "MultiSign: Invalid value threshold value of 0. Required threshold > 1"
            );
        if (_threshold > ownersCount)
            revert("MultiSign. Setting more threshold than owners.");
        threshold = _threshold;
    }

    function _getHashId(
        address _to,
        uint256 _value,
        bytes memory _data
    ) private view returns (bytes32 _hashId) {
        _hashId = keccak256(
            abi.encodePacked(_to, _value, _data, block.timestamp)
        );
    }

    receive() external payable {}

    fallback() external payable {}
}
