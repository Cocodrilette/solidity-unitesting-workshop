// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title This contract allow multiple user manage founds together.
/// @author https://github.com/cocodrilette
/// @notice This contract is indeed to be educational only. It is not a secure contract.
contract MultiSign {
    mapping(address => bool) private owners;
    uint256 public ownersCount;
    uint256 public threshold;
    // mapping(uint256 => Transaction) public transactions;
    // mapping(uint256 => mapping(address => bool)) public confirmations;
    // uint256 public transactionCount;

    // struct Transaction {
    //     address to;
    //     uint256 value;
    //     bool executed;
    //     bytes data;
    // }

    // event TransactionCreated(uint256 txId);
    // event TransactionConfirmed(address owner, uint256 txId);
    // event TransactionSubmited(address destination, uint256 value);
    // event TransactionExecuted(uint256 txId, address destination, uint256 value);

    error NotAnOwner(address account);

    modifier onlyOwners() {
        if (!isOwner(msg.sender)) revert NotAnOwner(msg.sender);
        _;
    }

    /// @param _owners: The user that can `submit`, `confirm` or `execute` transactions.
    /// @param _threshold: The required confirmation to excuted a transaction.
    constructor(address[] memory _owners, uint256 _threshold) {
        _setOwners(_owners);
        _setThreshold(_threshold);
    }

    // function addTransaction(
    //     address _destination,
    //     uint256 _value,
    //     bytes calldata _data
    // ) internal onlyOwners returns (uint256) {
    //     if (_destination == address(0)) revert();
    //     uint256 txId = transactionCount;
    //     transactionCount++;
    //     transactions[txId] = Transaction({
    //         to: _destination,
    //         value: _value,
    //         executed: false,
    //         data: _data
    //     });

    //     emit TransactionCreated(txId);
    //     return txId;
    // }

    // function confirmTransaction(uint256 _txId) public onlyOwners {
    //     confirmations[_txId][msg.sender] = true;

    //     if (getConfirmationsCount(_txId) >= required) {
    //         executeTransaction(_txId);
    //     } else {
    //         emit TransactionConfirmed(msg.sender, _txId);
    //     }
    // }

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

    // function submitTransaction(
    //     address _destination,
    //     uint256 _value,
    //     bytes calldata _data
    // ) external onlyOwners {
    //     confirmTransaction(addTransaction(_destination, _value, _data));
    //     emit TransactionSubmited(_destination, _value);
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

    function isOwner(address _address) public view returns (bool) {
        return owners[_address];
    }

    receive() external payable {}

    fallback() external payable {}
}
