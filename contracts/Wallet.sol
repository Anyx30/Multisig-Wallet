// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

contract NyxWallet {

    // CustomErrors

    // Events
    event Deposited(address indexed _sender, uint _amount, uint _balance);
    event TxnSubmitted(address indexed _owner, uint indexed _txId, address indexed _to, uint _value, bytes _data);
    event TxnConfirmed(address indexed _owner, address indexed _txId);
    event TxnRevoked(address indexed _owner, address indexed _txId);
    event TxnExecuted(address indexed _owner, address indexed _txId);

    struct transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint confirmations;
    }

    // Modifiers
    modifier onlyOwner() {
        require(isOwner[msg.sender], "!Owner");
        _;
    }
    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "Txn does not exist");
        _;
    }
    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "Txn not executed yet");
        _;
    }
    modifier hasNotConfirmed(uint _txId) {
        require(!hasConfirmed[_txId][msg.sender], "Already Confirmed txn");
        _;
    }

    uint8 public quorum;
    address[] owners;
    transaction[] public transactions;
    mapping(address => bool) public isOwner;
    mapping(uint => mapping(address => bool)) public hasConfirmed;

    constructor(address[] memory _owners, uint _quorumReq) {
        require(_owners.length > 0, 'Invalid Length');
        require(_quorumReq > 0 && _quorumReq <= _owners.length,
            'Quorum must be greater than zero and less than num of owners');
        for(uint i; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner!= address(0), "Invalid");
            require(!isOwner[owner], "Owner already Registered");
            isOwner[owner] = true;
            owners.push(owner);
        }
    }

    receive() external payable {
        emit Deposited(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint txId = transactions.length;
        transactions.push(transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            conformations: 0
        }));

        emit TxnSubmitted(msg.sender, txId);
    }

    function confirmTransaction(uint _txId) public txExists(_txId) notExecuted(_txId) hasNotConfirmed(_txId) onlyOwner {
        transaction storage txn = transactions[_txId];
        txn.confirmations += 1;
        hasConfirmed[_txId][msg.sender] = true;
        emit TxnConfirmed(msg.sender, _txId);
    }

    function revokeTransaction(uint _txId) public txExists(_txId) notExecuted(_txId) onlyOwner {
        transaction storage txn = transactions[_txId];
        txn.confirmations -= 1;
        hasConfirmed[_txId][msg.sender] = false;
        emit TxnRevoked(msg.sender, _txId);
    }

    function executeTransaction(uint _txId) public txExists(_txId) notExecuted(_txId) onlyOwner {
        transaction storage txn = transactions[_txId];
        require(txn.confirmations >= quorum, "Quorum not reached");
        txn.executed = true;
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Tx failed");
        emit TxnExecuted(msg.sender, _txId);
    }

    function getTxnCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(uint _txId) public view returns (
        address to, uint value, bytes memory data, bool executed, uint conformations)
    {
        transaction storage txn = transactions[_txId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.confirmations);
    }

}