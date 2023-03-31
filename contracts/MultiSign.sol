// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

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

    address[] private owners;
    uint256 public ownersCount;

    mapping(bytes32 => Transaction) public transactions;

    mapping(bytes32 => mapping(address => bool)) public confirmations;

    event TransactionCreated(bytes32 indexed txId);
    event TransactionSubmitted(address destination, uint256 value);
    event TransactionConfirmed(address owner, bytes32 indexed txId);
    event TransactionExecuted(bytes32 txId, address destination, uint256 value);
    event FoundsAdded(address indexed owner, uint256 value);

    error NotAnOwner(address account);

    /**
     * @dev Modifier that checks if the caller is an owner of the contract.
     * @notice The function using this modifier will only be executed if the caller is an owner.
     */
    modifier onlyOwners() {
        if (!isOwner(msg.sender)) revert NotAnOwner(msg.sender);
        _;
    }

    /**
     * @dev Modifier that checks if an address is a valid address to receive funds or call functions.
     * @param _to The address to validate.
     * @notice The function using this modifier will only be executed if the address is valid.
     */
    modifier validAddress(address _to) {
        if (_to == address(0) && _to == address(this))
            revert("MultiSign: Invalid address.");
        _;
    }

    /**
     * @dev Modifier that checks if the provided data is not empty.
     * @param _data The data to validate.
     * @notice The function using this modifier will only be executed if the data is not empty.
     */
    modifier validData(bytes memory _data) {
        if (_data.length == 0) revert("MultiSign: Empty data is not valid.");
        _;
    }

    /**
     * @dev Modifier that checks if a transaction with the given ID exists.
     * @param _txId The ID of the transaction to validate.
     * @notice The function using this modifier will only be executed if the transaction exists.
     */
    modifier isExistingTransaction(bytes32 _txId) {
        if (
            keccak256(abi.encode(transactions[_txId])) ==
            keccak256(abi.encode(Transaction(address(0), 0, false, bytes(""))))
        ) revert("MultiSign: Transaction does not exist.");
        _;
    }

    /**
     * @dev Modifier that checks if the value provided is greater than zero.
     * @notice The function using this modifier will only be executed if the value is greater than zero.
     */
    modifier notZeroValue() {
        if (msg.value == 0) revert("MultSign: Zero value");
        _;
    }

    /// @param _owners: The users that can `submit`, `confirm` or `execute` transactions.
    /// @param _threshold: The required confirmation to excuted a transaction.
    constructor(address[] memory _owners, uint256 _threshold) {
        _setOwners(_owners);
        _setThreshold(_threshold);
    }

    /**
     * @dev Adds a new transaction to the list of transactions that can be confirmed and executed.
     * @param _to The address of the contract or account to interact with.
     * @param _value The amount of Ether to send with the transaction.
     * @param _data The data to include with the transaction.
     * @return The ID of the new transaction.
     */
    function addTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) internal onlyOwners validAddress(_to) validData(_data) returns (bytes32) {
        bytes32 _txId = _getHashId(_to, _value, _data);

        transactions[_txId] = Transaction({
            to: _to,
            value: _value,
            executed: false,
            data: _data
        });

        emit TransactionCreated(_txId);

        return _txId;
    }

    /**
     * @dev Submits a new transaction to the list of pending transactions.
     * @param _to The address of the contract or account to interact with.
     * @param _value The amount of Ether to send with the transaction.
     * @param _data The data to include with the transaction.
     *
     * Requirements:
     * - The function can only be called by one of the contract owners.
     * - The address `_to` must be a valid Ethereum address.
     * - The bytes `_data` must not be empty.
     */
    function submitTransaction(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwners {
        _confirmTransaction(addTransaction(_to, _value, _data));
        emit TransactionSubmitted(_to, _value);
    }

    /**
     * @dev Confirms a pending transaction.
     * @param _txId The ID of the transaction to confirm.
     *
     * Requirements:
     * - The function can only be called by one of the contract owners.
     */
    function confirmTransaction(bytes32 _txId) public onlyOwners {
        _confirmTransaction(_txId);
    }

    /**
     * @dev Gets the number of confirmations for a pending transaction.
     * @param _txId The ID of the transaction to check.
     * @return confirmationsCount The number of confirmations for the transaction.
     */
    function getConfirmationsCount(
        bytes32 _txId
    ) public view returns (uint256) {
        uint256 confirmationsCount;
        for (uint256 i = 0; i < ownersCount; i++) {
            if (confirmations[_txId][owners[i]]) {
                confirmationsCount++;
            }
        }
        return confirmationsCount;
    }

    /**
     * @dev Checks if a transaction has been confirmed by the required number of owners.
     * @param _txId The ID of the transaction to check.
     * @return True if the transaction is confirmed, false otherwise.
     */
    function isConfirmed(bytes32 _txId) public view returns (bool) {
        if (getConfirmationsCount(_txId) < threshold) return false;
        return true;
    }

    /**
     * @dev Executes a confirmed transaction.
     * @param _txId The ID of the transaction to execute.
     *
     * Requirements:
     * - The function can only be called by one of the contract owners.
     * - The transaction must have been confirmed by the required number of owners.
     * - The contract must have enough Ether to fulfill the transaction value.
     */
    function executeTransaction(bytes32 _txId) public onlyOwners {
        Transaction storage _tx = transactions[_txId];

        if (!isConfirmed(_txId))
            revert("MultiSign: Trnsaction not confirmed yet");
        if (_tx.value > address(this).balance)
            revert("MultiSign: Not enougth balance");

        _tx.executed = true;

        (bool s, ) = payable(_tx.to).call{value: _tx.value}(_tx.data);
        if (!s) revert("TRANSACTION_FAILED");

        emit TransactionExecuted(_txId, _tx.to, _tx.value);
    }

    /**
     * @dev Checks if an address is one of the contract owners.
     * @param _address The address to check.
     * @return _isOwner True if the address is an owner, false otherwise.
     */
    function isOwner(address _address) public view returns (bool _isOwner) {
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == _address) {
                _isOwner = true;
                break;
            }
        }
    }

    /**
     * @dev Adds funds to the contract.
     *
     * Requirements:
     * - The function can only be called by one of the contract owners.
     * - The value of the transaction must not be zero.
     */
    function fund() external payable onlyOwners notZeroValue {
        emit FoundsAdded(msg.sender, msg.value);
    }

    /**
     * @dev Confirms a pending transaction and executes it if it has been confirmed by the required number of owners.
     * @param _txId The ID of the transaction to confirm and execute.
     */
    function _confirmTransaction(
        bytes32 _txId
    ) internal isExistingTransaction(_txId) {
        confirmations[_txId][msg.sender] = true;

        emit TransactionConfirmed(msg.sender, _txId);

        if (getConfirmationsCount(_txId) >= threshold) {
            executeTransaction(_txId);
        } else {
            emit TransactionConfirmed(msg.sender, _txId);
        }
    }

    /**
     * @dev Sets the owners of the contract.
     * @param _owners The list of addresses to set as the new owners.
     * @notice At least one owner must be provided, or the function will revert.
     */
    function _setOwners(address[] memory _owners) private {
        if (_owners.length == 0) {
            revert(
                "MultiSign: No valid owners length. At least one is required."
            );
        }

        owners = _owners;
        ownersCount = _owners.length;
    }

    /**
     * @dev Sets the required threshold for executing a transaction.
     * @param _threshold The number of confirmations required for execution.
     * @notice The threshold must be greater than zero and less than or equal to the number of owners,
     * or the function will revert.
     */
    function _setThreshold(uint256 _threshold) private {
        if (_threshold == 0)
            revert(
                "MultiSign: Invalid value threshold value of 0. Required threshold > 1"
            );
        if (_threshold > ownersCount)
            revert("MultiSign. Setting more threshold than owners.");
        threshold = _threshold;
    }

    /**
     * @dev Computes the hash id for a given transaction data.
     * @param _to The target address for the transaction.
     * @param _value The value to send in the transaction.
     * @param _data The data to include in the transaction.
     * @return _hashId The hash id computed for the given transaction data.
     */
    function _getHashId(
        address _to,
        uint256 _value,
        bytes memory _data
    ) private view returns (bytes32 _hashId) {
        _hashId = keccak256(
            abi.encodePacked(_to, _value, _data, block.timestamp)
        );
    }

    receive() external payable notZeroValue {
        emit FoundsAdded(msg.sender, msg.value);
    }

    fallback() external payable {
        if (msg.value != 0) {
            emit FoundsAdded(msg.sender, msg.value);
        }
    }
}
